// Licensed under the Any Distance Source-Available License
//
//  Extensions.swift
//  ADAC
//
//  Created by Daniel Kuntz on 12/14/20.
//

import UIKit
import CloudKit
import MapKit
#if !os(watchOS)
import SafariServices
#endif
import HealthKit

#if !os(watchOS)
extension UIView {
    func addParralaxMotionEffect(withDepth depth: CGFloat) {
        let effectX = UIInterpolatingMotionEffect(keyPath: "center.x",
                                                  type: .tiltAlongHorizontalAxis)
        effectX.minimumRelativeValue = -1 * depth
        effectX.maximumRelativeValue = depth
        addMotionEffect(effectX)

        let effectY = UIInterpolatingMotionEffect(keyPath: "center.y",
                                                  type: .tiltAlongVerticalAxis)
        effectY.minimumRelativeValue = -1 * depth
        effectY.maximumRelativeValue = depth
        addMotionEffect(effectY)
    }

    func add3DFloatingEffect(withDepth depth: Double = 1 / 12, duration: Double = 5) {
        let depthAngle = depth * .pi
        let rotationAnimationY = CABasicAnimation(keyPath: "transform.rotation.y")
        rotationAnimationY.fromValue = NSNumber(floatLiteral: -1 * depthAngle)
        rotationAnimationY.toValue = NSNumber(floatLiteral: depthAngle)
        rotationAnimationY.duration = duration
        rotationAnimationY.repeatCount = Float(Int.max)
        rotationAnimationY.autoreverses = true
        rotationAnimationY.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(rotationAnimationY, forKey: "rotationAnimationZ")

        let rotationAnimationX = CABasicAnimation(keyPath: "transform.rotation.x")
        rotationAnimationX.fromValue = NSNumber(floatLiteral: -1 * depthAngle)
        rotationAnimationX.toValue = NSNumber(floatLiteral: depthAngle)
        rotationAnimationX.duration = duration
        rotationAnimationX.repeatCount = Float(Int.max)
        rotationAnimationX.autoreverses = true
        rotationAnimationX.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        rotationAnimationX.timeOffset = duration / 2
        layer.add(rotationAnimationX, forKey: "rotationAnimationX")

        layer.transform.m34 = -1/500
        layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
    }

    func applySketchShadow(color: UIColor = .black,
                           alpha: Float = 0.2,
                           x: CGFloat = 0,
                           y: CGFloat = 2,
                           blur: CGFloat = 4,
                           spread: CGFloat = 0) {
        layer.shadowColor = color.cgColor
        layer.shadowOpacity = alpha
        layer.shadowOffset = CGSize(width: x, height: y)
        layer.shadowRadius = blur / 2
        if spread == 0 {
            layer.shadowPath = nil
        } else {
            let dx = -spread
            let rect = bounds.insetBy(dx: dx, dy: dx)
            layer.shadowPath = UIBezierPath(ovalIn: rect).cgPath
        }
    }

    func findContainingScrollView(for view: UIView? = nil) -> UIScrollView? {
        if let scrollView = (view ?? self).superview as? UIScrollView {
            return scrollView
        } else if let superview = (view ?? self).superview {
            return findContainingScrollView(for: superview)
        } else {
            return nil
        }
    }

    static func scaleView(_ v: UIView, scaleFactor: CGFloat) {
        if v is UILabel {
            v.layer.shadowRadius *= scaleFactor
        }

        if !(v is UIStackView) {
            v.contentScaleFactor = scaleFactor
        }

        for sv in v.subviews {
            scaleView(sv, scaleFactor: scaleFactor)
        }
    }
}

extension UITextField {
    func addDoneToolbar(onDone: (target: Any, action: Selector)? = nil) {
        let onDone = onDone ?? (target: self, action: #selector(doneButtonTapped))

        let toolbar: UIToolbar = UIToolbar()
        toolbar.barStyle = .default
        toolbar.items = [
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: self, action: nil),
            UIBarButtonItem(title: "Done", style: .done, target: onDone.target, action: onDone.action)
        ]
        toolbar.sizeToFit()
        toolbar.tintColor = .white

        self.inputAccessoryView = toolbar
    }

    // Default actions:
    @objc func doneButtonTapped() { self.resignFirstResponder() }
}

extension UIAlertController {
    func addActions(_ actions: [UIAlertAction]) {
        for action in actions {
            addAction(action)
        }
    }

