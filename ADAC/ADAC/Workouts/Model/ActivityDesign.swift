// Licensed under the Any Distance Source-Available License
//
//  ActivityDesign.swift
//  ADAC
//
//  Created by Daniel Kuntz on 1/18/21.
//

import UIKit
import SDWebImage

final class ActivityDesign: Codable {
    var activityId: Int = 0

    private var _cutoutShape: String? {
        didSet { cache() }
    }

    var font: ADFont? {
        didSet { cache() }
    }

    var alignment: StatisticAlignment? {
        didSet { cache() }
    }

    var routeEnabled: Bool? {
        didSet { cache() }
    }

    var graphType: GraphType? {
        didSet { cache() }
    }

    var distanceEnabled: Bool? {
        didSet { cache() }
    }

    var timeEnabled: Bool? {
        didSet { cache() }
    }

    var paceEnabled: Bool? {
        didSet { cache() }
    }

    var activeCalEnabled: Bool? {
        didSet { cache() }
    }

    var stepCountEnabled: Bool? {
        didSet { cache() }
    }

    var elevationEnabled: Bool? {
        didSet { cache() }
    }

    var locationEnabled: Bool? {
        didSet { cache() }
    }

    var goalEnabled: Bool? {
        didSet { cache() }
    }

    var activityTypeEnabled: Bool? {
        didSet { cache() }
    }

    var photoZoom: Float? {
        didSet { cache() }
    }

    var photoOffsetX: Float? {
        didSet { cache() }
    }

    var photoOffsetY: Float? {
        didSet { cache() }
    }

    var videoUrl: URL? {
        didSet {
            if let oldValue = oldValue {
                FileManager.default.removeItemIfExists(atUrl: oldValue)
            }

            cache()
        }
    }

    var videoMode: VideoMode? {
        didSet { cache() }
    }

    var photoFilter: PhotoFilter? {
        didSet { cache() }
    }

    var routeTransform: CGAffineTransform? {
        didSet { cache() }
    }

    var isStepCountDesign: Bool? {
        didSet { cache() }
    }

    var palette: Palette? {
        didSet { cache() }
    }

    private var _photo: UIImage?
    private var _filteredPhoto: UIImage?

    private enum CodingKeys: String, CodingKey {
        case activityId, _cutoutShape, font, routeEnabled, distanceEnabled, timeEnabled, paceEnabled,
             stepCountEnabled, elevationEnabled, locationEnabled, goalEnabled, activityTypeEnabled,
             photoZoom, photoOffsetX, photoOffsetY, videoUrl, videoMode, photoFilter, routeTransform,
             alignment, isStepCountDesign, graphType, palette, activeCalEnabled
    }

    var cutoutShape: CutoutShape? {
        get {
            guard let shape = _cutoutShape else {
                return nil
            }

            return CutoutShape(rawValue: shape)
        }

        set {
            _cutoutShape = newValue?.rawValue
        }
    }

    var cacheFileSuffix: String {
        return "_activity_design.json"
    }

    var photoFileName: String {
        return "\(activityId).jpg"
    }

    var filteredPhotoFileName: String {
        return "\(activityId)_filtered.jpg"
    }

    var hasSuperDistanceFeaturesEnabled: Bool {
        return (graphType?.requiresSuperDistance ?? false) ||
               (palette?.requiresSuperDistance ?? false) ||
               ((photoFilter ?? .noFilter) != .noFilter) ||
               (cutoutShape?.requiresSuperDistance ?? false)
    }

    func set(statisticType: StatisticType, on: Bool) {
        switch statisticType {
        case .stepCount:
            stepCountEnabled = on
        case .distance:
            distanceEnabled = on
        case .time:
            timeEnabled = on
        case .pace:
            paceEnabled = on
        case .elevationGain:
            elevationEnabled = on
        case .graph:
            routeEnabled = on
        case .location:
            locationEnabled = on
        case .activityType:
            activityTypeEnabled = on
        case .goal:
            goalEnabled = on
        case .activeCal:
            activeCalEnabled = on
        }
    }

    func getPhoto(cacheDecoded: Bool = true) -> UIImage? {
        if let photo = _photo {
            return photo
        }

        if cacheDecoded {
            _photo = ActivityDesignCache.photo(withFileName: photoFileName)
            return _photo
        }

        return ActivityDesignCache.photo(withFileName: photoFileName)
    }

    func getFilteredPhoto(cacheDecoded: Bool = true) -> UIImage? {
        if let photo = _filteredPhoto {
            return photo
        }

        if cacheDecoded {
            _filteredPhoto = ActivityDesignCache.photo(withFileName: filteredPhotoFileName)
            return _filteredPhoto
        }

        return ActivityDesignCache.photo(withFileName: filteredPhotoFileName)
    }

    func writePhoto(_ image: UIImage?) {
        _photo = image
        ActivityDesignCache.writePhoto(image, fileName: photoFileName)
        ActivityDesignCache.writePhoto(nil, fileName: filteredPhotoFileName)
        _filteredPhoto = nil
        invalidateCachedPhoto()
    }

    func writeFilteredPhoto(_ image: UIImage?) {
        _filteredPhoto = image
        ActivityDesignCache.writePhoto(image, fileName: filteredPhotoFileName)
        invalidateCachedPhoto()
    }

    func removePhoto() {
        _photo = nil
        _filteredPhoto = nil
        ActivityDesignCache.writePhoto(nil, fileName: photoFileName)
        ActivityDesignCache.writePhoto(nil, fileName: filteredPhotoFileName)
        photoZoom = nil
        photoOffsetX = nil
        photoOffsetY = nil
        invalidateCachedPhoto()
    }

    private func invalidateCachedPhoto() {
        let documentsDirectory = try? FileManager.default.url(for: .documentDirectory,
                                                                 in: .userDomainMask,
                                                                 appropriateFor: nil,
                                                                 create: true)
        guard let photoUrl = documentsDirectory?.appendingPathComponent(photoFileName),
              let filteredPhotoUrl = documentsDirectory?.appendingPathComponent(filteredPhotoFileName) else {
                  return
        }

        SDImageCache.shared.removeImage(forKey: photoUrl.absoluteString, withCompletion: nil)
        SDImageCache.shared.removeImage(forKey: filteredPhotoUrl.absoluteString, withCompletion: nil)
    }

    private func cache() {
        guard activityId != 0 else {
            return
        }

        ActivityDesignCache.cacheDesign(self)

        if (isStepCountDesign ?? false) {
            UserDefaults.standard.defaultStepCountDesign = self
        } else {
            UserDefaults.standard.defaultDesign = self
        }
    }
}
