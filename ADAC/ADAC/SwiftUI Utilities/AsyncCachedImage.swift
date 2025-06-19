// Licensed under the Any Distance Source-Available License
//
//  AsyncCachedImage.swift
//  ADAC
//
//  Created by Daniel Kuntz on 4/3/23.
//

import SwiftUI
import SwiftUIX
import SDWebImage
import CoreGraphics
import Cache
import Combine

class ParallelImageLoader {
    static var urlObservers: [String: [((UIImage?) -> Void)?]] = [:]
    private static let queue = DispatchQueue(label: "com.anydistance.anydistance.ParallelImageLoader.\(UUID().uuidString)",
                                             qos: .userInitiated)

    static func loadImage(with url: URL, completion: ((UIImage?) -> Void)? = nil) {
        queue.sync {
            if let observers = urlObservers[url.absoluteString] {
                urlObservers[url.absoluteString] = observers + [completion]
                return
            }
            urlObservers[url.absoluteString] = [{ completion?($0) }]

            Task(priority: .userInitiated) {
                guard let request = try? URLRequest(url: url, method: .get) else {
                    return
                }
                let (data, _) = try await URLSession.shared.data(for: request)
                guard let image = UIImage(data: data) else {
                    return
                }

                queue.sync {
                    if let observers = urlObservers[url.absoluteString] {
                        observers.forEach { observer in
                            observer?(image)
                        }
                    }
                    urlObservers[url.absoluteString] = nil
                }
            }
        }
    }
}

fileprivate class ResizedImageMemoryCache {
    static let shared = ResizedImageMemoryCache()

    private let queue = DispatchQueue(label: "com.anydistance.anydistance.ResizedImageMemoryCache.\(UUID().uuidString)",
                                      qos: .userInitiated)
    let maxMemoryFootprintBytes: UInt64 = UInt64(10e7)
    private var internalCache: [String: UIImage] = [:]
    private var orderedImageKeysByInsertionTime: [String] = []
    private var currentMemoryFootprint: UInt64 = 0
    private var subscribers: Set<AnyCancellable> = []

    init() {
        NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)
            .receive(on: queue)
            .sink { [weak self] _ in
                self?.purgeAll()
            }.store(in: &subscribers)
    }

    private func key(for url: URL, width: CGFloat?) -> String {
        if let width = width {
            return url.absoluteString + "_" + String(Int(width))
        } else {
            return url.absoluteString
        }
    }

    func cache(image: UIImage?, for url: URL, width: CGFloat?) {
        queue.sync {
            guard let image = image else {
                return
            }

            let key = self.key(for: url, width: width)
            internalCache[key] = image
            orderedImageKeysByInsertionTime.removeAll(where: { $0 == key })
            orderedImageKeysByInsertionTime.append(key)
            if let cgImage = image.cgImage {
                let size = cgImage.height * cgImage.bytesPerRow
                currentMemoryFootprint += UInt64(size)
            }

            purgeIfNecessary()
        }
    }

    private func purgeIfNecessary() {
        while currentMemoryFootprint > maxMemoryFootprintBytes {
            guard let firstInsertedKey = orderedImageKeysByInsertionTime.first else {
                break
            }

            guard let image = internalCache[firstInsertedKey] else {
                orderedImageKeysByInsertionTime.removeFirst()
                continue
            }

            guard let cgImage = image.cgImage else {
                continue
            }

            let size = cgImage.height * cgImage.bytesPerRow
            currentMemoryFootprint -= UInt64(size)
            internalCache[firstInsertedKey] = nil
            orderedImageKeysByInsertionTime.removeFirst()
        }
    }

    private func purgeAll() {
        internalCache = [:]
        orderedImageKeysByInsertionTime = []
        currentMemoryFootprint = 0
    }

    func cachedImage(for url: URL, width: CGFloat?) -> UIImage? {
        queue.sync {
            let key = self.key(for: url, width: width)
            return internalCache[key]
        }
    }
}

fileprivate class URLImageDiskCache {
    static let shared = URLImageDiskCache()
    private var internalCache: Storage<String, UIImage>? // url string, image

    init() {
        let memoryConfig = MemoryConfig(expiry: .never,
                                        countLimit: 1,
                                        totalCostLimit: 1)

        internalCache = try? Storage<String, UIImage>(
            diskConfig: DiskConfig(name: "com.anydistance.URLImageDiskCache", maxSize: UInt(1e+8)),
            memoryConfig: memoryConfig,
            transformer: TransformerFactory.forImage()
        )
    }

    func cachedImage(for url: URL) -> UIImage? {
        return try? internalCache?.object(forKey: url.absoluteString)
    }

    func cache(image: UIImage?, for url: URL) {
        guard let image = image else {
            return
        }

        try? internalCache?.setObject(image, forKey: url.absoluteString)
    }
}

