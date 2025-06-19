// Licensed under the Any Distance Source-Available License
//
//  ElevationGraphRenderer.swift
//  ADAC
//
//  Created by Daniel Kuntz on 10/19/21.
//

import UIKit
import CoreLocation

struct ElevationGraphGenerator {
    static let size = CGSize(width: 1500, height: 1500)
    static let lineWidth: CGFloat = 12.75
    static let smoothing: Double = 0.4
    static let hPadding: CGFloat = 12
    static let vPadding: CGFloat = 80

    static let regFont = UIFont.presicav(size: 45)
    static let boldFont = UIFont.presicav(size: 45, weight: .heavy)

    static func renderGraph(withPalette palette: Palette = .dark,
                            coordinates coords: [CLLocation],
                            size: CGSize = size,
                            lineWidth: CGFloat = lineWidth,
                            completion: @escaping ((UIImage?) -> Void)) {
        guard !coords.isEmpty else {
            completion(nil)
            return
        }

        let s = max(1, coords.count / 250)
        let coords = stride(from: 0, to: coords.count - 1, by: s).map { coords[$0] }

        DispatchQueue.global(qos: .userInitiated).async {
            let elevationMin: CLLocationDistance = coords.min(by: { $0.altitude < $1.altitude })?.altitude ?? 0
            let elevationMax: CLLocationDistance = coords.max(by: { $0.altitude < $1.altitude })?.altitude ?? 0
            let elevationRange = elevationMax - elevationMin

            let timeMin = coords.first!.timestamp.timeIntervalSince1970
            let timeMax = coords.last!.timestamp.timeIntervalSince1970
            let timeRange = timeMax - timeMin

            let renderer = UIGraphicsImageRenderer(size: size)

            let image = renderer.image { ctx in
                ctx.cgContext.setStrokeColor(palette.foregroundColor.cgColor)
                ctx.cgContext.setLineWidth(lineWidth)
                ctx.cgContext.setLineJoin(.round)
                ctx.cgContext.setLineCap(.round)
                ctx.cgContext.beginPath()

                var prevY: Double = -1

                let boldAttributes: [NSAttributedString.Key : Any] = [.font: boldFont as Any,
                                                                      .foregroundColor: palette.foregroundColor]
                let regAttributes: [NSAttributedString.Key : Any] = [.font: regFont as Any,
                                                                     .foregroundColor: palette.foregroundColor]
                let unitString = NSAttributedString(string: ADUser.current.distanceUnit == .miles ? "ft" : "m",
                                                    attributes: regAttributes)

                var hasDrawnMinLabel: Bool = false
                var hasDrawnMaxLabel: Bool = false

                for (i, coord) in coords.enumerated() {
                    var x = hPadding + (size.width - (2 * hPadding)) * (coord.timestamp.timeIntervalSince1970 - timeMin) / timeRange
                    var y = vPadding + (size.height - (2 * vPadding)) * (1 - ((coord.altitude - elevationMin) / elevationRange))
                    x = floor(x)
                    y = floor(y)

                    // Smoothing
                    if prevY == -1 {
                        prevY = y
                    } else {
                        y = (y * (1 - smoothing)) + (prevY * smoothing)
                        prevY = y
                    }

                    if i == 0 {
                        ctx.cgContext.move(to: CGPoint(x: x, y: y))
                    }

                    ctx.cgContext.addLine(to: CGPoint(x: x, y: y))

                    if coord.altitude == elevationMin && !hasDrawnMinLabel {
                        let altitude = ADUser.current.distanceUnit == .miles ? UnitConverter.metersToFeet(coord.altitude) : coord.altitude
                        let string = NSMutableAttributedString(string: "▼\(Int(altitude))",
                                                               attributes: boldAttributes)
                        string.append(unitString)
                        let stringSize = string.size()
                        let drawX = (x - (stringSize.width / 2)).clamped(to: (hPadding * 2)...(size.width - stringSize.width))
                        string.draw(at: CGPoint(x: drawX, y: y + 30))
                        hasDrawnMinLabel = true
                    }

                    if coord.altitude == elevationMax && !hasDrawnMaxLabel {
                        let altitude = ADUser.current.distanceUnit == .miles ? UnitConverter.metersToFeet(coord.altitude) : coord.altitude
                        let string = NSMutableAttributedString(string: "▲\(Int(altitude))",
                                                               attributes: boldAttributes)
                        string.append(unitString)
                        let stringSize = string.size()
                        let drawX = (x - (stringSize.width / 2)).clamped(to: (hPadding * 2)...(size.width - stringSize.width))
                        string.draw(at: CGPoint(x: drawX, y: y - stringSize.height - 30))
                        hasDrawnMaxLabel = true
                    }
                }

                let path = ctx.cgContext.path!
                ctx.cgContext.drawPath(using: .stroke)

                ctx.cgContext.addPath(path)
                ctx.cgContext.addLine(to: CGPoint(x: size.width - hPadding, y: size.height))
                ctx.cgContext.addLine(to: CGPoint(x: hPadding, y: size.height))
                ctx.cgContext.clip()

                let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                          colors: [palette.foregroundColor.withAlphaComponent(0.25).cgColor,
                                                   palette.foregroundColor.withAlphaComponent(0).cgColor] as CFArray,
                                          locations: [0, 1])!
                ctx.cgContext.drawLinearGradient(gradient,
                                                 start: CGPoint(x: size.width / 2, y: 0),
                                                 end: CGPoint(x: size.width / 2, y: size.height),
                                                 options: [])
            }

            DispatchQueue.main.async {
                completion(image)
            }
        }
    }
}
