// Licensed under the Any Distance Source-Available License
//
//  CollectibleLoader.swift
//  ADAC
//
//  Created by Daniel Kuntz on 5/3/22.
//

import Foundation
import CloudKit
import OneSignal

class CollectibleLoader {

    // MARK: - Variables

    static let shared = CollectibleLoader()
    private let container = CKContainer(identifier: "iCloud.com.anydistance.anydistance.cloudkit")
    private(set) var remoteCollectibles: [String: RemoteCollectible] = NSUbiquitousKeyValueStore.default.remoteCollectibles

    // MARK: - Setup

    func loadCollectibles() async {
        return await withCheckedContinuation { continuation in
            var fetchedCollectibles: [String: RemoteCollectible] = [:]

            let query = CKQuery(recordType: "Collectible", predicate: NSPredicate(value: true))
            var operation = CKQueryOperation(query: query)
            operation.configuration.timeoutIntervalForRequest = 10
            operation.recordFetchedBlock = { record in
                let type = RemoteCollectible(ckRecord: record)
                var shouldAdd: Bool = false
                shouldAdd = type.minVersion <= Bundle.main.releaseVersionNumber
                if type.adminOnly {
                    shouldAdd = ADUser.current.isTeamADAC
                }

                if shouldAdd {
                    fetchedCollectibles[type.rawValue] = type
                }
            }

            operation.queryCompletionBlock = { cursor, error in
                guard error == nil else {
                    print("Error loading collectibles: \(String(describing: error?.localizedDescription))")
                    continuation.resume()
                    return
                }

                guard let cursor = cursor else {
                    self.remoteCollectibles = fetchedCollectibles
                    NSUbiquitousKeyValueStore.default.remoteCollectibles = self.remoteCollectibles
                    CollectibleDataCache.clearUnusedFiles(withExistingCollectibles: Array(self.remoteCollectibles.values))
                    continuation.resume()
                    return
                }

                let newOperation = CKQueryOperation(cursor: cursor)
                newOperation.resultsLimit = operation.resultsLimit
                newOperation.recordFetchedBlock = operation.recordFetchedBlock
                newOperation.queryCompletionBlock = operation.queryCompletionBlock
                operation = newOperation
                self.container.publicCloudDatabase.add(newOperation)
            }

            container.publicCloudDatabase.add(operation)
        }
    }

    func deleteOneSignalTags(for remotes: [RemoteCollectible]) async {
        guard !NSUbiquitousKeyValueStore.default.hasDeletedOneSignalTagsForRemotes else {
            return
        }

        let slice = Array(remotes[0..<min(50, remotes.count)])
        let oneSignalTags = slice.map { "collectible_earned_\($0.rawValue)" }
        await withCheckedContinuation { continuation in
            OneSignal.deleteTags(oneSignalTags) { dict in
                continuation.resume()
            } onFailure: { _ in
                continuation.resume()
            }
        }

        let remaining = Array(remotes.dropFirst(50))
        if !remaining.isEmpty {
            await self.deleteOneSignalTags(for: remaining)
        } else {
            NSUbiquitousKeyValueStore.default.hasDeletedOneSignalTagsForRemotes = true
        }
    }

    // MARK: - Public

    func remoteCollectible(withRawValue rawValue: String) -> RemoteCollectible? {
        return remoteCollectibles[rawValue]
    }
}

extension NSUbiquitousKeyValueStore {
    var hasDeletedOneSignalTagsForRemotes: Bool {
        get {
            return bool(forKey: "hasDeletedOneSignalTagsForRemotes")
        }

        set {
            set(newValue, forKey: "hasDeletedOneSignalTagsForRemotes")
        }
    }

    var remoteCollectibles: [String: RemoteCollectible] {
        get {
            if let object = data(forKey: "remoteCollectibles"),
               let array = try? JSONDecoder().decode([String: RemoteCollectible].self, from: object) {
                return array
            }

            return [:]
        }

        set {
            let data = try? JSONEncoder().encode(newValue)
            set(data, forKey: "remoteCollectibles")
        }
    }

    var rewardCollectibles: [RemoteCollectible] {
        get {
            if let object = data(forKey: "rewardCollectibles"),
               let array = try? JSONDecoder().decode([RemoteCollectible].self, from: object) {
                return array
            }

            return []
        }

        set {
            let data = try? JSONEncoder().encode(newValue)
            set(data, forKey: "rewardCollectibles")
        }
    }
}