    static func defaultWith(title: String, message: String) -> UIAlertController {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
        return alert
    }
}

extension UIDevice {
    static let modelName: String = {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }

        func mapToDevice(identifier: String) -> String {
#if os(iOS)
            switch identifier {
            case "iPod5,1":                                 return "iPod touch (5th generation)"
            case "iPod7,1":                                 return "iPod touch (6th generation)"
            case "iPod9,1":                                 return "iPod touch (7th generation)"
            case "iPhone3,1", "iPhone3,2", "iPhone3,3":     return "iPhone 4"
            case "iPhone4,1":                               return "iPhone 4s"
            case "iPhone5,1", "iPhone5,2":                  return "iPhone 5"
            case "iPhone5,3", "iPhone5,4":                  return "iPhone 5c"
            case "iPhone6,1", "iPhone6,2":                  return "iPhone 5s"
            case "iPhone7,2":                               return "iPhone 6"
            case "iPhone7,1":                               return "iPhone 6 Plus"
            case "iPhone8,1":                               return "iPhone 6s"
            case "iPhone8,2":                               return "iPhone 6s Plus"
            case "iPhone8,4":                               return "iPhone SE"
            case "iPhone9,1", "iPhone9,3":                  return "iPhone 7"
            case "iPhone9,2", "iPhone9,4":                  return "iPhone 7 Plus"
            case "iPhone10,1", "iPhone10,4":                return "iPhone 8"
            case "iPhone10,2", "iPhone10,5":                return "iPhone 8 Plus"
            case "iPhone10,3", "iPhone10,6":                return "iPhone X"
            case "iPhone11,2":                              return "iPhone XS"
            case "iPhone11,4", "iPhone11,6":                return "iPhone XS Max"
            case "iPhone11,8":                              return "iPhone XR"
            case "iPhone12,1":                              return "iPhone 11"
            case "iPhone12,3":                              return "iPhone 11 Pro"
            case "iPhone12,5":                              return "iPhone 11 Pro Max"
            case "iPhone12,8":                              return "iPhone SE (2nd generation)"
            case "iPhone13,1":                              return "iPhone 12 mini"
            case "iPhone13,2":                              return "iPhone 12"
            case "iPhone13,3":                              return "iPhone 12 Pro"
            case "iPhone13,4":                              return "iPhone 12 Pro Max"
            case "iPad2,1", "iPad2,2", "iPad2,3", "iPad2,4":return "iPad 2"
            case "iPad3,1", "iPad3,2", "iPad3,3":           return "iPad (3rd generation)"
            case "iPad3,4", "iPad3,5", "iPad3,6":           return "iPad (4th generation)"
            case "iPad6,11", "iPad6,12":                    return "iPad (5th generation)"
            case "iPad7,5", "iPad7,6":                      return "iPad (6th generation)"
            case "iPad7,11", "iPad7,12":                    return "iPad (7th generation)"
            case "iPad11,6", "iPad11,7":                    return "iPad (8th generation)"
            case "iPad4,1", "iPad4,2", "iPad4,3":           return "iPad Air"
            case "iPad5,3", "iPad5,4":                      return "iPad Air 2"
            case "iPad11,3", "iPad11,4":                    return "iPad Air (3rd generation)"
            case "iPad13,1", "iPad13,2":                    return "iPad Air (4th generation)"
            case "iPad2,5", "iPad2,6", "iPad2,7":           return "iPad mini"
            case "iPad4,4", "iPad4,5", "iPad4,6":           return "iPad mini 2"
            case "iPad4,7", "iPad4,8", "iPad4,9":           return "iPad mini 3"
            case "iPad5,1", "iPad5,2":                      return "iPad mini 4"
            case "iPad11,1", "iPad11,2":                    return "iPad mini (5th generation)"
            case "iPad6,3", "iPad6,4":                      return "iPad Pro (9.7-inch)"
            case "iPad7,3", "iPad7,4":                      return "iPad Pro (10.5-inch)"
            case "iPad8,1", "iPad8,2", "iPad8,3", "iPad8,4":return "iPad Pro (11-inch) (1st generation)"
            case "iPad8,9", "iPad8,10":                     return "iPad Pro (11-inch) (2nd generation)"
            case "iPad6,7", "iPad6,8":                      return "iPad Pro (12.9-inch) (1st generation)"
            case "iPad7,1", "iPad7,2":                      return "iPad Pro (12.9-inch) (2nd generation)"
            case "iPad8,5", "iPad8,6", "iPad8,7", "iPad8,8":return "iPad Pro (12.9-inch) (3rd generation)"
            case "iPad8,11", "iPad8,12":                    return "iPad Pro (12.9-inch) (4th generation)"
            case "AppleTV5,3":                              return "Apple TV"
            case "AppleTV6,2":                              return "Apple TV 4K"
            case "AudioAccessory1,1":                       return "HomePod"
            case "AudioAccessory5,1":                       return "HomePod mini"
            case "i386", "x86_64":                          return "Simulator \(mapToDevice(identifier: ProcessInfo().environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "iOS"))"
            default:                                        return identifier
            }
#elseif os(tvOS)
            switch identifier {
            case "AppleTV5,3": return "Apple TV 4"
            case "AppleTV6,2": return "Apple TV 4K"
            case "i386", "x86_64": return "Simulator \(mapToDevice(identifier: ProcessInfo().environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "tvOS"))"
            default: return identifier
            }
#endif
        }

