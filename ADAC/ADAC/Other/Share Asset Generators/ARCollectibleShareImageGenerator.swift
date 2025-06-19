// Licensed under the Any Distance Source-Available License
//
//  ARCollectibleShareImageGenerator.swift
//  ADAC
//
//  Created by Daniel Kuntz on 2/14/22.
//

import UIKit

final class ARCollectibleShareImageGenerator {
    static func generateShareImages(_ photo: UIImage,
                                    completion: @escaping ((_ images: ShareImages) -> Void)) {
        DispatchQueue.global(qos: .userInitiated).async {
            let story = generateInstaStoryImage(photo)
            let square = generateSquareImage(photo)
            let twitter = generateTwitterImage(photo)

            DispatchQueue.main.async {
                completion(ShareImages(base: photo, instagramStory: story, instagramFeed: square, twitter: twitter))
            }
        }
    }

    private static func generateInstaStoryImage(_ photo: UIImage) -> UIImage {
        let size = CGSize(width: 1080, height: 1920)
        let photoAspect = photo.size.height / photo.size.width
        let scaledPhotoSize = CGSize(width: size.width, height: size.width * photoAspect)
        let blackBarHeight: CGFloat = 130

        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { ctx in
            let rect = CGRect(x: 0,
                              y: blackBarHeight + (size.height - scaledPhotoSize.height) / 2,
                              width: size.width,
                              height: size.width * (photo.size.height / photo.size.width))
            photo.draw(in: rect)

            let blackBarRect = CGRect(x: 0, y: 0, width: size.width, height: blackBarHeight)
            UIColor.black.setFill()
            ctx.fill(blackBarRect)

            if NSUbiquitousKeyValueStore.default.shouldShowAnyDistanceBranding {
                let watermark = UIImage(named: "watermark_v2")!
                let desiredWidth = size.width * 0.25
                let watermarkFrame = CGRect(x: 80,
                                            y: blackBarHeight + 80,
                                            width: desiredWidth,
                                            height: desiredWidth * watermark.size.height / watermark.size.width)
                watermark.draw(in: watermarkFrame)
            }
        }
    }

    private static func generateSquareImage(_ photo: UIImage) -> UIImage {
        let size = CGSize(width: 1080, height: 1080)
        let photoAspect = photo.size.height / photo.size.width
        let scaledPhotoSize = CGSize(width: size.width, height: size.width * photoAspect)

        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { ctx in
            let rect = CGRect(x: 0,
                              y: (size.height - scaledPhotoSize.height) / 2,
                              width: size.width,
                              height: size.width * (photo.size.height / photo.size.width))
            photo.draw(in: rect)

            if NSUbiquitousKeyValueStore.default.shouldShowAnyDistanceBranding {
                let watermark = UIImage(named: "watermark_v2")!
                let desiredWidth = size.width * 0.25
                let watermarkFrame = CGRect(x: 80,
                                            y: 80,
                                            width: desiredWidth,
                                            height: desiredWidth * watermark.size.height / watermark.size.width)
                watermark.draw(in: watermarkFrame)
            }
        }
    }

    private static func generateTwitterImage(_ photo: UIImage) -> UIImage {
        let size = CGSize(width: 1080, height: 1440)
        let photoAspect = photo.size.height / photo.size.width
        let scaledPhotoSize = CGSize(width: size.width, height: size.width * photoAspect)

        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { ctx in
            let rect = CGRect(x: 0,
                              y: (size.height - scaledPhotoSize.height) / 2,
                              width: size.width,
                              height: size.width * (photo.size.height / photo.size.width))
            photo.draw(in: rect)

            if NSUbiquitousKeyValueStore.default.shouldShowAnyDistanceBranding {
                let watermark = UIImage(named: "watermark_v2")!
                let desiredWidth = size.width * 0.25
                let watermarkFrame = CGRect(x: 80,
                                            y: 80,
                                            width: desiredWidth,
                                            height: desiredWidth * watermark.size.height / watermark.size.width)
                watermark.draw(in: watermarkFrame)
            }
        }
    }
}
