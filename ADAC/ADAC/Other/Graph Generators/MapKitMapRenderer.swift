// Licensed under the Any Distance Source-Available License
//
//  MapKitMapRenderer.swift
//  ADAC
//
//  Created by Daniel Kuntz on 4/4/23.
//

import UIKit
import CoreLocation
import MapKit
import SDWebImage

final class MapKitMapRenderer {
    static func generateMapImage(from locations: [CLLocation]) async -> UIImage? {
        let coordinates = locations.map { $0.coordinate }
        guard let minLat = coordinates.map({ $0.latitude }).min(),
              let maxLat = coordinates.map({ $0.latitude }).max(),
              let minLon = coordinates.map({ $0.longitude }).min(),
              let maxLon = coordinates.map({ $0.longitude }).max() else {
            return nil
        }

        let span = MKCoordinateSpan(latitudeDelta: (maxLat - minLat) * 10.5,
                                    longitudeDelta: (maxLon - minLon) * 10.5)
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2,
                                            longitude: ((minLon + maxLon) / 2))
        let region = MKCoordinateRegion(center: center, span: span)
        let rect = region.mapRect()
        let adjustedRect = MKMapRect(x: rect.minX,
                                     y: rect.minY,
                                     width: rect.width,
                                     height: rect.height)

        let outputSize: CGSize = CGSize(width: 600.0, height: 600.0)
        let options = MKMapSnapshotter.Options()
        options.mapRect = adjustedRect
        options.size = outputSize
        options.mapType = .mutedStandard
        options.showsBuildings = false
        options.pointOfInterestFilter = .excludingAll

        let snapshotter = MKMapSnapshotter(options: options)
        let snapshot: MKMapSnapshotter.Snapshot? = await withCheckedContinuation { continuation in
            snapshotter.start() { snapshot, _ in
                continuation.resume(returning: snapshot)
            }
        }

        guard let snapshot = snapshot else {
            return nil
        }

        let lineWidth: CGFloat = 2.0
        let smoothing: Double = 0.85
        var maxX: CGFloat = 0.0

        let renderer = UIGraphicsImageRenderer(size: outputSize)
        let image = renderer.image { ctx in
            snapshot.image.draw(in: CGRect(origin: .zero, size: outputSize))

            ctx.cgContext.setStrokeColor(UIColor.white.cgColor)
            ctx.cgContext.setLineWidth(lineWidth)
            ctx.cgContext.setLineJoin(.round)
            ctx.cgContext.setLineCap(.round)
            ctx.cgContext.beginPath()

            var prevX: Double = -1
            var prevY: Double = -1

            for (i, coord) in coordinates.enumerated() {
                let point = snapshot.point(for: coord)

                var x = point.x
                var y = point.y

                // Smoothing
                if prevX == -1 || prevY == -1 {
                    prevX = x
                    prevY = y
                } else {
                    x = (x * (1 - smoothing)) + (prevX * smoothing)
                    prevX = x
                    y = (y * (1 - smoothing)) + (prevY * smoothing)
                    prevY = y
                }

                if x > maxX {
                    maxX = x
                }

                if i == 0 {
                    ctx.cgContext.move(to: CGPoint(x: x, y: y))
                }

                ctx.cgContext.addLine(to: CGPoint(x: x, y: y))
            }
            ctx.cgContext.drawPath(using: .stroke)
        }

        let cropped = image.sd_croppedImage(with: CGRect(x: 0,
                                                         y: 0,
                                                         width: maxX + 25.0,
                                                         height: image.size.height))
        return cropped
    }
}