        return mapToDevice(identifier: identifier)
    }()
}
#endif

extension UIColor {
    static let adYellow = UIColor(realRed: 255, green: 207, blue: 59)
    static let hipstaYellow = UIColor(hex: "FFD510")
    static let adOrangeLighter = UIColor(realRed: 255, green: 173, blue: 0)
    static let adOrange = UIColor(realRed: 198, green: 83, blue: 3)
    static let adRed = UIColor(realRed: 174, green: 32, blue: 1)
    static let adBrown = UIColor(realRed: 78, green: 45, blue: 0)
    static let adGreen = UIColor(hex: "30D158")

    static let adGray1 = UIColor(hex: "171717")
    static let adGray3 = UIColor(hex: "7B7B7B")
    static let adGray4 = UIColor(hex: "D8D8D8")

    @nonobjc convenience init(realRed: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat = 1) {
        self.init(red: realRed/255.0, green: green/255.0, blue: blue/255.0, alpha: alpha)
    }

    func lighter(by percentage: CGFloat = 30.0) -> UIColor? {
        return self.adjust(by: abs(percentage) )
    }

    func darker(by percentage: CGFloat = 30.0) -> UIColor? {
        return self.adjust(by: -1 * abs(percentage) )
    }

    func withBrightness(_ brightness: CGFloat, saturation: CGFloat) -> UIColor {
        var h: CGFloat = 0
        var s: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        if s == 0 {
            return UIColor(hue: h, saturation: s, brightness: brightness, alpha: a)
        }
        return UIColor(hue: h, saturation: saturation, brightness: brightness, alpha: a)
    }

    func adjust(by percentage: CGFloat = 30.0) -> UIColor? {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        if self.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            return UIColor(red: (red + percentage / 100).clamped(to: 0...1),
                           green:(green + percentage / 100).clamped(to: 0...1),
                           blue: (blue + percentage / 100).clamped(to: 0...1),
                           alpha: alpha)
        } else {
            return nil
        }
    }

    func toHexString() -> String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        let rgb: Int = (Int)(r*255)<<16 | (Int)(g*255)<<8 | (Int)(b*255)<<0
        return String(format:"#%06x", rgb)
    }

    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        let scanner = Scanner(string: hex)

        if hex.hasPrefix("#") {
            scanner.currentIndex = hex.index(after: hex.startIndex)
        }

        var hexNumber: UInt64 = 0
        guard scanner.scanHexInt64(&hexNumber) else {
            self.init(white: 0.0, alpha: 0.0)
            return
        }

        let r, g, b: CGFloat
        if hex.count == 6 || (hex.count == 7 && hex.hasPrefix("#")) {
            r = CGFloat((hexNumber & 0xFF0000) >> 16) / 255
            g = CGFloat((hexNumber & 0x00FF00) >> 8) / 255
            b = CGFloat(hexNumber & 0x0000FF) / 255
            self.init(red: r, green: g, blue: b, alpha: 1.0)
        } else {
            self.init(white: 0.0, alpha: 0.0)
        }
    }
}

extension UIFont {
    static func presicav(size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        return {
            switch weight {
            case .bold:
                return UIFont(name: "PresicavRg-Bold", size: size)
            case .heavy:
                return UIFont(name: "PresicavHv-Regular", size: size)
            default:
                return UIFont(name: "PresicavRg-Regular", size: size)
            }
        }() ?? UIFont.systemFont(ofSize: size, weight: weight, width: .expanded)
    }
}

