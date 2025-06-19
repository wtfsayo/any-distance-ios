// Licensed under the Any Distance Source-Available License
//
//  ActivitySummaryShareImageGenerator.swift
//  ADAC
//
//  Created by Daniel Kuntz on 4/21/22.
//

import UIKit
import UIImageColors
import SDWebImage

class ActivitySummaryShareImageGenerator {

    static let cellSize: CGSize = CGSize(width: 400, height: 84)
    static let cellSpacing: CGFloat = 10
    static let padding: CGFloat = 20
    static let cellCornerRadius: CGFloat = 16
    static let activityTypeImageSize: CGSize = CGSize(width: 53, height: 45)
    static let medalImageSize: CGSize = CGSize(width: 43, height: 66)
    static let miniRouteImageSize: CGSize = CGSize(width: 60, height: 60)
    static let titleFont: UIFont? = UIFont.presicav(size: 20.0, weight: .bold)
    static let smallerTitleFont: UIFont? = UIFont.presicav(size: 15.0, weight: .bold)
    static let subtitleFont: UIFont? = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    static let arrowGlyph: UIImage = UIImage(named: "glyph_cell_arrow")!
    static let arrowGlyphSize: CGSize = CGSize(width: 28, height: 27)

    private struct Cell {
        var date: Date
        var type: CellType
        var userImage: UIImage?
        var rightImage: UIImage?
        var titleText: String
        var subtitleText: String
        var graphImage: UIImage?
        var confettiColors: [UIColor]?
    }

    private enum CellType {
        case activity
        case collectible
        case stepCount
    }

    static func generateShareImages(forTableViewDataPoints dataPoints: [AnyHashable],
                                    backgroundImage: UIImage?,
                                    progress: @escaping (Float) -> Void) async -> ShareImages {
        var p: Float = 0
        let timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { _ in
            p += (1 / Float(dataPoints.count)) * 0.002
            let prog = p.clamped(to: 0...0.5)
            DispatchQueue.main.async {
                progress(prog)
            }
        }

        // Fetch data
        let dataPoints = dataPoints.reversed()
        let cells: [Cell] = await withTaskGroup(of: [Cell].self) { group in
            for (i, dataPoint) in dataPoints.enumerated() {
                group.addTask {
                    if let activityDataPoint = dataPoint as? ActivityDataPoint,
                       let activity = ActivitiesData.shared.activity(with: activityDataPoint.id) {
                        let routeImage = try? await activity.routeImageMini
                        let formattedDate = activityDataPoint.formattedDateShort
                        let photo = await activity.design.photo
                        let userImage = await activity.design.photoWithFilter ?? photo
                        return [Cell(date: activity.startDateLocal,
                                     type: .activity,
                                     userImage: userImage,
                                     rightImage: activityDataPoint.typeGlyph,
                                     titleText: activityDataPoint.bigLabelText,
                                     subtitleText: formattedDate,
                                     graphImage: routeImage)]
                    } else if let collectibleDataPoint = dataPoint as? CollectibleDataPoint {
                        var cellArray: [Cell] = []
                        for collectible in collectibleDataPoint.collectibles {
                            guard let medalImageUrl = collectible.medalImageUrl else {
                                continue
                            }

                            let medalImage = await withCheckedContinuation { continuation in
                                SDWebImageManager.shared.loadImage(with: medalImageUrl, progress: nil) { image, data, error, cacheType, finished, url in
                                    continuation.resume(returning: image)
                                }
                            }

                            cellArray.append(Cell(date: collectible.sortDate,
                                                  type: .collectible,
                                                  rightImage: medalImage,
                                                  titleText: collectible.description,
                                                  subtitleText: collectible.typeDescription,
                                                  confettiColors: collectible.type.confettiColors))
                        }
                        return cellArray
                    } else if let stepCountDataPoint = dataPoint as? StepCountDataPoint {
                        let photo = await stepCountDataPoint.stepCount.design.photo
                        let userImage = await stepCountDataPoint.stepCount.design.photoWithFilter ?? photo ?? backgroundImage
                        let graphImage = await stepCountDataPoint.stepCount.stepCountsGraphImage(with: stepCountDataPoint.stepCount.design.palette)
                        return [Cell(date: Date(timeIntervalSince1970: 0),
                                     type: .stepCount,
                                     userImage: userImage,
                                     rightImage: DailyStepCount.glyph,
                                     titleText: stepCountDataPoint.formattedStepCount + " Steps",
                                     subtitleText: stepCountDataPoint.formattedDate,
                                     graphImage: graphImage)]
                    }

                    return []
                }
            }

            var cells: [Cell] = []

            for await cellArray in group {
                cells.append(contentsOf: cellArray)
            }

            return cells
        }

        timer.invalidate()
        await MainActor.run {
            progress(0.5)
        }

        // Make overlay image
        let overlayImage = makeOverlayImage(withCells: cells)
        let stepCountBackgroundImage = cells.first(where: { $0.type == .stepCount && $0.userImage != nil })?.userImage
        let blurredStepCountBG = stepCountBackgroundImage?.resized(withNewWidth: cellSize.width + (padding * 2),
                                                                   imageScale: 2).sd_blurredImage(withRadius: 20)
        await MainActor.run {
            progress(0.6)
        }

        // Draw resized images using overlay and background images
        let instaStory = makeFinalImage(withBackground: stepCountBackgroundImage,
                                        blurredBackground: blurredStepCountBG,
                                        cells: cells,
                                        overlay: overlayImage,
                                        aspectRatio: 9/16)
        await MainActor.run {
            progress(0.7)
        }

        let instaFeed = makeFinalImage(withBackground: stepCountBackgroundImage,
                                       blurredBackground: blurredStepCountBG,
                                       cells: cells,
                                       overlay: overlayImage,
                                       aspectRatio: 1/1)
        await MainActor.run {
            progress(0.85)
        }

        let twitter = makeFinalImage(withBackground: stepCountBackgroundImage,
                                     blurredBackground: blurredStepCountBG,
                                     cells: cells,
                                     overlay: overlayImage,
                                     aspectRatio: 3/4)
        await MainActor.run {
            progress(1)
        }

        return ShareImages(base: overlayImage,
                           instagramStory: instaStory,
                           instagramFeed: instaFeed,
                           twitter: twitter)
    }

