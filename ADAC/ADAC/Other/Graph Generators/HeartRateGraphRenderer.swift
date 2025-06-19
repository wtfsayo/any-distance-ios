// Licensed under the Any Distance Source-Available License
//
//  HeartRateGraphRenderer.swift
//  ADAC
//
//  Created by Daniel Kuntz on 10/19/21.
//

import UIKit

final class HeartRateGraphGenerator {
    static let size = HeartRateGraph.defaultSize
    static let dotWidth = HeartRateGraph.dotWidth
    static let spacing = HeartRateGraph.spacing
    static let lineWidth: CGFloat = 14.0
    static let padding: CGFloat = 200.0

    static let regFont = UIFont.presicav(size: 45)
    static let boldFont = UIFont.presicav(size: 45, weight: .heavy)

    static func renderGraph(with palette: Palette = .dark,
                            size: CGSize = HeartRateGraph.defaultSize,
                            samples: [HeartRateSample],
                            completion: @escaping ((UIImage?) -> Void)) {
        guard !samples.isEmpty else {
            completion(nil)
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let hrMin = samples.min(by: { $0.minimumBpm < $1.minimumBpm })?.minimumBpm ?? 0
            let hrMax = samples.max(by: { $0.maximumBpm < $1.maximumBpm })?.maximumBpm ?? 0
            let hrRange = hrMax - hrMin

            let renderer = UIGraphicsImageRenderer(size: size)

            let image = renderer.image { ctx in
                ctx.cgContext.saveGState()
                let flipVertical = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: size.height)
                ctx.cgContext.concatenate(flipVertical)

                let boldAttributes: [NSAttributedString.Key : Any] = [.font: boldFont as Any,
                                                                      .foregroundColor: palette.foregroundColor]
                let regAttributes: [NSAttributedString.Key : Any] = [.font: regFont as Any,
                                                                     .foregroundColor: palette.foregroundColor]
                let unitString = NSAttributedString(string: "BPM",
                                                    attributes: regAttributes)

                var hasDrawnMinLabel: Bool = false
                var hasDrawnMaxLabel: Bool = false

                let spacingForData = ((size.width / CGFloat(samples.count)) - dotWidth).clamped(to: spacing...100)

                for (i, datum) in samples.enumerated() {
                    // Draw avg dot
                    ctx.cgContext.setFillColor(palette.foregroundColor.cgColor)
                    let heightMinusPadding = size.height - padding * 2
                    let dotFrame = CGRect(x: CGFloat(i) * (dotWidth + spacingForData) + ((dotWidth + spacingForData) / 2),
                                          y: padding + heightMinusPadding * ((datum.averageBpm - hrMin) / hrRange) - dotWidth / 2,
                                          width: dotWidth,
                                          height: dotWidth)

                    if dotFrame.maxX <= size.width {
                        let dotPath = UIBezierPath(roundedRect: dotFrame, cornerRadius: dotFrame.width / 2)
                        dotPath.fill()

                        // Draw min-max line
                        ctx.cgContext.setFillColor(palette.foregroundColor.withAlphaComponent(0.6).cgColor)
                        let lineFrame = CGRect(x: dotFrame.midX - (lineWidth / 2),
                                               y: padding + heightMinusPadding * ((datum.minimumBpm - hrMin) / hrRange),
                                               width: lineWidth,
                                               height: heightMinusPadding * ((datum.maximumBpm - datum.minimumBpm) / hrRange))

                        let linePath = UIBezierPath(roundedRect: lineFrame, cornerRadius: lineFrame.width / 2)
                        linePath.fill()

                        ctx.cgContext.saveGState()
                        ctx.cgContext.concatenate(flipVertical)
                        // Draw Text
                        if datum.minimumBpm == hrMin && !hasDrawnMinLabel {
                            let string = NSMutableAttributedString(string: "▼\(Int(datum.minimumBpm))",
                                                                   attributes: boldAttributes)
                            string.append(unitString)
                            let stringSize = string.size()
                            let centerY = size.height - (padding + heightMinusPadding * ((datum.minimumBpm - hrMin) / hrRange))
                            let x = (dotFrame.midX - (stringSize.width / 2)).clamped(to: 0...(size.width - stringSize.width))
                            string.draw(at: CGPoint(x: x, y: centerY + 30))
                            hasDrawnMinLabel = true
                        }

                        if datum.maximumBpm == hrMax && !hasDrawnMaxLabel {
                            let string = NSMutableAttributedString(string: "▲\(Int(datum.maximumBpm))",
                                                                   attributes: boldAttributes)
                            string.append(unitString)
                            let stringSize = string.size()
                            let centerY = size.height - (padding + heightMinusPadding * ((datum.maximumBpm - hrMin) / hrRange))
                            let x = (dotFrame.midX - (stringSize.width / 2)).clamped(to: 0...(size.width - stringSize.width))
                            string.draw(at: CGPoint(x: x,
                                                    y: centerY - stringSize.height - 30))
                            hasDrawnMaxLabel = true
                        }

                        ctx.cgContext.restoreGState()
                    }
                }

                ctx.cgContext.restoreGState()
            }

            UIGraphicsBeginImageContext(size)
            let context = UIGraphicsGetCurrentContext()
            context?.setShadow(offset: .zero, blur: lineWidth * 2, color: UIColor.black.withAlphaComponent(0.3).cgColor)
            image.draw(in: CGRect(origin: .zero, size: size))
            let shadowImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()

            DispatchQueue.main.async {
                completion(shadowImage)
            }
        }
    }
}

struct HeartRateGraph {
    static let defaultSize = CGSize(width: 1500, height: 1500)
    static let dotWidth: CGFloat = 30.0
    static let spacing: CGFloat = 8.0

    static var numberOfSamplesToRequest: Double {
        return 38.0
    }

    static var numberOfSamplesRequired: Double {
        return 5.0
    }
}
