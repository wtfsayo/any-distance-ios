// Licensed under the Any Distance Source-Available License
//
//  CollectibleShareImageGenerator.swift
//  ADAC
//
//  Created by Daniel Kuntz on 2/4/21.
//

import UIKit

final class CollectibleShareImageGenerator: CanvasShareImageGenerator {
    static func generateShareImages(_ collectible: Collectible) async -> ShareImages {
        let instaStory = await makeInstagramStoryImage(collectible)
        let instaFeed = await makeInstagramFeedImage(collectible)
        let twitter = await makeTwitterImage(collectible)
        let images = ShareImages(base: instaStory,
                                 instagramStory: instaStory,
                                 instagramFeed: instaFeed,
                                 twitter: twitter)

        return images
    }

    static func generateLayoutBackgroundImages(forCollectibles collectibles: [Collectible]) async -> [UIImage] {
        var images: [UIImage] = []

        for collectible in collectibles where collectible.itemType == .medal {
            let image = await generateLayoutBackgroundImage(collectible)
            images.append(image)
        }

        return images
    }

    private static func generateLayoutBackgroundImage(_ collectible: Collectible) async -> UIImage {
        let width: CGFloat = 1080
        let aspectRatio: CGFloat = 3.0 / 5.0
        let medalImage = await collectible.medalImage ?? UIImage()

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let size = CGSize(width: width,
                                  height: width * 1.0 / aspectRatio)
                UIGraphicsBeginImageContextWithOptions(size, true, 1)
                let context = UIGraphicsGetCurrentContext()!

                context.setFillColor(UIColor.black.cgColor)
                context.fill(CGRect(origin: .zero, size: size))

                let medalImageWidth = width * 0.5
                let medalImageHeight = medalImageWidth * 1.53

                medalImage.draw(in: CGRect(x: size.width / 2 - medalImageWidth / 2,
                                           y: size.height / 2 - medalImageHeight / 2,
                                           width: medalImageWidth,
                                           height: medalImageHeight))

                if !collectible.type.confettiColors.isEmpty {
                    drawConfetti(collectible.type.confettiColors, inContext: context)
                }

                let finalImage = UIGraphicsGetImageFromCurrentImageContext()!
                UIGraphicsEndImageContext()
                continuation.resume(returning: finalImage)
            }
        }
    }

    static func makeInstagramStoryImage(_ collectible: Collectible,
                                        includeConfetti: Bool = true,
                                        includeMedal: Bool = true) async -> UIImage {
        let width: CGFloat = 1080
        let aspectRatio: CGFloat = 9.0 / 16.0
        let size = CGSize(width: width,
                          height: width * 1.0 / aspectRatio)
        UIGraphicsBeginImageContextWithOptions(size, true, 1)
        let context = UIGraphicsGetCurrentContext()!

        context.setFillColor(UIColor.black.cgColor)
        context.fill(CGRect(origin: .zero, size: size))

        if NSUbiquitousKeyValueStore.default.shouldShowAnyDistanceBranding {
            let watermark = UIImage(named: "watermark_v2")!
            let desiredWidth = size.width * 0.2
            let watermarkFrame = CGRect(x: size.width / 2 - desiredWidth / 2,
                                        y: 130,
                                        width: desiredWidth,
                                        height: desiredWidth * watermark.size.height / watermark.size.width)
            watermark.draw(in: watermarkFrame)
        }

        if includeMedal {
            let medalImage = await collectible.medalImage ?? UIImage()
            let medalImageWidth = width * 0.61
            let medalImageHeight = medalImageWidth * 1.53

            medalImage.draw(in: CGRect(x: size.width / 2 - medalImageWidth / 2,
                                       y: size.height / 2 - medalImageHeight / 1.6,
                                       width: medalImageWidth,
                                       height: medalImageHeight))
        }

        let leftRightMargin: CGFloat = 100
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.lineBreakMode = .byWordWrapping
        let descriptionString = NSAttributedString(string: collectible.typeDescription,
                                                   attributes: [.font: UIFont.monospacedSystemFont(ofSize: 45.0, weight: .regular),
                                                                .paragraphStyle: style,
                                                                .foregroundColor: UIColor.white])
        descriptionString.draw(in: CGRect(x: leftRightMargin, y: size.height * 0.77, width: size.width - leftRightMargin * 2, height: 54))

        var fontSize: CGFloat = 150
        let str = collectible.shorterDescription.uppercased() as NSString

        var attributes: [NSAttributedString.Key : Any] {
            return [.font: UIFont.presicav(size: fontSize, weight: .heavy),
                    .paragraphStyle: style,
                    .foregroundColor: UIColor.white]
        }

        while str.size(withAttributes: attributes).width > size.width - leftRightMargin * 2 {
            fontSize -= 1
        }

        let typeDescriptionString = NSAttributedString(string: str as String,
                                                       attributes: attributes)
        typeDescriptionString.draw(in: CGRect(x: leftRightMargin, y: size.height * 0.81, width: size.width - leftRightMargin * 2, height: 191))

        if includeConfetti {
            drawConfetti(collectible.type.confettiColors, inContext: context)
        }

        let finalImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return finalImage
    }

    static func make3DBackgroundImage(forCollectible collectible: Collectible) -> UIImage {
        let width: CGFloat = 1080
        let aspectRatio: CGFloat = 9.0 / 16.0
        let size = CGSize(width: width,
                          height: width * 1.0 / aspectRatio)
        UIGraphicsBeginImageContextWithOptions(size, true, 1)
        let context = UIGraphicsGetCurrentContext()!

        context.setFillColor(UIColor.black.cgColor)
        context.fill(CGRect(origin: .zero, size: size))

        // Watermark

        if NSUbiquitousKeyValueStore.default.shouldShowAnyDistanceBranding {
            let watermark = UIImage(named: "watermark_v2")!
            let desiredWidth = size.width * 0.2
            let watermarkFrame = CGRect(x: size.width / 2 - desiredWidth / 2,
                                        y: 130,
                                        width: desiredWidth,
                                        height: desiredWidth * watermark.size.height / watermark.size.width)
            watermark.draw(in: watermarkFrame)
        }

        // Description

        let leftRightMargin: CGFloat = 100
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.lineBreakMode = .byWordWrapping
        let descriptionString = NSAttributedString(string: collectible.typeDescription,
                                                   attributes: [.font: UIFont.monospacedSystemFont(ofSize: 45.0, weight: .regular),
                                                                .paragraphStyle: style,
                                                                .foregroundColor: UIColor.white])
        descriptionString.draw(in: CGRect(x: leftRightMargin,
                                          y: size.height * 0.71,
                                          width: size.width - leftRightMargin * 2,
                                          height: 54))

        // Type description

        var fontSize: CGFloat = 150
        let str = collectible.shorterDescription.uppercased() as NSString

        var attributes: [NSAttributedString.Key : Any] {
            return [.font: UIFont.presicav(size: fontSize, weight: .heavy),
                    .paragraphStyle: style,
                    .foregroundColor: UIColor.white]
        }

        while str.size(withAttributes: attributes).width > size.width - leftRightMargin * 2 {
            fontSize -= 1
        }

        let typeDescriptionString = NSAttributedString(string: str as String,
                                                       attributes: attributes)
        let typeDescriptionRect = CGRect(x: leftRightMargin,
                                         y: size.height * 0.75,
                                         width: size.width - leftRightMargin * 2,
                                         height: 191)
        typeDescriptionString.draw(in: typeDescriptionRect)

        // Subtitle

        let subtitleString = NSAttributedString(string: collectible.subtitle ?? "",
                                                attributes: [.font: UIFont.monospacedSystemFont(ofSize: 35.0, weight: .regular),
                                                             .paragraphStyle: style,
                                                             .foregroundColor: UIColor.white.withAlphaComponent(0.6)])

        let typeDescriptionSize = typeDescriptionString.boundingRect(with: typeDescriptionRect.size, context: nil).size

        subtitleString.draw(in: CGRect(x: leftRightMargin,
                                       y: (size.height * 0.75) + typeDescriptionSize.height + 35,
                                       width: size.width - leftRightMargin * 2,
                                       height: 40))

        let finalImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return finalImage
    }

    private static func makeInstagramFeedImage(_ collectible: Collectible) async -> UIImage {
        let width: CGFloat = 1920
        let size = CGSize(width: width,
                          height: width)
        UIGraphicsBeginImageContextWithOptions(size, true, 1)
        let context = UIGraphicsGetCurrentContext()!

        context.setFillColor(UIColor.black.cgColor)
        context.fill(CGRect(origin: .zero, size: size))

        if NSUbiquitousKeyValueStore.default.shouldShowAnyDistanceBranding {
            let watermark = UIImage(named: "watermark_v2")!
            let desiredWidth = size.width * 0.18
            let watermarkFrame = CGRect(x: size.width / 2 - desiredWidth / 2,
                                        y: 80,
                                        width: desiredWidth,
                                        height: desiredWidth * watermark.size.height / watermark.size.width)
            watermark.draw(in: watermarkFrame)
        }

        let medalImage = await collectible.medalImage ?? UIImage()
        let medalImageWidth = width * 0.38
        let medalImageHeight = medalImageWidth * 1.53

        medalImage.draw(in: CGRect(x: size.width / 2 - medalImageWidth / 2,
                                   y: size.height / 2 - medalImageHeight / 1.6,
                                   width: medalImageWidth,
                                   height: medalImageHeight))

        let leftRightMargin: CGFloat = 100
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.lineBreakMode = .byWordWrapping
        let descriptionString = NSAttributedString(string: collectible.typeDescription,
                                                   attributes: [.font: UIFont.monospacedSystemFont(ofSize: 45.0, weight: .regular),
                                                                .paragraphStyle: style,
                                                                .foregroundColor: UIColor.white])
        descriptionString.draw(in: CGRect(x: leftRightMargin, y: size.height * 0.77, width: size.width - leftRightMargin * 2, height: 54))

        var fontSize: CGFloat = 150
        let str = collectible.shorterDescription.uppercased() as NSString

        var attributes: [NSAttributedString.Key : Any] {
            return [.font: UIFont.presicav(size: fontSize, weight: .heavy),
                    .paragraphStyle: style,
                    .foregroundColor: UIColor.white]
        }

        while str.size(withAttributes: attributes).width > size.width - leftRightMargin * 2 {
            fontSize -= 1
        }

        let typeDescriptionString = NSAttributedString(string: str as String,
                                                       attributes: attributes)
        typeDescriptionString.draw(in: CGRect(x: leftRightMargin, y: size.height * 0.81, width: size.width - leftRightMargin * 2, height: 191))

        drawConfetti(collectible.type.confettiColors, inContext: context)

        let finalImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return finalImage
    }

    private static func makeTwitterImage(_ collectible: Collectible) async -> UIImage {
        let width: CGFloat = 1080
        let aspectRatio: CGFloat = 3.0 / 4.0
        let size = CGSize(width: width,
                          height: width * 1.0 / aspectRatio)
        UIGraphicsBeginImageContextWithOptions(size, true, 1)
        let context = UIGraphicsGetCurrentContext()!

        context.setFillColor(UIColor.black.cgColor)
        context.fill(CGRect(origin: .zero, size: size))

        if NSUbiquitousKeyValueStore.default.shouldShowAnyDistanceBranding {
            let watermark = UIImage(named: "watermark_v2")!
            let desiredWidth = size.width * 0.2
            let watermarkFrame = CGRect(x: size.width / 2 - desiredWidth / 2,
                                        y: 60,
                                        width: desiredWidth,
                                        height: desiredWidth * watermark.size.height / watermark.size.width)
            watermark.draw(in: watermarkFrame)
        }

        let medalImage = await collectible.medalImage ?? UIImage()
        let medalImageWidth = width * 0.53
        let medalImageHeight = medalImageWidth * 1.53

        medalImage.draw(in: CGRect(x: size.width / 2 - medalImageWidth / 2,
                                   y: size.height / 2 - medalImageHeight / 1.6,
                                   width: medalImageWidth,
                                   height: medalImageHeight))

        let leftRightMargin: CGFloat = 100
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.lineBreakMode = .byWordWrapping
        let descriptionString = NSAttributedString(string: collectible.typeDescription,
                                                   attributes: [.font: UIFont.monospacedSystemFont(ofSize: 40.0, weight: .regular),
                                                                .paragraphStyle: style,
                                                                .foregroundColor: UIColor.white])
        descriptionString.draw(in: CGRect(x: leftRightMargin, y: size.height * 0.765, width: size.width - leftRightMargin * 2, height: 54))

        var fontSize: CGFloat = 120
        let str = collectible.shorterDescription.uppercased() as NSString

        var attributes: [NSAttributedString.Key : Any] {
            return [.font: UIFont.presicav(size: fontSize, weight: .heavy),
                    .paragraphStyle: style,
                    .foregroundColor: UIColor.white]
        }

        while str.size(withAttributes: attributes).width > size.width - leftRightMargin * 2 {
            fontSize -= 1
        }

        let typeDescriptionString = NSAttributedString(string: str as String,
                                                       attributes: attributes)
        typeDescriptionString.draw(in: CGRect(x: leftRightMargin, y: size.height * 0.81, width: size.width - leftRightMargin * 2, height: 191))

        drawConfetti(collectible.type.confettiColors, inContext: context)

        let finalImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return finalImage
    }

    static func drawConfetti(_ colors: [UIColor], inContext context: CGContext, scale: CGFloat = 1, count: Int = 250, rect: CGRect? = nil) {
        let originalImage = UIImage(named: "confetti_big")!
        let images = colors.map { originalImage.withTintColor($0) }

        for _ in 0..<count {
            var randPoint: CGPoint {
                if let rect = rect {
                    return CGPoint(x: (rect.origin.x + CGFloat.random(in: 0...CGFloat(rect.width))),
                                   y: (rect.origin.y + CGFloat.random(in: 0...CGFloat(rect.height))))
                }

                return CGPoint(x: CGFloat.random(in: 0...CGFloat(context.width)),
                               y: CGFloat.random(in: 0...CGFloat(context.height)))
            }
            let randSize = CGFloat.random(in: (12 * scale)...(40 * scale))
            let randRotation = CGFloat.random(in: 0...(2 * .pi))
            guard let randImage = images.randomElement() else {
                return
            }

            context.saveGState()
            context.translateBy(x: CGFloat(randPoint.x), y: CGFloat(randPoint.y))
            // Rotate around middle
            context.rotate(by: randRotation)
            context.translateBy(x: CGFloat(randPoint.x) / -2, y: CGFloat(randPoint.y) / -2)
            // Draw the image at its center
            randImage.draw(in: CGRect(x: randPoint.x, y: randPoint.y, width: randSize, height: randSize))
            context.restoreGState()
        }
    }
}
