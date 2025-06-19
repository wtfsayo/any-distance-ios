// Licensed under the Any Distance Source-Available License
//
//  Collectible.swift
//  ADAC
//
//  Created by Daniel Kuntz on 2/1/21.
//

import UIKit
import SDWebImage

final class Collectible: Codable, Hashable, ActivityTableViewDataClass {
    var type: CollectibleType
    var dateEarned: Date

    var sortDate: Date {
        return dateEarned
    }

    init(type: CollectibleType, dateEarned: Date) {
        self.type = type
        self.dateEarned = dateEarned
    }

    var medalImage: UIImage? {
        get async {
            return await withCheckedContinuation { continuation in
                SDWebImageManager.shared.loadImage(with: medalImageUrl, progress: nil) { image, data, error, cacheType, finished, url in
                    continuation.resume(returning: image)
                }
            }
        }
    }

    var medalImageUrl: URL? {
        switch type {
        case .remote(let collectible):
            if let url = collectible.medalImageUrl {
                return url
            }
        default: break
        }

        return Bundle.main.url(forResource: medalImageName, withExtension: "png")
    }

    var medalImageHasBlackBackground: Bool {
        switch type {
        case .location(_),
             .activity(.half_marathon),
             .activity(.full_marathon):
            return true
        case .totalDistance(let distance):
            if distance.unitlessDistance >= 1000 {
                return true
            }
            return false
        case .special(let type):
            return type.medalImageHasBlackBackground
        case .remote(let remote):
            return remote.medalImageHasBlackBackground
        default:
            return false
        }
    }

    var medalBorderColor: UIColor? {
        get async {
            switch type {
            case .activity(let distance):
                if distance != .full_marathon && distance != .half_marathon {
                    return UIColor(realRed: 180, green: 180, blue: 180)
                }
            default: break
            }

            return await medalImage?.sd_color(at: CGPoint(x: 400, y: 13))
        }
    }

    var medalImageName: String {
        switch type {
        case .goal_new(let goal):
            return goal.medalImageName
        default:
            return "medal_\(type.rawValue)"
        }
    }

    var typeDescription: String {
        switch type {
        case .location(_), .locationstate(_):
            return "Location Achievement"
        case .goal(_), .goal_new(_):
            return "Goal Complete"
        case .special(_):
            return "Special Achievement"
        case .activity(_):
            return "Activity Achievement"
        case .totalDistance(_):
            return "Total Distance"
        case .remote(let collectible):
            return collectible.itemType.description
        case .remoteUnknown(_):
            return ""
        }
    }

    var sectionName: String {
        switch type {
        case .location(_):
            return "Cities"
        case .locationstate(_):
            return "States"
        case .goal(_), .goal_new(_):
            return "Goals"
        case .special(_):
            return "Special"
        case .remote(let remoteCollectible):
            return remoteCollectible.sectionName
        case .activity(_):
            return "Activities"
        case .totalDistance(_):
            return "Total Distance"
        case .remoteUnknown(_):
            return ""
        }
    }

    var sortOrder: Int {
        switch type {
        case .location(_):
            return 50
        case .locationstate(_):
            return 60
        case .goal(_), .goal_new(_):
            return 30
        case .special(_):
            return 0
        case .remote(let remoteCollectible):
            return remoteCollectible.sectionSortOrder
        case .activity(_):
            return 10
        case .totalDistance(_):
            return 20
        case .remoteUnknown(_):
            return -1
        }
    }

    var description: String {
        switch type {
        case .location(let location):
            return location.cityDisplayName
        case .locationstate(let location):
            return location.stateName
        case .goal(_):
            return "Goal Reached"
        case .goal_new(let goal):
            return goal.formattedPercentComplete
        case .special(let type):
            return type.description
        case .activity(let distance), .totalDistance(let distance):
            return distance.description
        case .remote(let type):
            return type.description
        case .remoteUnknown(_):
            return ""
        }
    }

    var shorterDescription: String {
        switch type {
        case .activity(let distance), .totalDistance(let distance):
            return distance.shorterDescription
        default:
            return description
        }
    }

    var itemType: ItemType {
        switch type {
        case .remote(let remote):
            return remote.itemType
        default:
            return .medal
        }
    }

    var subtitle: String? {
        switch type {
        case .remote(let remote):
            return remote.subtitle
        default:
            return nil
        }
    }

    var canOnlyBeEarnedOnce: Bool {
        return type.rawValue.contains("totaldistance") ||
               type.rawValue.contains("location") ||
               type.rawValue.contains("special") ||
               type.rawValue.contains("remote")
    }

    // returns the distance of the medal if there is one
    var distance: Float {
        switch type {
        case .totalDistance(let medal):
            return medal.unitlessDistance
        default:
            return 0.0
        }
    }

    static func == (lhs: Collectible, rhs: Collectible) -> Bool {
        return lhs.type.rawValue == rhs.type.rawValue && lhs.dateEarned == rhs.dateEarned
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(type.rawValue)
        hasher.combine(dateEarned)
    }
}
