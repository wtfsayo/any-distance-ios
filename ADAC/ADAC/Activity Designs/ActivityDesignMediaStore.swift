// Licensed under the Any Distance Source-Available License
//
//  ActivityDesignMediaStore.swift
//  ADAC
//
//  Created by Jarod Luebbert on 4/25/22.
//

import Foundation
import UIKit
import Cache
import AVFoundation

fileprivate extension UIImage {
    
    func cropped(to cropRect: CGRect, scale: CGFloat, compression: CGFloat) -> UIImage? {
        // crop
        guard let cutImageRef: CGImage = cgImage?.cropping(to: cropRect) else {
            return nil
        }
        
        let croppedImage: UIImage = UIImage(cgImage: cutImageRef)

        // scale
        let rect = CGRect(x: 0.0,
                          y: 0.0,
                          width: croppedImage.size.width * scale,
                          height: croppedImage.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0 // set to default `format` for device scale
        let renderer = UIGraphicsImageRenderer(size: rect.size, format: format)
        let data = renderer.jpegData(withCompressionQuality: compression) { context in
            croppedImage.draw(in: rect)
        }
        
        return UIImage(data: data, scale: self.scale)
    }
    
    func resized(to photoSize: ActivityDesign.PhotoSize) -> UIImage? {
        let scale = min(min(photoSize.maxSize.width / size.width,
                            photoSize.maxSize.height / size.height), 1.0)
        let cropRect = CGRect(x: photoSize.cropRect.origin.x * size.width,
                              y: photoSize.cropRect.origin.y * size.height,
                              width: photoSize.cropRect.width * size.width,
                              height: photoSize.cropRect.height * size.height)
        let croppedImage = self.withCorrectedOrientation().cropped(to: cropRect,
                                                                   scale: scale,
                                                                   compression: photoSize.compression)
        return croppedImage
    }

}

extension ActivityDesign {
    
    enum PhotoSize: String, CaseIterable {
        case listView
        
        var maxSize: CGSize {
            switch self {
            case .listView:
                return CGSize(width: 1200.0, height: 1200.0)
            }
        }
        
        var cropRect: CGRect {
            switch self {
            case .listView:
                return CGRect(x: 0.0, y: 0.5, width: 1.0, height: 0.2)
            }
        }
        
        var compression: CGFloat {
            switch self {
            case .listView:
                return 0.7
            }
        }
    }
    
}

fileprivate extension ActivityDesign {
    
    var cachedImageKey: String {
        id
    }
    
    var cachedFilteredImageKey: String {
        cachedImageKey(for: photoFilter)
    }
    
    var cachedFilteredFillImageKey: String {
        "\(id)_\(fill?.name ?? "none")_\(photoFilter.rawValue)"
    }
    
    func cachedFilteredImageKey(for size: PhotoSize?, photoFilter: PhotoFilter? = nil) -> String {
        let filter = photoFilter ?? self.photoFilter
        guard let size = size else {
            return cachedImageKey(for: filter)
        }

        return "\(cachedImageKey(for: filter))_\(size.rawValue)"
    }
    
    func cachedImageKey(for photoFilter: PhotoFilter) -> String {
        "\(id)_filter_\(photoFilter.rawValue)"
    }
 
    func cachedImageKey(for size: PhotoSize?) -> String {
        guard let size = size else {
            return cachedImageKey
        }

        return "\(cachedImageKey)_\(size.rawValue)"
    }
    
    func photoFilename(for size: PhotoSize?) -> String {
        guard let size = size else {
            return photoFilename
        }

        return "\(size.rawValue)_\(photoFilename)"
    }
    
}

/// Persists images/videos to disk, and caches them to disk/memory
/// persists to the documents directory.
///
/// Eventually, move to using storing `PHCloudIdentifier` on the `ActivityDesign`,
/// so we don't have to take up space on the user's device, and also can move to syncing
/// designs with iCloud.
class ActivityDesignMediaStore {
    
    static let shared = ActivityDesignMediaStore()
    
    private let imageCache = NSCache<NSString, UIImage>()

    private init() {
        imageCache.countLimit = 20
    }
    
    // MARK: - Public
    
    func image(for activityDesign: ActivityDesign, size: ActivityDesign.PhotoSize? = nil) async -> UIImage? {
        let key = activityDesign.cachedImageKey(for: size)
        if let cachedImage = cachedImage(for: key) {
            return cachedImage
        }
        
        let filename = activityDesign.photoFilename(for: size)
        return await image(with: filename)
    }
    
    func fillWithFilter(for activityDesign: ActivityDesign, size: ActivityDesign.PhotoSize? = nil) async -> UIImage? {
        guard activityDesign.photoFilter != .none else {
            return activityDesign.fill?.image
        }
        
        guard let fill = activityDesign.fill,
              let image = fill.image else {
            return nil
        }
        
        if let cachedImage = cachedImage(for: activityDesign.cachedFilteredFillImageKey) {
            return cachedImage
        }

        do {
//            let filteredImage = try await activityDesign.photoFilter.applied(to: image)
//            
//            if let image = filteredImage {
//                cache(image: image, for: activityDesign.cachedFilteredFillImageKey)
//            }
//            
//            return filteredImage
        } catch {
            print("Error getting filtered fill image: \(error.localizedDescription)")
        }
        
        return nil
    }
    
    /// Filtered images are cached in memory and to disk, when we reach our memory/disk limits,
    /// the cache is automatically cleared, since we can always re-filter our image that is saved
    /// to the documents directory.
    func imageWithFilter(for activityDesign: ActivityDesign, size: ActivityDesign.PhotoSize? = nil) async -> UIImage? {
        guard activityDesign.photoFilter != .none else { return nil }
        
        if let cachedImage = cachedImage(for: activityDesign.cachedFilteredImageKey) {
            return cachedImage
        }
        
        do {
            // if not in cache or disk, just filter the image with the active filter
            guard let image = await image(for: activityDesign) else {
                return nil
            }
            
//            let filteredImage = try await activityDesign.photoFilter.applied(to: image)
//            
//            if let image = filteredImage {
//                cache(image: image, for: activityDesign.cachedFilteredImageKey)
//            }
//            
//            return filteredImage
        } catch {
            print("Error getting filtered image: \(error.localizedDescription)")
        }
        
        return nil
    }
    
    func videoAsset(for activityDesign: ActivityDesign, videoMode: VideoMode) -> AVAsset? {
        return asset(with: activityDesign.videoFilename(for: videoMode))
    }
    
    /// non-blocking, autocreates bounce asset if one does not exist
    func videoAssetAsync(for activityDesign: ActivityDesign, videoMode: VideoMode) async -> AVAsset? {
        let asset: AVAsset? = await withCheckedContinuation { continuation in
            Task {
                var asset = videoAsset(for: activityDesign, videoMode: videoMode)
                
                if videoMode == .bounce, asset == nil,
                   let loopedURL = url(with: activityDesign.videoFilename(for: .loop)) {
                    // use the looped video to generate a bounced video
                    asset = await makeBounceVideo(from: loopedURL, for: activityDesign)
                }
                
                continuation.resume(returning: asset)
            }
        }
        return asset
    }
    
    func saveVideo(from url: URL, for activityDesign: ActivityDesign) async throws {
        // guarantees we add a `save` when we add a new video mode
        for videoMode in VideoMode.allCases {
            guard let outputURL = self.url(with: activityDesign.videoFilename(for: videoMode)) else {
                continue
            }
            
            switch videoMode {
            case .loop:
                FileManager.default.removeItemIfExists(atUrl: outputURL)
                print(outputURL)
                try FileManager.default.copyItem(at: url, to: outputURL)
            case .bounce:
                Task {
                    let _ = await makeBounceVideo(from: url, for: activityDesign)
                    FileManager.default.removeItemIfExists(atUrl: url)
                }
            }
        }
        
        // save a thumbnail of the video to show and generate color palettes
        if let image = await VideoFrameGrabber.firstFrameForVideo(at: url) {
            await save(image: image, for: activityDesign)
        }
    }
    
    private func makeBounceVideo(from url: URL, for activityDesign: ActivityDesign) async -> AVAsset? {
        guard fileExists(at: url),
              let outputURL = self.url(with: activityDesign.videoFilename(for: .bounce)) else { return nil }
        let bounceAsset: AVAsset? = await withCheckedContinuation { continuation in
            let asset = AVAsset(url: url)
            VideoReverser.makeBounceVideo(asset, outputURL: outputURL) { bounceAsset in
                continuation.resume(returning: bounceAsset)
            }
        }
        return bounceAsset
    }
    
    func removeVideo(for activityDesign: ActivityDesign) {
        for videoMode in VideoMode.allCases {
            if let outputURL = url(with: activityDesign.videoFilename(for: videoMode)) {
                FileManager.default.removeItemIfExists(atUrl: outputURL)
            }
        }
    }
    
    @discardableResult
    func save(image: UIImage, for activityDesign: ActivityDesign) async -> [UIImage?] {
        removeImage(for: activityDesign)
        removeCachedImage(for: activityDesign.cachedFilteredImageKey)

        let images: [UIImage?] = await withTaskGroup(of: UIImage?.self) { group in
            // save various sizes
            for size in ActivityDesign.PhotoSize.allCases {
                group.addTask(priority: .background) { [weak self] in
                    guard let self = self else { return nil }
                    // remove old filtered images for this size
                    self.removeCachedImage(for: activityDesign.cachedFilteredImageKey(for: size))

                    if let resizedImage = image.resized(to: size) {
                        self.cache(image: resizedImage,
                                   for: activityDesign.cachedImageKey(for: size))
                        try? await self.save(image: resizedImage,
                                             with: activityDesign.photoFilename(for: size))
                        return resizedImage
                    } else {
                        return nil
                    }
                }
            }
            
            cache(image: image, for: activityDesign.cachedImageKey)
            
            group.addTask(priority: .background) { [weak self] in
                guard let self = self else { return nil }
                try? await self.save(image: image, with: activityDesign.photoFilename)
                return image
            }

            var images = [UIImage?]()
            
            for await image in group {
                images.append(image)
            }
            
            return images
        }
        
        return images
    }
    
    func removeImage(for activityDesign: ActivityDesign) {
        // delete image/filteredImage from cache
        removeCachedImage(for: activityDesign.cachedImageKey)
        // remove all cached filters
        for filter in PhotoFilter.allCases {
            removeCachedImage(for: activityDesign.cachedImageKey(for: filter))
        }
        
        // remove all sizes
        for size in ActivityDesign.PhotoSize.allCases {
            removeCachedImage(for: activityDesign.cachedImageKey(for: size))
            for filter in PhotoFilter.allCases {
                removeCachedImage(for: activityDesign.cachedFilteredImageKey(for: size, photoFilter: filter))
            }
            
            guard let imageURL = url(with: activityDesign.photoFilename(for: size)) else {
                continue
            }
            try? FileManager.default.removeItemIfExists(at: imageURL)
        }
        
        do {
            guard let imageURL = url(with: activityDesign.photoFilename) else {
                return
            }
            try FileManager.default.removeItemIfExists(at: imageURL)
            // for legacy only, when we used to write filtered images to docs directory
            if let legacyFilename = activityDesign.legacyFilteredPhotoFilename,
               let legacyURL = url(with: legacyFilename) {
                try FileManager.default.removeItemIfExists(at: legacyURL)
            }
        } catch {
            print("Error removing image: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Cacheing
    
    private func cache(image: UIImage, for key: String) {
        imageCache.setObject(image, forKey: key as NSString)
    }
    
    private func cachedImage(for key: String) -> UIImage? {
        return imageCache.object(forKey: key as NSString)
    }
    
    private func removeCachedImage(for key: String) {
        imageCache.removeObject(forKey: key as NSString)
    }
    
    // MARK: - Persistance
    
    static let documentsDirectory: URL? = try? FileManager.default.url(for: .documentDirectory,
                                                                      in: .userDomainMask,
                                                                      appropriateFor: nil,
                                                                      create: true)
    
    private func image(with filename: String) async -> UIImage? {
        guard let path = url(with: filename)?.path else {
            return nil
        }
        
        let image: UIImage? = await withCheckedContinuation { continuation in
            continuation.resume(returning: UIImage(contentsOfFile: path))
        }
        
        return image
    }
        
    private func save(image: UIImage, with filename: String, compression: CGFloat = 1.0) async throws {
        guard let url = url(with: filename) else {
            return
        }
        
        if let data = image.jpegData(compressionQuality: compression) {
            try data.write(to: url)
        } else {
            try FileManager.default.removeItem(at: url)
        }
    }
    
    private func asset(with filename: String) -> AVAsset? {
        guard let url = url(with: filename),
              fileExists(at: url) else {
            return nil
        }
        
        return AVAsset(url: url)
    }
    
    func url(with filename: String) -> URL? {
        return Self.documentsDirectory?.appendingPathComponent(filename)
    }
    
    func fileExists(at url: URL?) -> Bool {
        guard let url = url else {
            return false
        }
        
        return FileManager.default.fileExists(atPath: url.path)
    }
    
}