extension UIImage {
#if !os(watchOS)
    func resized(withNewWidth newWidth: CGFloat, imageScale: CGFloat = UIScreen.main.scale) -> UIImage {
        let scale = newWidth / size.width
        let newHeight = size.height * scale
        UIGraphicsBeginImageContextWithOptions(CGSize(width: newWidth, height: newHeight), false, imageScale)
        draw(in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage ?? self
    }

    func grayscaled() -> UIImage {
        let ciImage = CIImage(image: self)
        if let grayscale = ciImage?.applyingFilter("CIColorControls",
                                                   parameters: [kCIInputSaturationKey: 0.0]) {
            return UIImage(ciImage: grayscale)
        }

        return self
    }
#else
    func resized(withNewWidth newWidth: CGFloat) -> UIImage {
        let scale = newWidth / size.width
        let newHeight = size.height * scale
        UIGraphicsBeginImageContextWithOptions(CGSize(width: newWidth, height: newHeight), false, 2.0)
        draw(in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage ?? self
    }
#endif

    func withCorrectedOrientation() -> UIImage {
        if (self.imageOrientation == .up) {
            return self
        }

        UIGraphicsBeginImageContextWithOptions(self.size, false, self.scale)
        let rect = CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height)
        self.draw(in: rect)

        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return normalizedImage ?? self
    }

    func trimmingTransparentPixels() -> UIImage {
        guard let cgImage = self.cgImage else {
            return self
        }

        let width = cgImage.width
        let height = cgImage.height

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel: Int = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        let bitmapInfo: UInt32 = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue

        guard let context = CGContext(data: nil,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: bitsPerComponent,
                                      bytesPerRow: bytesPerRow,
                                      space: colorSpace,
                                      bitmapInfo: bitmapInfo),
              let ptr = context.data?.assumingMemoryBound(to: UInt8.self) else {
            return self
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var minX = width
        var minY = height
        var maxX: Int = 0
        var maxY: Int = 0

        for x in 1 ..< width {
            for y in 1 ..< height {
                let i = bytesPerRow * Int(y) + bytesPerPixel * Int(x)
                let a = CGFloat(ptr[i + 3]) / 255.0

                if(a > 0) {
                    if (x < minX) { minX = x }
                    if (x > maxX) { maxX = x }
                    if (y < minY) { minY = y }
                    if (y > maxY) { maxY = y }
                }
            }
        }

        let rect = CGRect(x: CGFloat(minX),
                          y: CGFloat(minY),
                          width: CGFloat(maxX - minX + 1),
                          height: CGFloat(maxY - minY + 1))
        let imageScale: CGFloat = self.scale
        guard let croppedImage = cgImage.cropping(to: rect) else {
            return self
        }

        return UIImage(cgImage: croppedImage, scale: imageScale, orientation: self.imageOrientation)
    }

    func isEqualToImage(image: UIImage) -> Bool {
        let data1 = self.pngData()! as NSData
        let data2 = image.pngData()! as NSData
        return data1.isEqual(data2)
    }
}

extension MKCoordinateRegion {
    func mapRect() -> MKMapRect {
        let topLeft = CLLocationCoordinate2D(latitude: self.center.latitude + (self.span.latitudeDelta/2),
                                             longitude: self.center.longitude - (self.span.longitudeDelta/2))
        let bottomRight = CLLocationCoordinate2D(latitude: self.center.latitude - (self.span.latitudeDelta/2),
                                                 longitude: self.center.longitude + (self.span.longitudeDelta/2))

        let a = MKMapPoint(topLeft)
        let b = MKMapPoint(bottomRight)

        return MKMapRect(origin: MKMapPoint(x:min(a.x,b.x), y:min(a.y,b.y)),
                         size: MKMapSize(width: abs(a.x-b.x), height: abs(a.y-b.y)))
    }
}

extension Notification {
    static let connectionStateChanged = Notification(name: Notification.Name("connectionStateChanged"))
    static let externalServicesConnectionStateChanged = Notification(name: Notification.Name("externalServicesConnectionStateChanged"))
    static let goalTypeChanged = Notification(name: Notification.Name("goalTypeChanged"))
    static let subscriptionStatusChanged = Notification(name: Notification.Name("subscriptionStatusChanged"))
    static let recordingShareActivity = Notification(name: Notification.Name("recordingShareActivity"))
}

extension Date {
    func formatted(withStyle style: DateFormatter.Style) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = style
        return formatter.string(from: self)
    }

    func formatted(withFormat format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: self)
    }

