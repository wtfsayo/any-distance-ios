// Licensed under the Any Distance Source-Available License
//
//  CombineExtensions.swift
//  ADAC
//
//  Created by Jarod Luebbert on 9/7/22.
//

import Foundation
import Combine

extension Publishers {
    public struct WithLatestFrom<Upstream: Publisher, Other: Publisher>:
        Publisher where Upstream.Failure == Other.Failure
    {
        // MARK: - Types
        public typealias Output = (Upstream.Output, Other.Output)
        public typealias Failure = Upstream.Failure

        // MARK: - Properties
        private let upstream: Upstream
        private let other: Other

        // MARK: - Initialization
        init(upstream: Upstream, other: Other) {
            self.upstream = upstream
            self.other = other
        }

        // MARK: - Publisher Lifecycle
        public func receive<S: Subscriber>(subscriber: S)
            where S.Failure == Failure, S.Input == Output
        {
            let merged = mergedStream(upstream, other)
            let result = resultStream(from: merged)
            result.subscribe(subscriber)
        }
    }
}


extension Publisher {
    
    func removeDuplicatesAndErase() -> AnyPublisher<Self.Output, Self.Failure> where Self.Output: Equatable {
        return removeDuplicates().eraseToAnyPublisher()
    }

     /// Includes the current element as well as the previous element from the upstream publisher in a tuple where the previous element is optional.
     /// The first time the upstream publisher emits an element, the previous element will be `nil`.
     ///
     ///     let range = (1...5)
     ///     cancellable = range.publisher
     ///         .withPrevious()
     ///         .sink { print ("(\($0.previous), \($0.current))", terminator: " ") }
     ///      // Prints: "(nil, 1) (Optional(1), 2) (Optional(2), 3) (Optional(3), 4) (Optional(4), 5) ".
     ///
     /// - Returns: A publisher of a tuple of the previous and current elements from the upstream publisher.
     func withPrevious() -> AnyPublisher<(previous: Output?, current: Output), Failure> {
         scan(Optional<(Output?, Output)>.none) { ($0?.1, $1) }
             .compactMap { $0 }
             .eraseToAnyPublisher()
     }

     /// Includes the current element as well as the previous element from the upstream publisher in a tuple where the previous element is not optional.
     /// The first time the upstream publisher emits an element, the previous element will be the `initialPreviousValue`.
     ///
     ///     let range = (1...5)
     ///     cancellable = range.publisher
     ///         .withPrevious(0)
     ///         .sink { print ("(\($0.previous), \($0.current))", terminator: " ") }
     ///      // Prints: "(0, 1) (1, 2) (2, 3) (3, 4) (4, 5) ".
     ///
     /// - Parameter initialPreviousValue: The initial value to use as the "previous" value when the upstream publisher emits for the first time.
     /// - Returns: A publisher of a tuple of the previous and current elements from the upstream publisher.
     func withPrevious(_ initialPreviousValue: Output) -> AnyPublisher<(previous: Output, current: Output), Failure> {
         scan((initialPreviousValue, initialPreviousValue)) { ($0.1, $1) }.eraseToAnyPublisher()
     }
    
    func asyncMap<T>(
        _ transform: @escaping (Output) async -> T
    ) -> Publishers.FlatMap<Future<T, Never>, Self> {
        flatMap { value in
            Future { promise in
                Task {
                    let output = await transform(value)
                    promise(.success(output))
                }
            }
        }
    }
    
    func withLatestFrom<Other: Publisher>(_ other: Other) -> Publishers.WithLatestFrom<Self, Other>
    {
        return .init(upstream: self, other: other)
    }

 }

// MARK: - Helpers
private extension Publishers.WithLatestFrom {
    // MARK: - Types
    enum MergedElement {
        case upstream1(Upstream.Output)
        case upstream2(Other.Output)
    }

    typealias ScanResult =
        (value1: Upstream.Output?,
         value2: Other.Output?, shouldEmit: Bool)

