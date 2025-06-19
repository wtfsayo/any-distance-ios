// Licensed under the Any Distance Source-Available License
//
//  RouteRenderer.swift
//  ADAC
//
//  Created by Daniel Kuntz on 12/18/20.
//

import UIKit
import CoreLocation
import CoreImage

struct RouteImageRenderer {
    static func renderMiniRoute(coordinates coords: [CLLocation], completion: @escaping (UIImage?) -> Void) {
        renderRoute(coordinates: coords,
                    imageSize: CGSize(width: 500, height: 500),
                    lineWidth: 14,
                    completion: completion)
    }

    static func renderRoute(withPalette palette: Palette = .dark, coordinates coords: [CLLocation], completion: @escaping (UIImage?) -> Void) {
        renderRoute(withPalette: palette,
                    coordinates: coords,
                    imageSize: CGSize(width: 1500, height: 1500),
                    lineWidth: 12.75,
                    completion: completion)
    }

    static func renderRouteShadowImage(coordinates coords: [CLLocation], completion: @escaping (UIImage?) -> Void) {
        let s = max(1, coords.count / 350)
        let reducedCoords = stride(from: 0, to: coords.count - 1, by: s).map { coords[$0] }
        renderRoute(withPalette: .light,
                    coordinates: reducedCoords,
                    imageSize: CGSize(width: 600, height: 600),
                    lineWidth: 20) { image in
            guard let image = image else {
                completion(nil)
                return
            }

            let blurFilter = CIFilter(name: "CIGaussianBlur")
            blurFilter?.setValue(CIImage(image: image), forKey: kCIInputImageKey)
            blurFilter?.setValue(90, forKey: kCIInputRadiusKey)
            if let output = blurFilter?.outputImage,
               let cgImage = CIContext(options: nil).createCGImage(output, from: output.extent) {
                let uiImage = UIImage(cgImage: cgImage)
                padToSquare(uiImage, completion: completion)
                return
            }

            completion(nil)
        }
    }

    private static func renderRoute(withPalette palette: Palette = .dark, coordinates coords: [CLLocation], imageSize: CGSize, lineWidth: CGFloat, completion: @escaping ((UIImage?) -> Void)) {
        DispatchQueue.global(qos: .userInitiated).async {
            let points: [CLLocationCoordinate2D] = coords.map { $0.coordinate }

            let latitudeMin: CLLocationDegrees = points.min(by: { $0.latitude < $1.latitude })?.latitude ?? 1
            let latitudeMax: CLLocationDegrees = points.max(by: { $0.latitude < $1.latitude })?.latitude ?? 1
            let longitudeMin: CLLocationDegrees = points.min(by: { $0.longitude < $1.longitude })?.longitude ?? 1
            let longitudeMax: CLLocationDegrees = points.max(by: { $0.longitude < $1.longitude })?.longitude ?? 1

            let latitudeRange = latitudeMax - latitudeMin
            let longitudeRange = longitudeMax - longitudeMin
            let aspectRatio = CGSize(width: CGFloat(longitudeRange),
                                     height: CGFloat(latitudeRange))
            let bounds = CGSize.aspectFit(aspectRatio: aspectRatio, boundingSize: imageSize)

            let smoothing: Double = 0.55
            let renderer = UIGraphicsImageRenderer(size: bounds.size)

            let image = renderer.image { ctx in
                ctx.cgContext.setStrokeColor(palette.foregroundColor.cgColor)
                ctx.cgContext.setLineWidth(lineWidth)
                ctx.cgContext.setLineJoin(.round)
                ctx.cgContext.setLineCap(.round)
                ctx.cgContext.beginPath()

                var prevX: Double = -1
                var prevY: Double = -1

                for (i, point) in points.enumerated() {
                    var y = Double(bounds.height) - (Double(bounds.height) * ((point.latitude - latitudeMin) / latitudeRange)) //+ Double(bounds.origin.x)
                    var x = Double(bounds.width) * ((point.longitude - longitudeMin) / longitudeRange) //+ Double(bounds.origin.y)

                    // Add a little padding so the line doesn't overlap the image bounds
                    y *= Double((bounds.height - lineWidth) / bounds.height)
                    y += Double(lineWidth/2)
                    x *= Double((bounds.width - lineWidth) / bounds.width)
                    x += Double(lineWidth/2)

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

                    if i == 0 {
                        ctx.cgContext.move(to: CGPoint(x: x, y: y))
                    }

                    ctx.cgContext.addLine(to: CGPoint(x: x, y: y))
                }

                ctx.cgContext.drawPath(using: .stroke)
            }

            DispatchQueue.main.async {
                completion(image)
            }
        }
    }

    private static func padToSquare(_ image: UIImage, completion: @escaping (UIImage) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let imageSideLength = max(image.size.width, image.size.height)
            let finalImageSize = CGSize(width: imageSideLength, height: imageSideLength)
            let imageFrame = CGSize.aspectFit(aspectRatio: image.size, boundingSize: finalImageSize)
            let renderer = UIGraphicsImageRenderer(size: finalImageSize)
            let image = renderer.image { ctx in
                image.draw(in: imageFrame)
            }

            DispatchQueue.main.async {
                completion(image)
            }
        }
    }
}