    func convertFromTimeZone(_ initTimeZone: TimeZone, toTimeZone timeZone: TimeZone) -> Date {
        let delta = TimeInterval(timeZone.secondsFromGMT(for: self) - initTimeZone.secondsFromGMT(for: self))
        return addingTimeInterval(delta)
    }
}

extension Calendar {
    func startOfWeek(for date: Date) -> Date {
        guard let sunday = self.date(from: self.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)) else { return date }
        var startOfWeek = self.date(byAdding: .day, value: 1, to: sunday) ?? date
        if startOfWeek >= date {
            startOfWeek = self.date(byAdding: .day, value: -7, to: startOfWeek) ?? date
        }
        return startOfWeek
    }
}

extension Float {
    func rounded(toPlaces places: Int) -> Float {
        let divisor = powf(10.0, Float(places))
        return (self * divisor).rounded() / divisor
    }
}

extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }

    func float() -> Float {
        return Float(self)
    }
}

extension Collection {
    /// Returns the element at the specified index if it is within bounds, otherwise nil.
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }

    func sorted<T: Comparable>(by keyPath: KeyPath<Element, T>) -> [Element] {
        sorted { a, b in
            a[keyPath: keyPath] < b[keyPath: keyPath]
        }
    }
}

extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        return min(max(self, limits.lowerBound), limits.upperBound)
    }
}

extension TimeInterval {
    func timeFormatted(includeSeconds: Bool = true,
                       includeMilliseconds: Bool = false,
                       includeAbbreviations: Bool = false) -> String {
        guard !self.isInfinite && !self.isNaN else {
            return "0:00"
        }
        
        let intSelf = Int(self)

        let hours = intSelf / 3600
        let mins = (intSelf / 60) % 60
        let secs = intSelf % 60
        let milliseconds = Int(self.truncatingRemainder(dividingBy: 1) * 100)

        var str = ""
        if hours > 0 {
            str += "\(hours)" + ":"
            str += (mins < 10 ? "0\(mins)" : "\(mins)")
            if includeSeconds {
                str += ":" + (secs < 10 ? "0\(secs)" : "\(secs)")
            }
            if includeAbbreviations {
                str += "hrs"
            } else if includeMilliseconds {
                str += "." + (milliseconds < 10 ? "0\(milliseconds)" : "\(milliseconds)")
            }
        } else {
            str += "\(mins)"
            if includeSeconds {
                str += ":" + (secs < 10 ? "0\(secs)" : "\(secs)")
            }
            if includeAbbreviations {
                str += "min"
            } else if includeMilliseconds {
                str += "." + (milliseconds < 10 ? "0\(milliseconds)" : "\(milliseconds)")
            }
        }

        return str
    }
}

extension CGSize {
    static func aspectFit(aspectRatio: CGSize, boundingSize: CGSize) -> CGRect {
        let mW = boundingSize.width / aspectRatio.width
        let mH = boundingSize.height / aspectRatio.height

        var newSize = boundingSize
        if (mH < mW) {
            newSize.width = boundingSize.height / aspectRatio.height * aspectRatio.width
        } else if (mW < mH) {
            newSize.height = boundingSize.width / aspectRatio.width * aspectRatio.height
        }

        let rect = CGRect(x: boundingSize.width / 2 - newSize.width / 2,
                          y: boundingSize.height / 2 - newSize.height / 2,
                          width: newSize.width,
                          height: newSize.height)

        return rect
    }

    static func aspectFit(aspectRatio: CGSize, inRect: CGRect) -> CGRect {
        var rect = aspectFit(aspectRatio: aspectRatio, boundingSize: inRect.size)
        rect.origin.x += inRect.origin.x
        rect.origin.y += inRect.origin.y
        return rect
    }

    static func aspectFill(aspectRatio: CGSize, minimumSize: CGSize) -> CGRect {
        let mW = minimumSize.width / aspectRatio.width
        let mH = minimumSize.height / aspectRatio.height

        var newSize = minimumSize
        if (mH > mW) {
            newSize.width = minimumSize.height / aspectRatio.height * aspectRatio.width
        } else if (mW > mH) {
            newSize.height = minimumSize.width / aspectRatio.width * aspectRatio.height
        }

        let rect = CGRect(x: minimumSize.width / 2 - newSize.width / 2,
                          y: minimumSize.height / 2 - newSize.height / 2,
                          width: newSize.width,
                          height: newSize.height)

        return rect
    }