class AsyncCachedImageModel: ObservableObject {
    var url: URL?
    var resizeToWidth: CGFloat?
    var isLoading: Bool = false
    @Published var imageWasLoadedFromMemory: Bool = false
    @Published var loadedImage: UIImage?
    @Published var loadFailed: Bool = false

    init(url: URL?, resizeToWidth: CGFloat?) {
        self.url = url
        self.resizeToWidth = resizeToWidth
        self.loadImage()
    }

    private func resizedImage(_ image: UIImage?, width: CGFloat?) async -> UIImage? {
        guard let image = image else {
            return nil
        }

        if let width = width {
            let size = CGSize(width: width,
                              height: width * image.size.height / image.size.width)
            let resized = await image.byPreparingThumbnail(ofSize: size)?.byPreparingForDisplay()
            return resized
        }

        return image
    }

    func loadImage() {
        guard let url = url?.imgixURL else {
            loadFailed = true
            return
        }

        guard loadedImage == nil,
              !isLoading else {
            return
        }

        isLoading = true
        loadFailed = false

        let resizeToWidth = (resizeToWidth != nil) ? (resizeToWidth! * 2.0) : nil

        // Check the memory cache for an existing resized, decoded image.
        if let memoryImage = ResizedImageMemoryCache.shared.cachedImage(for: url,
                                                                        width: resizeToWidth) {
            self.imageWasLoadedFromMemory = true
            self.loadedImage = memoryImage
            self.isLoading = false
            return
        }

        Task(priority: .userInitiated) {
            // Check the disk cache for this image.
            if let diskImage = URLImageDiskCache.shared.cachedImage(for: url) {
                // If we find an image in the disk cache, resize and prepare it for display.
                let resized = await self.resizedImage(diskImage, width: resizeToWidth)
                // Cache it in memory for next display.
                ResizedImageMemoryCache.shared.cache(image: resized,
                                                     for: url,
                                                     width: resizeToWidth)
                // Prepare for display
                let prepared = await resized?.byPreparingForDisplay()
                await MainActor.run {
                    self.loadedImage = prepared
                    self.isLoading = false
                }
                return
            }

            // If we can't find this image in memory or on the disk, download it from the URL.
            ParallelImageLoader.loadImage(with: url) { [weak self] image in
                Task(priority: .medium) {
                    if !url.isFileURL {
                        // Only disk cache remote URLs to avoid duplicates.
                        URLImageDiskCache.shared.cache(image: image, for: url)
                    }
                }

                guard let self = self else {
                    return
                }

                Task(priority: .userInitiated) {
                    // Resize and prepare for display.
                    let resized = await self.resizedImage(image, width: resizeToWidth)
                    // Cache in memory
                    ResizedImageMemoryCache.shared.cache(image: resized,
                                                         for: url,
                                                         width: resizeToWidth)
                    // Prepare for display
                    let prepared = await resized?.byPreparingForDisplay()
                    await MainActor.run {
                        self.loadedImage = resized
                        self.isLoading = false
                        if self.loadedImage == nil {
                            self.loadFailed = true
                        }
                    }
                }
            }
        }
    }
}

struct AsyncCachedImage: View {
    @StateObject var model: AsyncCachedImageModel
    @Binding var loadedImage: UIImage?
    var showsLoadingIndicator: Bool = true
    @State var loadingAnimationState: Bool = false

    init(url: URL?,
         resizeToWidth: CGFloat? = nil,
         loadedImage: Binding<UIImage?>? = nil,
         showsLoadingIndicator: Bool = true) {
        if let loadedImage = loadedImage {
            self._loadedImage = loadedImage
        } else {
            self._loadedImage = .init(get: { return nil }, set: { _ in })
        }

        self._model = StateObject(wrappedValue: { AsyncCachedImageModel(url: url, resizeToWidth: resizeToWidth) }())
        self.showsLoadingIndicator = showsLoadingIndicator
    }

    var body: some View {
        VStack {
            if let loadedImage = model.loadedImage {
                Image(uiImage: loadedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipped()
            } else if showsLoadingIndicator && !model.loadFailed {
                Rectangle()
                    .fill(Color.white)
                    .opacity(loadingAnimationState ? 0.2 : 0.0)
                    .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true),
                               value: loadingAnimationState)
                    .onAppear {
                        loadingAnimationState = true
                    }
            }
        }
        .id(model.loadedImage == nil ? 0 : 1)
        .if(!model.imageWasLoadedFromMemory) { view in
            view.modifier(BlurOpacityTransition(speed: 2.0))
        }
        .onChange(of: model.loadedImage) { newValue in
            loadedImage = newValue
        }
        .onAppear {
            model.loadImage()
            loadedImage = model.loadedImage
        }
        .onDisappear {
            model.loadedImage = nil
        }
    }
}
