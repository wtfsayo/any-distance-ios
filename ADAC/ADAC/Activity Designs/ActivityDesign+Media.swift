// Licensed under the Any Distance Source-Available License
//
//  ActivityDesign+Media.swift
//  ADAC
//
//  Created by Jarod Luebbert on 4/25/22.
//

import Foundation
import UIKit
import AVFoundation

extension ActivityDesign {
    
    // MARK: - Photo/Video
        
    private var store: ActivityDesignMediaStore {
        return ActivityDesignMediaStore.shared
    }
    
    func photo(with size: ActivityDesign.PhotoSize) async -> UIImage? {
        if photoFilter == .none {
            return await store.image(for: self, size: size)
        } else {
            return await store.imageWithFilter(for: self, size: size)
        }
    }
    
    var photo: UIImage? {
        get async {
            return await store.image(for: self)
        }
    }
    
    var photoWithFilter: UIImage? {
        get async {
            return await store.imageWithFilter(for: self)
        }
    }
    
    var fillWithFilter: UIImage? {
        get async {
            return await store.fillWithFilter(for: self)
        }
    }
    
    func save(photo: UIImage) async {
        await store.save(image: photo, for: self)
        store.removeVideo(for: self)
    }
    
    // TODO: support AR video?
    func saveVideo(from url: URL) async {
        try? await store.saveVideo(from: url, for: self)
    }
    
    func removePhoto() {
        store.removeImage(for: self)
    }
    
    func removeVideo() {
        store.removeVideo(for: self)
        store.removeImage(for: self)
    }
    
    var videoAsset: AVAsset? {
        get {
            store.videoAsset(for: self, videoMode: .loop)
        }
    }
    
    var videoAssetURL: URL? {
        store.url(with: videoFilename(for: .loop))
    }
    
    var videoAssetWithBounceURL: URL? {
        store.url(with: videoFilename(for: .bounce))
    }
    
    /// Will not generate the asset, only loads from file if it exists
    var videoAssetWithBounceFromFile: AVAsset? {
        get {
            store.videoAsset(for: self, videoMode: .bounce)
        }
    }
    
    /// generates the asset as long as there is a video URL
    var videoAssetWithBounce: AVAsset? {
        get async {
            await store.videoAssetAsync(for: self, videoMode: .bounce)
        }
    }
    
    func videoFilename(for videoMode: VideoMode) -> String {
        switch videoMode {
        case .loop:
            return legacyVideoURL?.lastPathComponent ?? "\(id)_loop.mov"
        case .bounce:
            return "\(id)_bounce.mov"
        }
    }
    
    var photoFilename: String {
        legacyPhotoFilename ?? "\(id).jpg"
    }
    
}
