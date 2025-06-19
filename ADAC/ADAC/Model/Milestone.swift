// Licensed under the Any Distance Source-Available License
//
//  Milestone.swift
//  ADAC
//
//  Created by Daniel Kuntz on 2/25/24.
//

import UIKit
import Combine

struct Milestone {
    var description: String
    var imageName: String?
    var imageURL: URL?
    var action: () -> Void
}

extension Milestone {
    static let trackFirstActivity = Milestone(description: "Track your first activity", imageName: "andi-shoes") {
        ADTabBarController.current?.setSelectedTab(.track)
    }

    static let setGoal = Milestone(description: "Set a goal 🎯", imageName: "andi-fly") {
        ADTabBarController.current?.setSelectedTab(.stats)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            ReloadPublishers.setNewGoal.send()
        }
    }

    static func track1(unit: DistanceUnit) -> Milestone {
        switch unit {
        case .miles:
            let collectible = Collectible(type: .activity(.mi_1), dateEarned: Date())
            return collectibleMilestone(description: "Track a 1mi activity", collectible: collectible)
        case .kilometers:
            let collectible = Collectible(type: .activity(.km_1), dateEarned: Date())
            return collectibleMilestone(description: "Track a 1km activity", collectible: collectible)
        }
    }

    static func track5k() -> Milestone {
        let collectible = Collectible(type: .activity(.k_5), dateEarned: Date())
        return collectibleMilestone(description: "Track a 5K activity", collectible: collectible)
    }

    static func track100(unit: DistanceUnit) -> Milestone {
        switch unit {
        case .miles:
            let collectible = Collectible(type: .totalDistance(.mi_100), dateEarned: Date())
            return collectibleMilestone(description: "Track 100 miles", collectible: collectible)
        case .kilometers:
            let collectible = Collectible(type: .totalDistance(.km_100), dateEarned: Date())
            return collectibleMilestone(description: "Track 100 kilometers", collectible: collectible)
        }
    }

    static func collectibleMilestone(description: String, collectible: Collectible) -> Milestone {
        return Milestone(description: description, imageURL: collectible.medalImageUrl) {
            showCollectible(collectible)
        }
    }

    private static func showCollectible(_ collectible: Collectible) {
        let storyboard = UIStoryboard(name: "Collectibles", bundle: nil)
        guard let vc = storyboard.instantiateViewController(withIdentifier: "collectibleDetail") as? CollectibleDetailViewController else {
            return
        }

        vc.collectible = collectible
        vc.collectibleEarned = ADUser.current.collectibles
            .contains(where: { $0.type.rawValue == collectible.type.rawValue })
        UIApplication.shared.topViewController?.present(vc, animated: true)
    }
}
