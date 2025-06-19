// Licensed under the Any Distance Source-Available License
//
//  VideoFrameGrabber.swift
//  ADAC
//
//  Created by Daniel Kuntz on 11/25/21.
//

import UIKit
import AVFoundation

final class VideoFrameGrabber {
    
    static func firstFrameForVideo(at url: URL) async -> UIImage? {
        return await withCheckedContinuation({ continuation in
            Self.getFirstFrameForVideo(atUrl: url) { image in
                continuation.resume(returning: image)
            }
        })
    }
    
    static func getFirstFrameForVideo(atUrl url: URL, completion: @escaping ((UIImage?) -> Void)) {
        DispatchQueue.global(qos: .userInitiated).async {
            let asset = AVURLAsset(url: url)
            let assetIG = AVAssetImageGenerator(asset: asset)
            assetIG.appliesPreferredTrackTransform = true
            assetIG.apertureMode = .encodedPixels

            let cmTime = CMTime(seconds: 0, preferredTimescale: 60)
            var thumbnailImageRef: CGImage?
            do {
                thumbnailImageRef = try assetIG.copyCGImage(at: cmTime, actualTime: nil)
            } catch let error {
                print("Error in getFirstFrameForVideo: \(error)")
            }

            guard let thumbnailImageRef = thumbnailImageRef else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }

            let image = UIImage(cgImage: thumbnailImageRef)

            DispatchQueue.main.async {
                completion(image)
            }
        }
    }
}

