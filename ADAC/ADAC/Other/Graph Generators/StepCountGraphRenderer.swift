// Licensed under the Any Distance Source-Available License
//
//  StepCountGraphRenderer.swift
//  ADAC
//
//  Created by Daniel Kuntz on 4/9/21.
//

import UIKit

final class StepCountGraphRenderer {
    static func renderGraph(withPalette palette: Palette = .dark,
                            stepCounts: [Int],
                            completion: @escaping (UIImage?) -> Void) {
        if stepCounts.isEmpty {
            completion(nil)
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let imageSize = CGSize(width: 2000, height: 2000)
            let graphHeight = imageSize.height * 0.7
            var graphFrame = CGSize.aspectFit(aspectRatio: CGSize(width: imageSize.width,
                                                                  height: graphHeight),
                                              boundingSize: imageSize)
            graphFrame.origin.y = 120

            let lineWidth = (imageSize.width / CGFloat(stepCounts.count)) * 0.6
            let spacing = (imageSize.width - (lineWidth * CGFloat(stepCounts.count))) / CGFloat(stepCounts.count - 1)

            let renderer = UIGraphicsImageRenderer(size: imageSize)

            let image = renderer.image { ctx in
                ctx.cgContext.setFillColor(palette.foregroundColor.cgColor)
                ctx.cgContext.setStrokeColor(UIColor.clear.cgColor)
                ctx.cgContext.setLineWidth(lineWidth)

                let maxStepCount = stepCounts.max() ?? stepCounts[0]
                for (i, count) in stepCounts.enumerated() {
                    let x = CGFloat(i) * (lineWidth + spacing)
                    let height = max(graphFrame.height * CGFloat(count) / CGFloat(maxStepCount), lineWidth)
                    let y = (graphFrame.height - height) + graphFrame.origin.y
                    let rect = CGRect(x: x, y: y, width: lineWidth, height: height)

                    ctx.cgContext.beginPath()
                    ctx.cgContext.addPath(CGPath(roundedRect: rect,
                                                 cornerWidth: lineWidth / 2,
                                                 cornerHeight: lineWidth / 2,
                                                 transform: nil))
                    ctx.cgContext.closePath()
                    ctx.cgContext.fillPath()
                }

                ctx.cgContext.rotate(by: .pi / 2)
                ctx.cgContext.translateBy(x: 0, y: -1 * imageSize.width)
                let font = UIFont.monospacedSystemFont(ofSize: 60, weight: .semibold)

                NSString("6AM").draw(at: CGPoint(x: graphFrame.origin.y + graphFrame.height + 50,
                                                 y: (3 * imageSize.width / 4) - (font.lineHeight / 2)),
                                      withAttributes: [.font : font,
                                                       .foregroundColor: palette.foregroundColor])

                NSString("12PM").draw(at: CGPoint(x: graphFrame.origin.y + graphFrame.height + 50,
                                                  y: (imageSize.width / 2) - (font.lineHeight / 2)),
                                      withAttributes: [.font : font,
                                                       .foregroundColor: palette.foregroundColor])

                NSString("6PM").draw(at: CGPoint(x: graphFrame.origin.y + graphFrame.height + 50,
                                                 y: (imageSize.width / 4) - (font.lineHeight / 2)),
                                      withAttributes: [.font : font,
                                                       .foregroundColor: palette.foregroundColor])
            }

            UIGraphicsBeginImageContext(imageSize)
            let context = UIGraphicsGetCurrentContext()
            context?.setShadow(offset: .zero, blur: lineWidth * 2, color: UIColor.black.withAlphaComponent(0.3).cgColor)
            image.draw(in: CGRect(origin: .zero, size: imageSize))
            let shadowImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()

            DispatchQueue.main.async {
                completion(shadowImage)
            }
        }
    }

    static func renderTinyGraph(withPalette palette: Palette = .dark,
                                stepCounts: [Int],
                                completion: @escaping (UIImage?) -> Void) {
        if stepCounts.isEmpty {
            completion(nil)
            return
        }

        let stepCounts = stride(from: 0, to: stepCounts.count - 3, by: 3).map { idx in
            return Array(stepCounts[idx...idx+2]).avg()
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let imageSize = CGSize(width: 250, height: 250)
            let graphHeight = imageSize.height * 0.7
            var graphFrame = CGSize.aspectFit(aspectRatio: CGSize(width: imageSize.width,
                                                                  height: graphHeight),
                                              boundingSize: imageSize)
            graphFrame.origin.y = 15

            let lineWidth = ((imageSize.width / CGFloat(stepCounts.count)) * 0.6).rounded()
            let spacing = (imageSize.width - (lineWidth * CGFloat(stepCounts.count))) / CGFloat(stepCounts.count - 1)

            let renderer = UIGraphicsImageRenderer(size: imageSize)

            let image = renderer.image { ctx in
                ctx.cgContext.setFillColor(palette.foregroundColor.cgColor)
                ctx.cgContext.setStrokeColor(UIColor.clear.cgColor)
                ctx.cgContext.setLineWidth(lineWidth)

                let maxStepCount = stepCounts.max() ?? stepCounts[0]
                for (i, count) in stepCounts.enumerated() {
                    let x = CGFloat(i) * (lineWidth + spacing)
                    let height = max(graphFrame.height * CGFloat(count) / CGFloat(maxStepCount), lineWidth)
                    let y = (graphFrame.height - height) + graphFrame.origin.y
                    let rect = CGRect(x: x.rounded(),
                                      y: y.rounded(),
                                      width: lineWidth,
                                      height: height.rounded())

                    ctx.cgContext.beginPath()
                    ctx.cgContext.addPath(CGPath(roundedRect: rect,
                                                 cornerWidth: lineWidth / 2,
                                                 cornerHeight: lineWidth / 2,
                                                 transform: nil))
                    ctx.cgContext.closePath()
                    ctx.cgContext.fillPath()
                }
            }

            DispatchQueue.main.async {
                completion(image)
            }
        }
    }
}
