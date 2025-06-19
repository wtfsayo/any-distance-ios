// Licensed under the Any Distance Source-Available License
//
//  CollectibleGoal.swift
//  ADAC
//
//  Created by Daniel Kuntz on 3/4/21.
//

import UIKit

struct GoalMedal: Codable {
    var medalNumber: Int
    var activityType: ActivityType
    var goalStartDate: Date
    var goalEndDate: Date
    var distanceMeters: Float
    var completionDistanceMeters: Float
    var unit: DistanceUnit

    init(goal: Goal, completionDistanceMeters: Float? = nil) {
        medalNumber = Int.random(in: 1...15)
        activityType = goal.activityType
        goalStartDate = goal.startDate
        goalEndDate = goal.endDate
        distanceMeters = goal.distanceMeters
        self.completionDistanceMeters = completionDistanceMeters ?? 1
        unit = goal.unit
    }

    var formattedPercentComplete: String {
        let progress = Int((completionDistanceMeters * 100 / distanceMeters).rounded())
        return "\(progress)%"
    }

    var medalImage: UIImage? {
        return UIImage(named: medalImageName)
    }

    var medalImageName: String {
        return "medal_goal_\(medalNumber)"
    }

    static func randomBlurb() -> String {
        let blurbs = ["Congratulations on meeting your goal.",
                      "Party time, goal complete!",
                      "And you are done. Amazing effort! Time for a new one?",
                      "Outstanding! Well done on meeting your goal.",
                      "What a feat! Congrats on meeting your goal.",
                      "You worked hard on this one. Nice work.",
                      "Extraordinary effort! Goal complete."]
        return blurbs.randomElement()!
    }

    static var hintBlurb: String {
        return "To earn this collectible, you must complete a goal."
    }

    static func confettiColors(forNumber number: Int) -> [UIColor] {
        switch number {
        case 1:
            return [UIColor(realRed: 239, green: 148, blue: 82),
                    UIColor(realRed: 235, green: 91, blue: 48),
                    UIColor(realRed: 41, green: 98, blue: 52),
                    UIColor(realRed: 29, green: 73, blue: 102),
                    UIColor(realRed: 241, green: 167, blue: 103)]
        case 2:
            return [UIColor(realRed: 178, green: 89, blue: 147),
                    UIColor(realRed: 153, green: 49, blue: 49),
                    UIColor(realRed: 34, green: 16, blue: 77),
                    UIColor(realRed: 195, green: 207, blue: 70),
                    UIColor(realRed: 137, green: 235, blue: 103)]
        case 3:
            return [UIColor(realRed: 243, green: 201, blue: 189),
                    UIColor(realRed: 233, green: 161, blue: 149),
                    UIColor(realRed: 229, green: 147, blue: 133),
                    UIColor(realRed: 201, green: 111, blue: 103),
                    UIColor(realRed: 240, green: 187, blue: 177)]
        case 4:
            return [UIColor(realRed: 131, green: 229, blue: 234),
                    UIColor(realRed: 241, green: 162, blue: 225),
                    UIColor(realRed: 114, green: 191, blue: 227),
                    UIColor(realRed: 153, green: 145, blue: 203),
                    UIColor(realRed: 239, green: 142, blue: 207)]
        case 5:
            return [UIColor(realRed: 220, green: 55, blue: 64),
                    UIColor(realRed: 191, green: 40, blue: 44),
                    UIColor(realRed: 65, green: 15, blue: 37),
                    UIColor(realRed: 204, green: 61, blue: 81),
                    UIColor(realRed: 216, green: 107, blue: 115)]
        case 6:
            return [UIColor(realRed: 215, green: 180, blue: 164),
                    UIColor(realRed: 236, green: 102, blue: 43),
                    UIColor(realRed: 186, green: 77, blue: 31),
                    UIColor(realRed: 118, green: 49, blue: 20),
                    UIColor(realRed: 158, green: 127, blue: 117)]
        case 7:
            return [UIColor(realRed: 240, green: 155, blue: 106),
                    UIColor(realRed: 243, green: 177, blue: 183),
                    UIColor(realRed: 248, green: 209, blue: 132),
                    UIColor(realRed: 233, green: 51, blue: 66),
                    UIColor(realRed: 117, green: 116, blue: 161)]
        case 8:
            return [UIColor(realRed: 239, green: 231, blue: 229),
                    UIColor(realRed: 192, green: 173, blue: 157),
                    UIColor(realRed: 146, green: 131, blue: 110),
                    UIColor(realRed: 142, green: 121, blue: 107),
                    UIColor(realRed: 30, green: 36, blue: 31)]
        case 9:
            return [UIColor(realRed: 238, green: 240, blue: 244),
                    UIColor(realRed: 251, green: 233, blue: 212),
                    UIColor(realRed: 243, green: 176, blue: 152),
                    UIColor(realRed: 246, green: 200, blue: 181),
                    UIColor(realRed: 181, green: 170, blue: 185)]
        case 10:
            return [UIColor(realRed: 234, green: 149, blue: 78),
                    UIColor(realRed: 235, green: 95, blue: 42),
                    UIColor(realRed: 198, green: 42, blue: 199),
                    UIColor(realRed: 72, green: 8, blue: 236),
                    UIColor(realRed: 213, green: 162, blue: 55)]
        case 11:
            return [UIColor(realRed: 90, green: 192, blue: 235),
                    UIColor(realRed: 226, green: 227, blue: 235),
                    UIColor(realRed: 238, green: 124, blue: 117),
                    UIColor(realRed: 53, green: 112, blue: 191),
                    UIColor(realRed: 155, green: 212, blue: 239)]
        case 12:
            return [UIColor(realRed: 241, green: 198, blue: 118),
                    UIColor(realRed: 219, green: 171, blue: 174),
                    UIColor(realRed: 240, green: 164, blue: 60),
                    UIColor(realRed: 219, green: 47, blue: 47),
                    UIColor(realRed: 240, green: 151, blue: 72)]
        case 13:
            return [UIColor(realRed: 247, green: 205, blue: 144),
                    UIColor(realRed: 242, green: 171, blue: 113),
                    UIColor(realRed: 192, green: 184, blue: 189),
                    UIColor(realRed: 81, green: 126, blue: 133),
                    UIColor(realRed: 46, green: 108, blue: 122)]
        case 14:
            return [UIColor(realRed: 198, green: 212, blue: 224),
                    UIColor(realRed: 238, green: 215, blue: 191),
                    UIColor(realRed: 246, green: 194, blue: 131),
                    UIColor(realRed: 238, green: 136, blue: 93),
                    UIColor(realRed: 81, green: 73, blue: 86)]
        case 15:
            return [UIColor.white,
                    UIColor(realRed: 163, green: 163, blue: 163),
                    UIColor(realRed: 111, green: 111, blue: 111),
                    UIColor(realRed: 96, green: 96, blue: 96),
                    UIColor(realRed: 45, green: 45, blue: 45)]
        default:
            return [.white]
        }
    }
}