    private static func makeOverlayImage(withCells cells: [Cell]) -> UIImage {
        // Draw overlay image
        let count = CGFloat(cells.count)
        let size = CGSize(width: cellSize.width + padding * 2,
                          height: cellSize.width + (padding * 2) + (cellSize.height * count) + (cellSpacing * (count - 1)))

        UIGraphicsBeginImageContextWithOptions(size, false, 2)
        let ctx = UIGraphicsGetCurrentContext()!

        if let stepCountCell = cells.first(where: { $0.type == .stepCount }) {
            // Draw step count graph image
            let graphImageRect = CGRect(x: padding,
                                        y: padding,
                                        width: cellSize.width,
                                        height: cellSize.width)
            drawAspectFitImage(stepCountCell.graphImage, inContext: ctx, inRect: graphImageRect)
        }

        for (i, cell) in cells.sorted(by: { $0.date < $1.date }).enumerated() {
            // Draw cell content
            switch cell.type {
            case .activity:
                drawActivityCell(cell, index: i, inContext: ctx)
            case .collectible:
                drawCollectibleCell(cell, index: i, inContext: ctx)
            case .stepCount:
                drawStepCountCell(cell, index: i, inContext: ctx)
            }
        }

        let overlayImage = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
        UIGraphicsEndImageContext()

        return overlayImage
    }

