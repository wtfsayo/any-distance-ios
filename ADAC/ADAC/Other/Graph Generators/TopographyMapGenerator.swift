// Licensed under the Any Distance Source-Available License
//
//  TopographyMapGenerator.swift
//  ADAC
//
//  Created by Daniel Kuntz on 11/19/21.
//

//import UIKit
//
//class TopographyMapGenerator {
//    static func generateMapImage2(fromPoints points: [ElevationPoint]) {
//        let latitudeMin = CGFloat(points.map { $0.location.0 }.min() ?? 0)
//        let latitudeMax = CGFloat(points.map { $0.location.0 }.max() ?? 0)
//        let longitudeMin = CGFloat(points.map { $0.location.1 }.min() ?? 0)
//        let longitudeMax = CGFloat(points.map { $0.location.1 }.max() ?? 0)
//        let latitudeRange = latitudeMax - latitudeMin
//        let longitudeRange = longitudeMax - longitudeMin
//
//        var latMap: [Float: [ElevationPoint]] = [:]
//        for point in points {
//            if latMap[point.location.0] == nil {
//                latMap[point.location.0] = [point]
//            } else {
//                latMap[point.location.0]?.append(point)
//            }
//        }
//        let columns = latMap.values.sorted(by: { $0[0].location.0 < $1[0].location.0 })
//
//        let res: Float = 5
//        let minElevation = points.map { $0.elevation }.min() ?? 0
//        let maxElevation = points.map { $0.elevation }.max() ?? 0
//        let tiers = stride(from: minElevation, to: maxElevation, by: res).map { $0 }
//
//        var tierPoints: [Float: [CGPoint]] = [:]
//        for tier in tiers {
//            tierPoints[tier] = []
//
//            for (col, colPoints) in columns.enumerated() {
//                for (row, point) in colPoints.enumerated() {
//                    if (row != 0) && (row != colPoints.count - 1) && (col != 0) && (col != columns.count - 1) {
//                        let surroundingPoints = [columns[col-1][row-1],
//                                                 columns[col-1][row],
//                                                 columns[col-1][row+1],
//                                                 columns[col][row+1],
//                                                 columns[col+1][row+1],
//                                                 columns[col+1][row],
//                                                 columns[col+1][row-1],
//                                                 columns[col][row-1]]
//
//                        for i in 0..<(surroundingPoints.count - 1) {
//                            let sp1 = surroundingPoints[i]
//                            let sp2 = surroundingPoints[i+1]
//
//                            let isBelow = sp1.elevation < tier && sp2.elevation < tier && point.elevation > tier
//                            let isAbove = sp1.elevation > tier && sp2.elevation > tier && point.elevation < tier
//                            if isBelow || isAbove {
//                                let p1 = (tier - sp1.elevation) / (point.elevation - sp1.elevation)
//                                let lat1 = sp1.location.0 + ((point.location.0 - sp1.location.0) * p1)
//                                let long1 = sp1.location.1 + ((point.location.1 - sp1.location.1) * p1)
//
//                                let p2 = (tier - sp2.elevation) / (point.elevation - sp2.elevation)
//                                let lat2 = sp2.location.0 + ((point.location.0 - sp2.location.0) * p2)
//                                let long2 = sp2.location.1 + ((point.location.1 - sp2.location.1) * p2)
//
//                                let cgPoint = CGPoint(x: CGFloat((lat1 + lat2) / 2),
//                                                      y: CGFloat((long1 + long2) / 2))
//
//                                if !tierPoints[tier]!.contains(cgPoint) {
//                                    tierPoints[tier]?.append(cgPoint)
//                                }
//                            }
//                        }
//                    }
//                }
//            }
//        }
//
//        let renderSize = CGSize(width: 1000, height: 1000)
//        let dotSize: CGFloat = 2
//        let renderer = UIGraphicsImageRenderer(size: renderSize)
//
//        let image = renderer.image { ctx in
//            ctx.cgContext.setFillColor(UIColor.black.cgColor)
//            ctx.cgContext.fill(CGRect(origin: .zero, size: renderSize))
//
//            for key in tierPoints.keys {
//                let tier = tierPoints[key]!
//
//                let hue = (key - minElevation) / (maxElevation - minElevation)
//                let color = UIColor(hue: CGFloat(hue), saturation: 1, brightness: 1, alpha: 1).cgColor
//                ctx.cgContext.setFillColor(color)
//
////                let p = CGFloat((key - elevationMin) / elevationRange)
////                let color = UIColor.blend(color1: .white, intensity1: 1 - p, color2: adOrange, intensity2: p)
////                ctx.cgContext.setFillColor(color.withAlphaComponent(p).cgColor)
//
//                for point in tier {
//                    let xP = (CGFloat(point.x) - latitudeMin) / latitudeRange
//                    let yP = (CGFloat(point.y) - longitudeMin) / longitudeRange
//                    let rect = CGRect(x: renderSize.width * xP - (dotSize / 2),
//                                      y: renderSize.height * yP - (dotSize / 2),
//                                      width: dotSize,
//                                      height: dotSize)
//                    ctx.cgContext.fillEllipse(in: rect)
//                }
//            }
//
////            for point in points {
////
////            }
//        }
//
//        print(image)
//    }
//
//    static func generateMapImage(fromPoints points: [ElevationPoint]) {
//        var latMap: [Float: [ElevationPoint]] = [:]
//        for point in points {
//            if latMap[point.location.0] == nil {
//                latMap[point.location.0] = [point]
//            } else {
//                latMap[point.location.0]?.append(point)
//            }
//        }
//        let columns = latMap.values.sorted(by: { $0[0].location.0 < $1[0].location.0 })
//
//        let res: Float = 5
//        let minElevation = points.map { $0.elevation }.min() ?? 0
//        let maxElevation = points.map { $0.elevation }.max() ?? 0
//        let tiers = stride(from: minElevation, to: maxElevation, by: res).map { $0 }
//
//        var tierPoints: [Float: [CGPoint]] = [:]
//        for tier in tiers {
//            tierPoints[tier] = []
//
//            for (col, colPoints) in columns.enumerated() {
//                for (row, point) in colPoints.enumerated() {
//                    if (row != 0) && (row != colPoints.count - 1) && (col != 0) && (col != columns.count - 1) {
//                        let surroundingPoints = [columns[col-1][row-1],
//                                                 columns[col-1][row],
//                                                 columns[col-1][row+1],
//                                                 columns[col][row+1],
//                                                 columns[col+1][row+1],
//                                                 columns[col+1][row],
//                                                 columns[col+1][row-1],
//                                                 columns[col][row-1]]
//
//                        for i in 0..<(surroundingPoints.count - 1) {
//                            let sp1 = surroundingPoints[i]
//                            let sp2 = surroundingPoints[i+1]
//
//                            let isBelow = sp1.elevation < tier && sp2.elevation < tier && point.elevation > tier
//                            let isAbove = sp1.elevation > tier && sp2.elevation > tier && point.elevation < tier
//                            if isBelow || isAbove {
//                                let p1 = (tier - sp1.elevation) / (point.elevation - sp1.elevation)
//                                let lat1 = sp1.location.0 + ((point.location.0 - sp1.location.0) * p1)
//                                let long1 = sp1.location.1 + ((point.location.1 - sp1.location.1) * p1)
//
//                                let p2 = (tier - sp2.elevation) / (point.elevation - sp2.elevation)
//                                let lat2 = sp2.location.0 + ((point.location.0 - sp2.location.0) * p2)
//                                let long2 = sp2.location.1 + ((point.location.1 - sp2.location.1) * p2)
//
//                                let cgPoint = CGPoint(x: CGFloat((lat1 + lat2) / 2),
//                                                      y: CGFloat((long1 + long2) / 2))
//
//                                if !tierPoints[tier]!.contains(cgPoint) {
//                                    tierPoints[tier]?.append(cgPoint)
//                                }
//                            }
//                        }
//                    }
//                }
//            }
//        }
//
//        let latitudeMin = CGFloat(points.map { $0.location.0 }.min() ?? 0)
//        let latitudeMax = CGFloat(points.map { $0.location.0 }.max() ?? 0)
//        let longitudeMin = CGFloat(points.map { $0.location.1 }.min() ?? 0)
//        let longitudeMax = CGFloat(points.map { $0.location.1 }.max() ?? 0)
//        let latitudeRange = latitudeMax - latitudeMin
//        let longitudeRange = longitudeMax - longitudeMin
//
//        let renderSize = CGSize(width: 1000, height: 1000)
//        let dotSize: CGFloat = 2
//        let renderer = UIGraphicsImageRenderer(size: renderSize)
//
//        let image = renderer.image { ctx in
//            ctx.cgContext.setFillColor(UIColor.black.cgColor)
//            ctx.cgContext.fill(CGRect(origin: .zero, size: renderSize))
//            ctx.cgContext.setLineJoin(.round)
//            ctx.cgContext.setLineCap(.round)
//
//            var lines: [Line] = []
//
//            for (i, key) in tierPoints.keys.enumerated() {
////                if i != 4 {
////                    continue
////                }
//
//                let hue = (key - minElevation) / (maxElevation - minElevation)
//                let color = UIColor(hue: CGFloat(hue), saturation: 1, brightness: 1, alpha: 1).cgColor
//                ctx.cgContext.setStrokeColor(color)
//                ctx.cgContext.setFillColor(color)
//                ctx.cgContext.setLineWidth(1)
//
//                var points = tierPoints[key]!.map { p in
//                    return CGPoint(x: renderSize.width * ((p.x - latitudeMin) / latitudeRange),
//                                   y: renderSize.height * ((p.y - longitudeMin) / longitudeRange))
//                }
//
//                for point in points {
//                    ctx.cgContext.fillEllipse(in: CGRect(x: point.x - dotSize / 2,
//                                                         y: point.y - dotSize / 2,
//                                                         width: dotSize,
//                                                         height: dotSize))
//                }
//
////                var prevCount = points.count + 1
////
////                while points.count != prevCount {
////                    if points.isEmpty {
////                        break
////                    }
////
////                    let firstPoint = points.first!
////                    ctx.cgContext.beginPath()
////                    ctx.cgContext.move(to: firstPoint)
////                    ctx.cgContext.addLine(to: firstPoint)
////
////                    var curPoints = points
////                    curPoints.removeAll(where: { $0 == firstPoint })
////                    guard let closest1 = closestPoint(to: firstPoint, in: curPoints, notIntersecting: lines) else {
////                        ctx.cgContext.closePath()
////                        prevCount = points.count
////                        points = curPoints
////                        continue
////                    }
////
////                    ctx.cgContext.addLine(to: closest1)
////                    lines.append(Line(point1: firstPoint, point2: closest1))
////                    curPoints.removeAll(where: { $0 == closest1 })
////
////                    guard let closest2 = closestPoint(to: closest1, in: curPoints, notIntersecting: lines) else {
////                        ctx.cgContext.closePath()
////                        prevCount = points.count
////                        points = curPoints
////                        continue
////                    }
////
////                    ctx.cgContext.addLine(to: closest2)
////                    lines.append(Line(point1: closest1, point2: closest2))
////                    curPoints.removeAll(where: { $0 == closest2 })
////                    curPoints.append(firstPoint)
////
////                    var flag: Bool = false
////                    var prevPoint: CGPoint = closest2
////                    while !flag {
////                        let nextClosest = closestPoint(to: prevPoint, in: curPoints, notIntersecting: lines)
////                        if nextClosest == nil {
////                            ctx.cgContext.strokePath()
////                            curPoints.removeAll(where: { $0 == firstPoint })
////                            flag = true
////                        } else if nextClosest == firstPoint {
////                            lines.append(Line(point1: prevPoint, point2: firstPoint))
////                            ctx.cgContext.closePath()
////                            ctx.cgContext.strokePath()
////                            curPoints.removeAll(where: { $0 == firstPoint })
////                            flag = true
////                        } else if let nextClosest = nextClosest {
////                            lines.append(Line(point1: prevPoint, point2: nextClosest))
////                            ctx.cgContext.addLine(to: nextClosest)
////                            curPoints.removeAll(where: { $0 == nextClosest })
////                            prevPoint = nextClosest
////                        }
////                    }
////
////                    prevCount = points.count
////                    points = curPoints
////                }
//
////                ctx.cgContext.drawPath(using: .stroke)
////                ctx.cgContext.closePath()
//            }
//        }
//
//        print(image)
//    }
//
//    fileprivate static func closestPoint(to targetPoint: CGPoint,
//                             in arr: [CGPoint],
//                             notIntersecting lines: [Line]) -> CGPoint? {
//        var distanceMin: CGFloat = 1000
//        var closestPoint: CGPoint?
//        for point in arr {
//            let d = point.distance(to: targetPoint)
//            let newLine = Line(point1: targetPoint, point2: point)
//            let intersects = self.line(newLine, intersectsAnyLines: lines)
//            if d < distanceMin && point != targetPoint && !intersects {
//                distanceMin = d
//                closestPoint = point
//            }
//        }
//        return closestPoint
//    }
//
//    fileprivate static func line(_ line: Line, intersectsAnyLines existingLines: [Line]) -> Bool {
//        for existingLine in existingLines {
//            if line.intersects(existingLine) {
//                return true
//            }
//        }
//
//        return false
//    }
//}
//
//fileprivate struct Line {
//    var point1: CGPoint
//    var point2: CGPoint
//
//    var boundingBox: CGRect {
//        return CGRect(x: min(point1.x, point2.x),
//                      y: min(point1.y, point2.y),
//                      width: max(point1.x, point2.x) - min(point1.x, point2.x),
//                      height: max(point1.y, point2.y) - min(point1.y, point2.y))
//    }
//
//    func intersects(_ line2: Line) -> Bool {
//        let boundingBoxIntersection = self.boundingBox.intersection(line2.boundingBox)
//        if boundingBoxIntersection.isNull {
//            return false
//        }
//
//        let a1 = self.point2.y - self.point1.y
//        let b1 = self.point1.x - self.point2.x
//        let c1 = a1*(self.point1.x) + b1*(self.point1.y)
//
//        // Line CD represented as a2x + b2y = c2
//        let a2 = line2.point2.y - line2.point1.y
//        let b2 = line2.point1.x - line2.point2.x
//        let c2 = a2*(line2.point1.x) + b2*(line2.point1.y)
//
//        let determinant = a1*b2 - a2*b1;
//
//        if (determinant == 0) {
//            // The lines are parallel. This is simplified
//            // by returning a pair of FLT_MAX
//            return false
//        } else {
//            let x = (b2*c1 - b1*c2)/determinant
//            let y = (a1*c2 - a2*c1)/determinant
//            return boundingBoxIntersection.contains(CGPoint(x: x, y: y))
//        }
//    }
//}
//
//extension UIColor {
//    static func blend(color1: UIColor, intensity1: CGFloat = 0.5, color2: UIColor, intensity2: CGFloat = 0.5) -> UIColor {
//        let total = intensity1 + intensity2
//        let l1 = intensity1/total
//        let l2 = intensity2/total
//        guard l1 > 0 else { return color2}
//        guard l2 > 0 else { return color1}
//        var (r1, g1, b1, a1): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
//        var (r2, g2, b2, a2): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
//
//        color1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
//        color2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
//
//        return UIColor(red: l1*r1 + l2*r2, green: l1*g1 + l2*g2, blue: l1*b1 + l2*b2, alpha: l1*a1 + l2*a2)
//    }
//}
