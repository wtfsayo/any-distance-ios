// Licensed under the Any Distance Source-Available License
//
//  WatchHeartRateGraphGenerator.swift
//  Any Distance WatchKit Extension
//
//  Created by Daniel Kuntz on 10/13/22.
//

import UIKit

struct WatchHeartRateGraphGenerator {
    static func generateGraphImage(_ data: [HeartRateSample]) async -> UIImage? {
        return await withCheckedContinuation { continuation in
            Task(priority: .userInitiated) {
                let size = CGSize(width: 400, height: 200)
                let lrMargin: CGFloat = 10
                UIGraphicsBeginImageContextWithOptions(size, false, 1)
                let ctx = UIGraphicsGetCurrentContext()

                func drawDottedLine(from: CGPoint, to: CGPoint) {
                    let dotWidth: CGFloat = 5
                    let dotSpacing: CGFloat = 9

                    let length = sqrt(pow(to.x - from.x, 2) + pow(to.y - from.y, 2))
                    let numDots = Int(length / dotSpacing)
                    let xSpacing = (from.x - to.x) / CGFloat(numDots)
                    let ySpacing = (from.y - to.y) / CGFloat(numDots)

                    var curPoint: CGPoint = from
                    var dotNumber: Int = 0

                    while dotNumber <= numDots {
                        ctx?.fillEllipse(in: CGRect(x: curPoint.x - dotWidth / 2,
                                                    y: curPoint.y - dotWidth / 2,
                                                    width: dotWidth,
                                                    height: dotWidth))
                        curPoint = CGPoint(x: curPoint.x - xSpacing,
                                           y: curPoint.y - ySpacing)
                        dotNumber += 1
                    }
                }

                let graphBottomMargin: CGFloat = 45

                // Draw labels and lines
                ctx?.setFillColor(UIColor(white: 0.5, alpha: 1.0).cgColor)
                drawDottedLine(from: CGPoint(x: lrMargin, y: 4),
                               to: CGPoint(x: lrMargin, y: size.height - graphBottomMargin))
                drawDottedLine(from: CGPoint(x: size.width / 2, y: 4),
                               to: CGPoint(x: size.width / 2, y: size.height - graphBottomMargin))
                NSString("10m ago").draw(at: CGPoint(x: lrMargin - 5, y: size.height - 40),
                                         withAttributes: [.font: UIFont.systemFont(ofSize: 30, weight: .medium),
                                                          .foregroundColor: UIColor.white.withAlphaComponent(0.6)])
                NSString("5m ago").draw(at: CGPoint(x: size.width / 2 - 5, y: size.height - 40),
                                        withAttributes: [.font: UIFont.systemFont(ofSize: 30, weight: .medium),
                                                         .foregroundColor: UIColor.white.withAlphaComponent(0.6)])

                if !data.isEmpty {
                    // Draw data points
                    let minBpm = data.map { $0.minimumBpm }.min()!
                    let maxBpm = data.map { $0.maximumBpm }.max()!
                    let bpmRange = maxBpm - minBpm
                    let endTime = Date(timeIntervalSince1970: Double(30 * Int((Date().timeIntervalSince1970 / 30).rounded()))).timeIntervalSince1970
                    let startTime = endTime - 600

                    for datum in data {
                        let midTime = datum.startDate.timeIntervalSince1970
                        let timeFraction = (midTime - startTime) / (endTime - startTime)

                        // Draw bar
                        let barWidth: CGFloat = 8
                        let barHeight = (size.height - graphBottomMargin) * ((datum.maximumBpm - datum.minimumBpm) / bpmRange)
                        let barX = lrMargin + (timeFraction * (size.width - (lrMargin * 2))) - (barWidth / 2)
                        let barY = size.height - (graphBottomMargin + ((size.height - graphBottomMargin) * ((datum.maximumBpm - minBpm) / bpmRange)))

                        let path = UIBezierPath(roundedRect: CGRect(x: barX,
                                                                    y: barY,
                                                                    width: barWidth,
                                                                    height: barHeight),
                                                cornerRadius: barWidth / 2)
                        ctx?.setFillColor(UIColor(red: 0.6, green: 0, blue: 0, alpha: 1).cgColor)
                        path.fill()

                        // Draw dot
                        let dotWidth: CGFloat = 12
                        let dotX = barX + (barWidth / 2) - (dotWidth / 2)
                        let dotY = size.height - (graphBottomMargin + ((size.height - graphBottomMargin) * ((datum.averageBpm - minBpm) / bpmRange)))
                        ctx?.setFillColor(UIColor.red.cgColor)
                        ctx?.fillEllipse(in: CGRect(x: dotX, y: dotY, width: dotWidth, height: dotWidth))
                    }
                }

                let image = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                continuation.resume(returning: image)
            }
        }
    }
}