    private static func makeFinalImage(withBackground background: UIImage?,
                                       blurredBackground: UIImage?,
                                       cells: [Cell],
                                       overlay: UIImage,
                                       aspectRatio: CGFloat) -> UIImage {
        let size = CGSize(width: 1920 * aspectRatio, height: 1920)
        let overlayRect = CGSize.aspectFit(aspectRatio: overlay.size, boundingSize: size)

        UIGraphicsBeginImageContextWithOptions(size, true, 2)
        let ctx = UIGraphicsGetCurrentContext()!
        let fullRect = CGRect(origin: .zero, size: size)

        UIColor.black.setFill()
        ctx.fill(fullRect)

        drawAspectFillImage(background,
                            inContext: ctx,
                            inRect: fullRect,
                            cornerRadius: 0,
                            alpha: 0.5)

        for (i, cell) in cells.sorted(by: { $0.date < $1.date }).enumerated() {
            let bgColor = background != nil ? UIColor.black.withAlphaComponent(0.4) : UIColor(white: 0.11, alpha: 1)

            // Draw cell background
            var cellFrame = frame(forCell: cell, index: i)
            let scale = overlayRect.width / overlay.size.width
            cellFrame.size.width *= scale
            cellFrame.size.height *= scale
            cellFrame.origin.x *= scale
            cellFrame.origin.x += (size.width - overlayRect.width) / 2
            cellFrame.origin.y *= scale
            cellFrame.origin.y += (size.height - overlayRect.height) / 2

            if let image = cell.userImage, cell.type != .stepCount {
                drawAspectFillImage(image,
                                    inContext: ctx,
                                    inRect: cellFrame,
                                    cornerRadius: cellCornerRadius * scale,
                                    alpha: 0.5)
            } else {
                draw(inContext: ctx, clippedToRect: cellFrame, cornerRadius: cellCornerRadius * scale) { ctx in
                    drawAspectFillImage(blurredBackground,
                                        inContext: ctx,
                                        inRect: fullRect,
                                        cornerRadius: 0,
                                        alpha: 1)
                    ctx.setFillColor(bgColor.cgColor)
                    ctx.fill(cellFrame)
                }
            }
        }

        overlay.draw(in: overlayRect)

        if NSUbiquitousKeyValueStore.default.shouldShowAnyDistanceBranding {
            let watermark = UIImage(named: "watermark_v2")!
            let desiredWidth: CGFloat = 280
            let watermarkFrame = CGRect(x: 80,
                                        y: aspectRatio == 9/16 ? 180 : 80,
                                        width: desiredWidth,
                                        height: desiredWidth * watermark.size.height / watermark.size.width)
            watermark.draw(in: watermarkFrame)
        }

        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()

        return image
    }

    private static func drawActivityCell(_ cell: Cell, index: Int, inContext ctx: CGContext) {
        let cellFrame = frame(forCell: cell, index: index)

        drawAspectFitImage(cell.rightImage,
                           inContext: ctx,
                           inRect: CGRect(x: cellFrame.origin.x + 19,
                                          y: cellFrame.origin.y + 19,
                                          width: activityTypeImageSize.width,
                                          height: activityTypeImageSize.height))

        drawText(cell.titleText,
                 at: CGPoint(x: cellFrame.origin.x + 90,
                             y: cellFrame.origin.y + 20),
                 withFont: titleFont,
                 inContext: ctx)

        drawText(cell.subtitleText,
                 at: CGPoint(x: cellFrame.origin.x + 90,
                             y: cellFrame.origin.y + 48),
                 withFont: subtitleFont,
                 alpha: 0.75,
                 inContext: ctx)

        let padding = (cellFrame.height - miniRouteImageSize.height) / 2
        drawAspectFitImage(cell.graphImage,
                           inContext: ctx,
                           inRect: CGRect(x: cellFrame.origin.x + cellFrame.width - miniRouteImageSize.width - 20,
                                          y: cellFrame.origin.y + padding,
                                          width: miniRouteImageSize.width,
                                          height: miniRouteImageSize.height),
                           alpha: 0.75)
    }

    private static func drawCollectibleCell(_ cell: Cell, index: Int, inContext ctx: CGContext) {
        let cellFrame = frame(forCell: cell, index: index)

        drawAspectFitImage(cell.rightImage,
                           inContext: ctx,
                           inRect: CGRect(x: cellFrame.origin.x + 24,
                                          y: cellFrame.origin.y + 9,
                                          width: medalImageSize.width,
                                          height: medalImageSize.height))

        drawText(cell.subtitleText,
                 at: CGPoint(x: cellFrame.origin.x + 90,
                             y: cellFrame.origin.y + 19),
                 withFont: subtitleFont,
                 alpha: 0.75,
                 inContext: ctx)

        let maxTextWidth = cellSize.width - 110
        var textWidth = NSString(string: cell.titleText).size(withAttributes: [.font: titleFont]).width
        var font = titleFont
        while textWidth > maxTextWidth {
            font = font?.withSize((font?.pointSize ?? 1) - 1)
            textWidth = NSString(string: cell.titleText).size(withAttributes: [.font: font]).width
        }

        drawText(cell.titleText,
                 at: CGPoint(x: cellFrame.origin.x + 89,
                             y: cellFrame.origin.y + 36),
                 withFont: font,
                 inContext: ctx)

        if let confettiColors = cell.confettiColors {
            draw(inContext: ctx, clippedToRect: cellFrame, cornerRadius: cellCornerRadius) { ctx in
                CollectibleShareImageGenerator.drawConfetti(confettiColors,
                                                            inContext: ctx,
                                                            scale: 0.2,
                                                            count: 1000,
                                                            rect: cellFrame)
            }
        }
    }

