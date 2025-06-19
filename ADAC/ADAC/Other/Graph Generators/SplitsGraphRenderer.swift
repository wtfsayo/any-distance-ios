// Licensed under the Any Distance Source-Available License
//
//  SplitsGraphRenderer.swift
//  ADAC
//
//  Created by Daniel Kuntz on 5/9/22.
//

import UIKit

class SplitsGraphRenderer {
    static let size = CGSize(width: 2000, height: 2000)
    static let lineHeight: CGFloat = 30
    static let rowSpacing: CGFloat = 61
    static let leftRightMargin: CGFloat = 0
    static let leftColumnWidth: CGFloat = 168
    static let rightColumnWidth: CGFloat = 413
    static let headerFont: UIFont = UIFont.presicav(size: 84.0, weight: .bold)
    static let rowFont: UIFont = UIFont.monospacedSystemFont(ofSize: 101, weight: .medium)

    static func renderGraph(withSplits splits: [Split],
                            speedInsteadOfPace: Bool,
                            palette: Palette = .dark,
                            showsUnitLabel: Bool = true,
                            limit: Int = 10,
                            completion: @escaping (UIImage?) -> Void) {
        guard !splits.isEmpty else {
            completion(nil)
            return
        }

        var splits = splits
        if splits.count > limit {
            splits = Array(splits[0..<limit])
        }

        let unit = ADUser.current.distanceUnit

        DispatchQueue.global(qos: .userInitiated).async {
            let rowHeight = "000".height(withConstrainedWidth: .greatestFiniteMagnitude,
                                         font: rowFont)
            let headerHeight = String("MI").height(withConstrainedWidth: .greatestFiniteMagnitude,
                                                   font: headerFont)
            let totalHeight = headerHeight + ((rowHeight + rowSpacing) * CGFloat(splits.count))
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: size.width, height: totalHeight))

            let image = renderer.image { ctx in
                ctx.cgContext.setFillColor(palette.foregroundColor.cgColor)
                ctx.cgContext.setStrokeColor(UIColor.clear.cgColor)

                let unitOrLapString = showsUnitLabel ? unit.abbreviation : "LAP"
                NSString(string: unitOrLapString.uppercased()).draw(at: CGPoint(x: leftRightMargin,
                                                                                y: 0.0),
                                                                    withAttributes: [.font: headerFont,
                                                                                     .foregroundColor: palette.foregroundColor])

                let rightAlginStyle = NSMutableParagraphStyle()
                rightAlginStyle.alignment = .right

                let labelRect: CGRect = CGRect(x: leftRightMargin + leftColumnWidth,
                                               y: 0.0,
                                               width: rightColumnWidth,
                                               height: headerHeight)
                let string = NSString(string: speedInsteadOfPace ? (splits[0].unit.speedAbbreviation.uppercased()) : "PACE")
                string.draw(in: labelRect,
                            withAttributes: [.font: headerFont,
                                             .foregroundColor: palette.foregroundColor,
                                             .paragraphStyle: rightAlginStyle])

                let splitValues = splits.map { speedInsteadOfPace ? $0.avgSpeedInUnit : $0.duration }
                let maxSplit = splitValues.max()!
                let minSplit = splitValues.min()!

                for (i, split) in splits.enumerated() {
                    let color = (speedInsteadOfPace ? (splitValues[i] == maxSplit) : (splitValues[i] == minSplit)) ? palette.accentColor : palette.foregroundColor

                    let y = headerHeight + rowSpacing + (CGFloat(i) * (rowHeight + rowSpacing))
                    NSString(string: (i+1) < 10 ? "0\(i+1)" : String(i+1)).draw(at: CGPoint(x: leftRightMargin, y: y),
                                                                        withAttributes: [.font: rowFont,
                                                                                         .foregroundColor: color])

                    let string = speedInsteadOfPace ? "\(split.avgSpeedInUnit.rounded(toPlaces: 1))" : split.duration.timeFormatted()
                    NSString(string: string).draw(in: CGRect(x: leftRightMargin + leftColumnWidth,
                                                                        y: y,
                                                                        width: rightColumnWidth,
                                                                        height: rowHeight),
                                                             withAttributes: [.font: rowFont,
                                                                              .foregroundColor: color,
                                                                              .paragraphStyle: rightAlginStyle])

                    let remainingWidth = (size.width - (leftRightMargin * 2)) - leftColumnWidth - rightColumnWidth - rowSpacing
                    let lineWidth = (splitValues[i] / maxSplit) * remainingWidth
                    let lineX = leftRightMargin + leftColumnWidth + rightColumnWidth + rowSpacing
                    let lineY = (y + (rowHeight / 2)) - (lineHeight / 2)

                    color.setFill()
                    UIBezierPath(roundedRect: CGRect(x: lineX,
                                                     y: lineY,
                                                     width: lineWidth,
                                                     height: lineHeight),
                                 cornerRadius: lineHeight / 2).fill()
                }
            }

            DispatchQueue.main.async {
                completion(image)
            }
        }
    }
}