    static func aspectFill(aspectRatio: CGSize, inRect: CGRect) -> CGRect {
        var rect = aspectFill(aspectRatio: aspectRatio, minimumSize: inRect.size)
        rect.origin.x += inRect.origin.x
        rect.origin.y += inRect.origin.y
        return rect
    }
}

extension CGPoint {
    func distance(to point: CGPoint) -> CGFloat {
        return sqrt(pow(x - point.x, 2) + pow(y - point.y, 2))
    }
}

extension Bundle {
    var releaseVersionNumber: Float {
        if let string = infoDictionary?["CFBundleShortVersionString"] as? String {
            return Float(string) ?? 0
        }

        return 0
    }

    var buildVersionNumber: Float {
        if let string = infoDictionary?["CFBundleVersion"] as? String {
            return Float(string) ?? 0
        }

        return 0
    }
}

extension FileManager {
    func clearTmpDirectory() {
        do {
            let tmpDirURL = FileManager.default.temporaryDirectory
            let tmpDirectory = try contentsOfDirectory(atPath: tmpDirURL.path)
            try tmpDirectory.forEach { file in
                let fileUrl = tmpDirURL.appendingPathComponent(file)
                try removeItem(atPath: fileUrl.path)
            }
        } catch {
            print("Error in clearTmpDirectory: \(error.localizedDescription)")
        }
    }

    func removeItemIfExists(at url: URL) throws {
        if fileExists(atPath: url.path) {
            try removeItem(at: url)
        }
    }

    func removeItemIfExists(atUrl url: URL) {
        do {
            if fileExists(atPath: url.path) {
                try removeItem(at: url)
                print("Deleted existing file.")
            }
        } catch {
            print("Error in removeItemIfExists: \(error.localizedDescription)")
        }
    }
}

extension String {
    func camelCaseToWords() -> String {
        return unicodeScalars.dropFirst().reduce(String(prefix(1))) {
            return CharacterSet.uppercaseLetters.contains($1)
            ? $0 + " " + String($1)
            : $0 + String($1)
        }
    }

    func camelCaseToSnakeCase() -> String {
        return unicodeScalars.dropFirst().reduce(String(prefix(1))) {
            return CharacterSet.uppercaseLetters.contains($1)
            ? $0 + "_" + String($1)
            : $0 + String($1)
        }.lowercased()
    }

    func height(withConstrainedWidth width: CGFloat, font: UIFont) -> CGFloat {
        let constraintRect = CGSize(width: width, height: .greatestFiniteMagnitude)
        let boundingBox = self.boundingRect(with: constraintRect,
                                            options: .usesLineFragmentOrigin,
                                            attributes: [.font: font], context: nil)

        return ceil(boundingBox.height)
    }

    func width(withConstrainedHeight height: CGFloat, font: UIFont) -> CGFloat {
        let constraintRect = CGSize(width: .greatestFiniteMagnitude, height: height)
        let boundingBox = self.boundingRect(with: constraintRect,
                                            options: .usesLineFragmentOrigin,
                                            attributes: [.font: font], context: nil)

        return ceil(boundingBox.width)
    }

    func zeroPadded(to numberOfChars: Int, front: Bool) -> String {
        if count >= numberOfChars {
            return self
        }

        let zeroes = Array(repeating: "0", count: numberOfChars - count).joined()
        return front ? zeroes + self : self + zeroes
    }
}

extension Array where Element: FloatingPoint {
    func sum() -> Element {
        return self.reduce(0, +)
    }

    func avg() -> Element {
        return self.sum() / Element(self.count.clamped(to: 1...Int.max))
    }

    func stdDeviation() -> Element {
        let mean = self.avg()
        let v = self.reduce(0, { $0 + ($1-mean)*($1-mean) })
        return sqrt(v / (Element(self.count) - 1))
    }
}
extension Array where Element == Int {
    func avg() -> Element {
        return Element(Float(self.reduce(0, +)) / Float(self.count))
    }
}

extension Sequence where Element: Hashable {
    func uniqued() -> [Element] {
        var set = Set<Element>()
        return filter { set.insert($0).inserted }
    }
}