    private static func drawStepCountCell(_ cell: Cell, index: Int, inContext ctx: CGContext) {
        let cellFrame = frame(forCell: cell, index: index)

        drawAspectFitImage(DailyStepCount.glyph,
                           inContext: ctx,
                           inRect: CGRect(x: cellFrame.origin.x + 19,
                                          y: cellFrame.origin.y + 19,
                                          width: activityTypeImageSize.width,
                                          height: activityTypeImageSize.height))

        drawText(cell.titleText,
                 at: CGPoint(x: cellFrame.origin.x + 90,
                             y: cellFrame.origin.y + 20),
                 withFont: titleFont,
                 inContext: ctx)

        drawText(cell.subtitleText,
                 at: CGPoint(x: cellFrame.origin.x + 90,
                             y: cellFrame.origin.y + 48),
                 withFont: subtitleFont,
                 alpha: 0.75,
                 inContext: ctx)
    }

    private static func drawArrow(inCellFrame cellFrame: CGRect, inContext ctx: CGContext) {
        drawAspectFitImage(arrowGlyph,
                           inContext: ctx,
                           inRect: CGRect(x: cellFrame.origin.x + 336,
                                          y: cellFrame.origin.y + 28.5,
                                          width: 28,
                                          height: 27))
    }

    private static func drawAspectFitImage(_ image: UIImage?, inContext ctx: CGContext, inRect rect: CGRect, alpha: CGFloat = 1) {
        guard let image = image else {
            return
        }

        let rect = CGSize.aspectFit(aspectRatio: image.size, inRect: rect)
        image.draw(in: rect, blendMode: .normal, alpha: alpha)
    }

    private static func drawAspectFillImage(_ image: UIImage?, inContext ctx: CGContext, inRect rect: CGRect, cornerRadius: CGFloat = cellCornerRadius, alpha: CGFloat = 1) {
        guard let image = image else {
            return
        }

        draw(inContext: ctx, clippedToRect: rect, cornerRadius: cornerRadius) { ctx in
            ctx.setFillColor(UIColor.black.cgColor)
            ctx.fill(rect)

            let imageRect = CGSize.aspectFill(aspectRatio: image.size, inRect: rect)
            image.draw(in: imageRect, blendMode: .normal, alpha: alpha)
        }
    }

    private static func drawText(_ text: String, at point: CGPoint, withFont font: UIFont?, alpha: CGFloat = 1, inContext ctx: CGContext) {
        if let font = font {
            let attributes: [NSAttributedString.Key: Any] = [.font: font,
                                                             .foregroundColor: UIColor.white.withAlphaComponent(alpha)]
            let attributedString = NSAttributedString(string: text, attributes: attributes)
            attributedString.draw(at: point)
        }
    }

    private static func draw(inContext ctx: CGContext, clippedToRect rect: CGRect, cornerRadius: CGFloat, drawCommands: @escaping (CGContext) -> Void) {
        ctx.saveGState()
        let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
        ctx.addPath(path.cgPath)
        ctx.clip()
        drawCommands(ctx)
        ctx.restoreGState()
    }

    private static func frame(forCell cell: Cell, index: Int) -> CGRect {
        let index = CGFloat(index)
        return CGRect(x: padding,
                      y: padding + (cellSize.height * index) + (cellSpacing * (index - 1)) + cellSize.width,
                      width: cellSize.width,
                      height: cellSize.height)
    }

    private static func blurImage(_ image: UIImage?, withRadius radius: CGFloat) -> UIImage? {
        guard let image = image else {
            return nil
        }

        let filter = CIFilter(name: "CIGaussianBlur")
        filter?.setValue(image.ciImage, forKey: kCIInputImageKey)
        filter?.setValue(radius, forKey: kCIInputRadiusKey)
        if let output = filter?.outputImage?.cgImage {
            if let croppedOutput = output.cropping(to: CGRect(x: (CGFloat(output.width) - image.size.width) / 2,
                                                              y: (CGFloat(output.height) - image.size.height) / 2,
                                                              width: image.size.width,
                                                              height: image.size.height)) {
                return UIImage(cgImage: croppedOutput)
            }
        }

        return image
    }
}
