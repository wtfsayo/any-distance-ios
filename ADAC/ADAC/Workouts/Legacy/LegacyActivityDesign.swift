// Licensed under the Any Distance Source-Available License
//
//  ActivityDesign.swift
//  ADAC
//
//  Created by Daniel Kuntz on 1/18/21.
//

import UIKit
import SDWebImage

final class LegacyActivityDesign: Codable {
    private(set) var activityId: Int = 0

    private var _cutoutShape: String?

    private(set) var font: ADFont?
    private(set) var alignment: StatisticAlignment?
    private(set) var routeEnabled: Bool?
    private(set) var graphType: GraphType?
    private(set) var distanceEnabled: Bool?
    private(set) var timeEnabled: Bool?
    private(set) var paceEnabled: Bool?
    private(set) var activeCalEnabled: Bool?
    private(set) var stepCountEnabled: Bool?
    private(set) var elevationEnabled: Bool?
    private(set) var locationEnabled: Bool?
    private(set) var goalEnabled: Bool?
    private(set) var activityTypeEnabled: Bool?
    private(set) var photoZoom: Float?
    private(set) var photoOffsetX: Float?
    private(set) var photoOffsetY: Float?
    private(set) var videoUrl: URL?
    private(set) var videoMode: VideoMode?
    private(set) var photoFilter: PhotoFilter?
    private(set) var routeTransform: CGAffineTransform?
    private(set) var isStepCountDesign: Bool?
    private(set) var palette: Palette?
    private var _photo: UIImage?
    private var _filteredPhoto: UIImage?
    
    // just used for tests
    init(activityId: Int,
         isStepCountDesign: Bool,
         stepCountEnabled: Bool,
         elevationEnabled: Bool,
         activeCalEnabled: Bool) {
        self.activityId = activityId
        self.isStepCountDesign = isStepCountDesign
        self.stepCountEnabled = stepCountEnabled
        self.elevationEnabled = elevationEnabled
        self.activeCalEnabled = activeCalEnabled
    }

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

    static var cacheFileSuffix: String {
        return "_activity_design.json"
    }

    var photoFileName: String {
        return "\(activityId).jpg"
    }

    var filteredPhotoFileName: String {
        return "\(activityId)_filtered.jpg"
    }

}