    // MARK: - Pipelines
    func mergedStream(_ upstream1: Upstream, _ upstream2: Other)
        -> AnyPublisher<MergedElement, Failure>
    {
        let mergedElementUpstream1 = upstream1
            .map { MergedElement.upstream1($0) }
        let mergedElementUpstream2 = upstream2
            .map { MergedElement.upstream2($0) }
        return mergedElementUpstream1
            .merge(with: mergedElementUpstream2)
            .eraseToAnyPublisher()
    }

    func resultStream(
        from mergedStream: AnyPublisher<MergedElement, Failure>
    ) -> AnyPublisher<Output, Failure>
    {
        mergedStream
            .scan(nil) {
                (prevResult: ScanResult?,
                mergedElement: MergedElement) -> ScanResult? in

                var newValue1: Upstream.Output?
                var newValue2: Other.Output?
                let shouldEmit: Bool

                switch mergedElement {
                case .upstream1(let v):
                    newValue1 = v
                    shouldEmit = prevResult?.value2 != nil
                case .upstream2(let v):
                    newValue2 = v
                    shouldEmit = false
                }

                return ScanResult(value1: newValue1 ?? prevResult?.value1,
                                  value2: newValue2 ?? prevResult?.value2,
                                  shouldEmit: shouldEmit)
        }
        .compactMap { $0 }
        .filter { $0.shouldEmit }
        .map { Output($0.value1!, $0.value2!) }
        .eraseToAnyPublisher()
    }
}

public struct CombineLatestCollection<Publishers>
    where
    Publishers: Collection,
    Publishers.Element: Publisher
{
    public typealias Output = [Publishers.Element.Output]
    public typealias Failure = Publishers.Element.Failure

    private let publishers: Publishers
    public init(_ publishers: Publishers) {
        self.publishers = publishers
    }
}

extension Collection where Element: Publisher {

    public var combineLatest: CombineLatestCollection<Self> {
        CombineLatestCollection(self)
    }
}

extension CombineLatestCollection: Publisher {

    public func receive<S>(subscriber: S)
        where
        S: Subscriber,
        S.Failure == Failure,
        S.Input == Output
    {
        let subscription = Subscription(publishers: publishers,
                                        subscriber: subscriber)
        subscriber.receive(subscription: subscription)
    }
}

extension CombineLatestCollection {

    public final class Subscription<Subscriber>: Combine.Subscription
        where
        Subscriber: Combine.Subscriber,
        Subscriber.Failure == Failure,
        Subscriber.Input == Output
    {

        private let subscribers: [AnyCancellable]

        fileprivate init(publishers: Publishers, subscriber: Subscriber) {

            var values: [Publishers.Element.Output?] = Array(repeating: nil, count: publishers.count)
            var completions = 0
            var hasCompleted = false
            var lock = pthread_mutex_t()

            subscribers = publishers.enumerated().map { index, publisher in

                publisher
                    .sink(receiveCompletion: { completion in

                        pthread_mutex_lock(&lock)
                        defer { pthread_mutex_unlock(&lock) }

                        guard case .finished = completion else {
                            // One failure in any of the publishers cause a
                            // failure for this subscription.
                            subscriber.receive(completion: completion)
                            hasCompleted = true
                            return
                        }

                        completions += 1

                        if completions == publishers.count {
                            subscriber.receive(completion: completion)
                            hasCompleted = true
                        }

                    }, receiveValue: { value in

                        pthread_mutex_lock(&lock)
                        defer { pthread_mutex_unlock(&lock) }

                        guard !hasCompleted else { return }

                        values[index] = value

                        // Get non-optional array of values and make sure we
                        // have a full array of values.
                        let current = values.compactMap { $0 }
                        if current.count == publishers.count {
                            _ = subscriber.receive(current)
                        }
                    })
            }
        }

        public func request(_ demand: Subscribers.Demand) {}

        public func cancel() {
            subscribers.forEach { $0.cancel() }
        }
    }
}
