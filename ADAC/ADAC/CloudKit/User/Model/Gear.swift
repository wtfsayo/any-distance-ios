// Licensed under the Any Distance Source-Available License
//
//  Gear.swift
//  ADAC
//
//  Created by Daniel Kuntz on 3/19/24.
//

import Foundation
import Combine
import HealthKit
import UIKit

final class Gear: ObservableObject, Codable, Identifiable {
    let id: String
    @Published var startDate: Date
    @Published var type: GearType
    @Published var name: String
    @Published var color: GearColor
    @Published var distanceTrackedMeters: Float
    @Published var timeTracked: TimeInterval
    private lazy var subscribers: Set<AnyCancellable> = []

    var isNew: Bool {
        return !ADUser.current.gear.contains(self)
    }

    var distanceInSelectedUnit: Float {
        return UnitConverter.meters(distanceTrackedMeters,
                                    toUnit: ADUser.current.distanceUnit)
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d yyyy"
        return formatter.string(from: startDate)
    }

    func addMetrics(for activities: [Activity]) {
        for activity in activities {
            distanceTrackedMeters += activity.distance
            timeTracked += activity.movingTime
        }
    }

    func subtractMetrics(for activities: [Activity]) {
        for activity in activities {
            distanceTrackedMeters = max(distanceTrackedMeters - activity.distance, 0)
            timeTracked = max(timeTracked - activity.movingTime, 0)
        }
    }

    init(type: GearType, name: String) {
        self.id = UUID().uuidString
        self.startDate = Date()
        self.type = type
        self.name = name
        self.color = .white
        self.distanceTrackedMeters = 0.0
        self.timeTracked = 0.0
        observeSelf()
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: GearCodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.startDate = try container.decode(Date.self, forKey: .startDate)
        self.type = try container.decode(GearType.self, forKey: .type)
        self.name = try container.decode(String.self, forKey: .name)
        self.color = try container.decode(GearColor.self, forKey: .color)
        self.distanceTrackedMeters = try container.decode(Float.self, forKey: .distanceTrackedMeters)
        self.timeTracked = try container.decode(TimeInterval.self, forKey: .timeTracked)
        observeSelf()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: GearCodingKeys.self)
        try container.encode(self.id, forKey: .id)
        try container.encode(self.startDate, forKey: .startDate)
        try container.encode(self.type, forKey: .type)
        try container.encode(self.name, forKey: .name)
        try container.encode(self.color, forKey: .color)
        try container.encode(self.distanceTrackedMeters, forKey: .distanceTrackedMeters)
        try container.encode(self.timeTracked, forKey: .timeTracked)
    }

    private func observeSelf() {
        objectWillChange
            .receive(on: DispatchQueue.main)
            .throttle(for: 1.0, scheduler: RunLoop.main, latest: true)
            .sink { _ in
                ADUser.current.saveToUserDefaults()
                Task(priority: .userInitiated) {
                    await UserManager.shared.updateCurrentUser()
                }
            }
            .store(in: &subscribers)
    }
}

enum GearType: String, Codable, CaseIterable {
    case shoes

    var usdzName: String {
        switch self {
        case .shoes:
            return "sneaker"
        }
    }
}

extension ActivityType {
    func matches(gearType: GearType) -> Bool {
        switch gearType {
        case .shoes:
            switch self {
            case .run, .dogRun, .strollerRun, .treadmillRun, .trailRun, .walk, .dogWalk, .strollerWalk, .treadmillWalk, .hotGirlWalk, .walkWithCane, .walkWithWalker, .walkingMeeting, .deskWalk, .dance, .cardioDance, .hike, .rucking, .crossCountrySkiing, .downhillSkiing, .snowboard, .snowSports, .skateboard, .traditionalStrengthTraining, .functionalStrengthTraining, .adaptiveStrengthTraining, .stairClimbing, .boxing, .kickboxing, .martialArts, .taiChi, .climbing, .coreTraining, .pilates, .yoga, .hiit, .basketball, .baseball, .handball, .softball, .australianFootball, .soccer, .archery, .badminton, .golf, .pickleball, .tennis, .tableTennis, .squash, .racquetball, .cricket, .volleyball, .bowling, .hockey, .discSports, .lacrosse, .rugby, .hunting, .rollerskating, .elliptical:
                return true
            default:
                return false
            }
        }
    }
}

enum GearColor: String, Codable, CaseIterable {
    case white
    case whiteBlack
    case black

    // On Running
    case iceAlloy
    case eclipseTurmeric
    case frostCobalt
    case frostAcacia
    case mistBlueberry
    case creamDune
    case frostSurf
    case acaiAloe

    // Hoka
    case duskIllusion
    case oatmilkBarley
    case harbormistBlack
    case shiftingSandEggnog
    case vibrantOrangeImpala
    case ceriseCloudless
    case wheatShiftingSand
    case solarFlareSherbet
    case virtualBlueCerise
    case blackMulti
    case amberHazeSherbet
    case bellwetherBlueDazzlingBlue
    case goldenLichenCeleryRoot
    case rustEarthenware
    case blackAllAboard
    case flameVibrantOrange
    case iceWaterEveningPrimrose
    case zestLimeGlow
    case passionFruitMaize
    case coastalSkyAllAboard
    case ceramicEveningPrimrose

    // Nike
    case seaGlassMandarin
    case lightIronOreMicaGreen
    case bronzineBlackOlive
    case wolfGreyVolt
    case blackLightCrimson
    case blackSailJadeCitron
    case whiteChileRed
    case platinumWhiteGreen
    case universityRedNavy
    case blackKhakiOrange
    case deepJungleEmerald
    case whitePaleIvoryFuchsia

    // Onitsuka
    case yellowBlack
    case birchGreen
    case creamPeacoat
    case creamCilantro
    case cozyPinkCool
    case birchRust
    case beigeGreen
    case midnightMidnight

    // Color on white BG
    case orange
    case green
    case red
    case blue
    case purple

    // Color on black BG
    case orangeDark
    case greenDark
    case redDark
    case blueDark
    case purpleDark

    var mainColor: UIColor {
        switch self {
        case .orange, .green, .red, .blue, .purple, .white, .whiteBlack:
            return UIColor(white: 0.95, alpha: 1)
        case .orangeDark, .greenDark, .redDark, .blueDark, .purpleDark, .black:
            return UIColor(white: 0.15, alpha: 1)

        // On Running
        case .iceAlloy:
            return UIColor(realRed: 214, green: 208, blue: 190)
        case .eclipseTurmeric:
            return UIColor(realRed: 81, green: 84, blue: 90)
        case .frostCobalt:
            return UIColor(white: 0.95, alpha: 1)
        case .frostAcacia:
            return UIColor(white: 0.95, alpha: 1)
        case .mistBlueberry:
            return UIColor(realRed: 135, green: 134, blue: 145)
        case .creamDune:
            return UIColor(realRed: 227, green: 227, blue: 212)
        case .frostSurf:
            return UIColor(realRed: 213, green: 215, blue: 215)
        case .acaiAloe:
            return UIColor(realRed: 49, green: 45, blue: 68)

        // Hoka
        case .duskIllusion:
            return UIColor(realRed: 154, green: 176, blue: 198)
        case .oatmilkBarley:
            return UIColor(realRed: 208, green: 194, blue: 179)
        case .harbormistBlack:
            return UIColor(realRed: 166, green: 165, blue: 163)
        case .shiftingSandEggnog:
            return UIColor(realRed: 213, green: 191, blue: 176)
        case .vibrantOrangeImpala:
            return UIColor(realRed: 234, green: 83, blue: 41)
        case .ceriseCloudless:
            return UIColor(realRed: 219, green: 87, blue: 88)
        case .wheatShiftingSand:
            return UIColor(realRed: 196, green: 171, blue: 148)
        case .solarFlareSherbet:
            return UIColor(realRed: 221, green: 148, blue: 85)
        case .virtualBlueCerise:
            return UIColor(realRed: 70, green: 106, blue: 167)
        case .blackMulti:
            return UIColor(realRed: 164, green: 141, blue: 173)
        case .amberHazeSherbet:
            return UIColor(realRed: 229, green: 181, blue: 111)
        case .bellwetherBlueDazzlingBlue:
            return UIColor(realRed: 20, green: 24, blue: 43)
        case .goldenLichenCeleryRoot:
            return UIColor(realRed: 204, green: 189, blue: 115)
        case .rustEarthenware:
            return UIColor(realRed: 232, green: 161, blue: 147)
        case .blackAllAboard:
            return UIColor(realRed: 49, green: 48, blue: 49)
        case .flameVibrantOrange:
            return UIColor(realRed: 223, green: 76, blue: 45)
        case .iceWaterEveningPrimrose:
            return UIColor(realRed: 216, green: 230, blue: 237)
        case .zestLimeGlow:
            return UIColor(realRed: 183, green: 223, blue: 180)
        case .passionFruitMaize:
            return UIColor(realRed: 224, green: 199, blue: 78)
        case .coastalSkyAllAboard:
            return UIColor(realRed: 54, green: 122, blue: 212)
        case .ceramicEveningPrimrose:
            return UIColor(realRed: 81, green: 170, blue: 150)

        // Nike
        case .seaGlassMandarin:
            return UIColor(realRed: 226, green: 226, blue: 214)
        case .lightIronOreMicaGreen:
            return UIColor(realRed: 134, green: 128, blue: 124)
        case .bronzineBlackOlive:
            return UIColor(realRed: 179, green: 147, blue: 44)
        case .wolfGreyVolt:
            return UIColor(realRed: 210, green: 210, blue: 210)
        case .blackLightCrimson:
            return UIColor(realRed: 29, green: 26, blue: 28)
        case .blackSailJadeCitron:
            return UIColor(realRed: 20, green: 18, blue: 19)
        case .whiteChileRed:
            return UIColor(realRed: 233, green: 235, blue: 239)
        case .platinumWhiteGreen:
            return UIColor(realRed: 229, green: 230, blue: 227)
        case .universityRedNavy:
            return UIColor(realRed: 217, green: 56, blue: 71)
        case .blackKhakiOrange:
            return UIColor(realRed: 26, green: 26, blue: 25)
        case .deepJungleEmerald:
            return UIColor(realRed: 48, green: 63, blue: 69)
        case .whitePaleIvoryFuchsia:
            return UIColor(realRed: 233, green: 233, blue: 237)

        // Onitsuka
        case .yellowBlack:
            return UIColor(realRed: 235, green: 202, blue: 69)
        case .birchGreen:
            return UIColor(realRed: 226, green: 220, blue: 216)
        case .creamPeacoat:
            return UIColor(realRed: 226, green: 220, blue: 216)
        case .creamCilantro:
            return UIColor(realRed: 226, green: 220, blue: 216)
        case .cozyPinkCool:
            return UIColor(realRed: 234, green: 214, blue: 201)
        case .birchRust:
            return UIColor(realRed: 236, green: 231, blue: 223)
        case .beigeGreen:
            return UIColor(realRed: 206, green: 191, blue: 166)
        case .midnightMidnight:
            return UIColor(realRed: 47, green: 47, blue: 64)
        }
    }

    var accent1: UIColor {
        switch self {
        case .orange, .orangeDark:
            return .adOrangeLighter
        case .blue, .blueDark:
            return RecordingGoalType.distance.color
        case .green, .greenDark:
            return UIColor(realRed: 115, green: 168, blue: 61)
        case .red, .redDark:
            return UIColor.adRed
        case .purple, .purpleDark:
            return UIColor.purple
        case .white:
            return UIColor(white: 0.85, alpha: 1)
        case .whiteBlack:
            return UIColor(white: 0.1, alpha: 1)
        case .black:
            return UIColor(white: 0.25, alpha: 1)

        // On Running
        case .iceAlloy:
            return UIColor(realRed: 124, green: 124, blue: 120)
        case .eclipseTurmeric:
            return UIColor(realRed: 201, green: 203, blue: 203)
        case .frostCobalt:
            return UIColor(realRed: 159, green: 157, blue: 160)
        case .frostAcacia:
            return UIColor(realRed: 176, green: 178, blue: 178)
        case .mistBlueberry:
            return UIColor(realRed: 49, green: 51, blue: 63)
        case .creamDune:
            return UIColor(realRed: 214, green: 222, blue: 182)
        case .frostSurf:
            return UIColor(realRed: 61, green: 59, blue: 59)
        case .acaiAloe:
            return UIColor(realRed: 180, green: 182, blue: 183)

        // Hoka
        case .duskIllusion:
            return UIColor(realRed: 215, green: 147, blue: 80)
        case .oatmilkBarley:
            return UIColor(realRed: 201, green: 201, blue: 201)
        case .harbormistBlack:
            return UIColor(realRed: 25, green: 27, blue: 28)
        case .shiftingSandEggnog:
            return UIColor(realRed: 184, green: 190, blue: 192)
        case .vibrantOrangeImpala:
            return UIColor(realRed: 12, green: 38, blue: 90)
        case .ceriseCloudless:
            return UIColor(realRed: 230, green: 191, blue: 124)
        case .wheatShiftingSand:
            return UIColor(realRed: 130, green: 98, blue: 55)
        case .solarFlareSherbet:
            return UIColor(realRed: 213, green: 202, blue: 201)
        case .virtualBlueCerise:
            return UIColor(realRed: 33, green: 31, blue: 81)
        case .blackMulti:
            return UIColor(realRed: 66, green: 140, blue: 115)
        case .amberHazeSherbet:
            return UIColor(realRed: 68, green: 35, blue: 32)
        case .bellwetherBlueDazzlingBlue:
            return UIColor(realRed: 198, green: 51, blue: 36)
        case .goldenLichenCeleryRoot:
            return UIColor(realRed: 32, green: 33, blue: 33)
        case .rustEarthenware:
            return UIColor(realRed: 84, green: 54, blue: 60)
        case .blackAllAboard:
            return UIColor(realRed: 164, green: 164, blue: 162)
        case .flameVibrantOrange:
            return UIColor(realRed: 39, green: 32, blue: 34)
        case .iceWaterEveningPrimrose:
            return UIColor(realRed: 212, green: 221, blue: 77)
        case .zestLimeGlow:
            return UIColor(realRed: 220, green: 156, blue: 69)
        case .passionFruitMaize:
            return UIColor(realRed: 203, green: 57, blue: 38)
        case .coastalSkyAllAboard:
            return UIColor(realRed: 179, green: 197, blue: 221)
        case .ceramicEveningPrimrose:
            return UIColor(realRed: 154, green: 55, blue: 92)

        // Nike
        case .seaGlassMandarin:
            return UIColor(realRed: 171, green: 138, blue: 51)
        case .lightIronOreMicaGreen:
            return UIColor(realRed: 47, green: 46, blue: 43)
        case .bronzineBlackOlive:
            return UIColor(realRed: 207, green: 204, blue: 197)
        case .wolfGreyVolt:
            return UIColor(realRed: 212, green: 234, blue: 132)
        case .blackLightCrimson:
            return UIColor(realRed: 215, green: 212, blue: 212)
        case .blackSailJadeCitron:
            return UIColor(realRed: 222, green: 214, blue: 159)
        case .whiteChileRed:
            return UIColor(realRed: 26, green: 26, blue: 26)
        case .platinumWhiteGreen:
            return UIColor(realRed: 20, green: 20, blue: 21)
        case .universityRedNavy:
            return UIColor(realRed: 233, green: 228, blue: 223)
        case .blackKhakiOrange:
            return UIColor(realRed: 188, green: 91, blue: 36)
        case .deepJungleEmerald:
            return UIColor(realRed: 228, green: 50, blue: 55)
        case .whitePaleIvoryFuchsia:
            return UIColor(realRed: 166, green: 122, blue: 171)

        // Onitsuka
        case .yellowBlack:
            return UIColor(realRed: 28, green: 26, blue: 23)
        case .birchGreen:
            return UIColor(realRed: 53, green: 119, blue: 64)
        case .creamPeacoat:
            return UIColor(realRed: 25, green: 26, blue: 61)
        case .creamCilantro:
            return UIColor(realRed: 77, green: 169, blue: 96)
        case .cozyPinkCool:
            return UIColor(realRed: 207, green: 203, blue: 202)
        case .birchRust:
            return UIColor(realRed: 184, green: 133, blue: 95)
        case .beigeGreen:
            return UIColor(realRed: 79, green: 81, blue: 58)
        case .midnightMidnight:
            return UIColor(realRed: 86, green: 83, blue: 101)
        }
    }

    var accent2: UIColor {
        switch self {
        case .orange, .orangeDark:
            return .adYellow
        case .blue, .blueDark:
            return RecordingGoalType.distance.lighterColor
        case .green, .greenDark:
            return UIColor(realRed: 115, green: 168, blue: 61).darker(by: 20.0)!
        case .red, .redDark:
            return UIColor.adRed.darker(by: 20.0)!
        case .purple, .purpleDark:
            return UIColor.purple.darker(by: 10.0)!
        case .whiteBlack:
            return UIColor(white: 0.1, alpha: 1)
        case .white, .black:
            return accent1

        // On Running
        case .iceAlloy:
            return UIColor(realRed: 100, green: 95, blue: 92)
        case .eclipseTurmeric:
            return UIColor(realRed: 207, green: 114, blue: 57)
        case .frostCobalt:
            return UIColor(white: 0.85, alpha: 1)
        case .frostAcacia:
            return UIColor(realRed: 192, green: 189, blue: 132)
        case .mistBlueberry:
            return UIColor(realRed: 193, green: 187, blue: 178)
        case .creamDune:
            return UIColor(realRed: 176, green: 146, blue: 113)
        case .frostSurf:
            return UIColor(realRed: 158, green: 177, blue: 178)
        case .acaiAloe:
            return UIColor(realRed: 196, green: 197, blue: 190)

        // Hoka
        case .duskIllusion:
            return UIColor(realRed: 163, green: 205, blue: 154)
        case .oatmilkBarley:
            return UIColor(realRed: 168, green: 166, blue: 150)
        case .harbormistBlack:
            return UIColor(realRed: 25, green: 27, blue: 28)
        case .shiftingSandEggnog:
            return UIColor(realRed: 221, green: 213, blue: 197)
        case .vibrantOrangeImpala:
            return UIColor(realRed: 218, green: 142, blue: 96)
        case .ceriseCloudless:
            return UIColor(realRed: 28, green: 38, blue: 94)
        case .wheatShiftingSand:
            return UIColor(realRed: 221, green: 205, blue: 175)
        case .solarFlareSherbet:
            return UIColor(realRed: 100, green: 170, blue: 85)
        case .virtualBlueCerise:
            return UIColor(realRed: 214, green: 223, blue: 79)
        case .blackMulti:
            return UIColor(realRed: 190, green: 118, blue: 105)
        case .amberHazeSherbet:
            return UIColor(realRed: 118, green: 47, blue: 36)
        case .bellwetherBlueDazzlingBlue:
            return UIColor(realRed: 76, green: 90, blue: 188)
        case .goldenLichenCeleryRoot:
            return UIColor(realRed: 175, green: 146, blue: 62)
        case .rustEarthenware:
            return UIColor(realRed: 61, green: 8, blue: 6)
        case .blackAllAboard:
            return UIColor(realRed: 221, green: 227, blue: 116)
        case .flameVibrantOrange:
            return UIColor(realRed: 145, green: 195, blue: 128)
        case .iceWaterEveningPrimrose:
            return UIColor(realRed: 53, green: 119, blue: 191)
        case .zestLimeGlow:
            return UIColor(realRed: 65, green: 146, blue: 159)
        case .passionFruitMaize:
            return UIColor(realRed: 56, green: 128, blue: 149)
        case .coastalSkyAllAboard:
            return UIColor(realRed: 228, green: 128, blue: 72)
        case .ceramicEveningPrimrose:
            return UIColor(realRed: 199, green: 197, blue: 64)

        // Nike
        case .seaGlassMandarin:
            return UIColor(realRed: 36, green: 60, blue: 32)
        case .lightIronOreMicaGreen:
            return UIColor(realRed: 181, green: 194, blue: 185)
        case .bronzineBlackOlive:
            return UIColor(realRed: 196, green: 166, blue: 100)
        case .wolfGreyVolt:
            return UIColor(realRed: 223, green: 224, blue: 226)
        case .blackLightCrimson:
            return UIColor(realRed: 202, green: 64, blue: 65)
        case .blackSailJadeCitron:
            return UIColor(realRed: 231, green: 229, blue: 221)
        case .whiteChileRed:
            return UIColor(realRed: 209, green: 65, blue: 36)
        case .platinumWhiteGreen:
            return UIColor(realRed: 109, green: 211, blue: 121)
        case .universityRedNavy:
            return UIColor(realRed: 227, green: 226, blue: 230)
        case .blackKhakiOrange:
            return UIColor(realRed: 224, green: 224, blue: 224)
        case .deepJungleEmerald:
            return UIColor(realRed: 182, green: 212, blue: 201)
        case .whitePaleIvoryFuchsia:
            return UIColor(realRed: 161, green: 216, blue: 144)

        // Onitsuka
        case .yellowBlack:
            return UIColor(realRed: 28, green: 26, blue: 23)
        case .birchGreen:
            return UIColor(realRed: 133, green: 28, blue: 29)
        case .creamPeacoat:
            return UIColor(realRed: 133, green: 50, blue: 67)
        case .creamCilantro:
            return UIColor(realRed: 231, green: 176, blue: 79)
        case .cozyPinkCool:
            return UIColor(realRed: 207, green: 203, blue: 202)
        case .birchRust:
            return UIColor(realRed: 219, green: 208, blue: 188)
        case .beigeGreen:
            return UIColor(realRed: 103, green: 63, blue: 35)
        case .midnightMidnight:
            return UIColor(realRed: 76, green: 77, blue: 95)
        }
    }

    var accent3: UIColor {
        switch self {
        case .orange, .green, .red, .blue, .purple:
            return UIColor(realRed: 215, green: 208, blue: 180)
        case .white, .whiteBlack:
            return UIColor(white: 0.9, alpha: 1)
        case .orangeDark, .greenDark, .redDark, .blueDark, .purpleDark, .black:
            return UIColor(white: 0.2, alpha: 1)

        // On Running
        case .iceAlloy:
            return UIColor(realRed: 189, green: 186, blue: 166)
        case .eclipseTurmeric:
            return UIColor(realRed: 213, green: 216, blue: 217)
        case .frostCobalt:
            return UIColor(realRed: 56, green: 93, blue: 178)
        case .frostAcacia:
            return UIColor(realRed: 220, green: 218, blue: 213)
        case .mistBlueberry:
            return UIColor(realRed: 85, green: 89, blue: 152)
        case .creamDune:
            return UIColor(realRed: 212, green: 212, blue: 172)
        case .frostSurf:
            return UIColor(realRed: 224, green: 226, blue: 233)
        case .acaiAloe:
            return UIColor(realRed: 84, green: 75, blue: 135)

        // Hoka
        case .duskIllusion:
            return UIColor(realRed: 204, green: 211, blue: 214)
        case .oatmilkBarley:
            return UIColor(realRed: 224, green: 217, blue: 202)
        case .harbormistBlack:
            return UIColor(realRed: 188, green: 191, blue: 192)
        case .shiftingSandEggnog:
            return UIColor(realRed: 209, green: 185, blue: 163)
        case .vibrantOrangeImpala:
            return UIColor(realRed: 56, green: 126, blue: 209)
        case .ceriseCloudless:
            return UIColor(realRed: 168, green: 214, blue: 217)
        case .wheatShiftingSand:
            return UIColor(realRed: 182, green: 141, blue: 91)
        case .solarFlareSherbet:
            return UIColor(realRed: 220, green: 216, blue: 221)
        case .virtualBlueCerise:
            return UIColor(realRed: 51, green: 48, blue: 105)
        case .blackMulti:
            return UIColor(realRed: 35, green: 35, blue: 37)
        case .amberHazeSherbet:
            return UIColor(realRed: 197, green: 109, blue: 62)
        case .bellwetherBlueDazzlingBlue:
            return UIColor(realRed: 190, green: 204, blue: 212)
        case .goldenLichenCeleryRoot:
            return UIColor(realRed: 213, green: 210, blue: 167)
        case .rustEarthenware:
            return UIColor(realRed: 141, green: 66, blue: 59)
        case .blackAllAboard:
            return UIColor(realRed: 87, green: 88, blue: 90)
        case .flameVibrantOrange:
            return UIColor(realRed: 245, green: 190, blue: 89)
        case .iceWaterEveningPrimrose:
            return UIColor(realRed: 236, green: 234, blue: 235)
        case .zestLimeGlow:
            return UIColor(realRed: 133, green: 205, blue: 131)
        case .passionFruitMaize:
            return UIColor(realRed: 241, green: 205, blue: 78)
        case .coastalSkyAllAboard:
            return UIColor(realRed: 224, green: 223, blue: 228)
        case .ceramicEveningPrimrose:
            return UIColor(realRed: 52, green: 120, blue: 163)

        // Nike
        case .seaGlassMandarin:
            return UIColor(realRed: 222, green: 222, blue: 209)
        case .lightIronOreMicaGreen:
            return UIColor(realRed: 222, green: 210, blue: 191)
        case .bronzineBlackOlive:
            return UIColor(realRed: 180, green: 149, blue: 64)
        case .wolfGreyVolt:
            return UIColor(realRed: 56, green: 55, blue: 52)
        case .blackLightCrimson:
            return UIColor(realRed: 25, green: 25, blue: 24)
        case .blackSailJadeCitron:
            return UIColor(realRed: 200, green: 139, blue: 100)
        case .whiteChileRed:
            return UIColor(realRed: 231, green: 230, blue: 217)
        case .platinumWhiteGreen:
            return UIColor(realRed: 226, green: 226, blue: 226)
        case .universityRedNavy:
            return UIColor(realRed: 205, green: 49, blue: 64)
        case .blackKhakiOrange:
            return UIColor(realRed: 39, green: 31, blue: 32)
        case .deepJungleEmerald:
            return UIColor(realRed: 55, green: 78, blue: 83)
        case .whitePaleIvoryFuchsia:
            return UIColor(realRed: 223, green: 221, blue: 207)

        // Onitsuka
        case .yellowBlack:
            return UIColor(realRed: 248, green: 217, blue: 81)
        case .birchGreen:
            return UIColor(realRed: 226, green: 220, blue: 217)
        case .creamPeacoat:
            return UIColor(realRed: 226, green: 220, blue: 217)
        case .creamCilantro:
            return UIColor(realRed: 205, green: 189, blue: 162)
        case .cozyPinkCool:
            return UIColor(realRed: 226, green: 203, blue: 187)
        case .birchRust:
            return UIColor(realRed: 230, green: 224, blue: 212)
        case .beigeGreen:
            return UIColor(realRed: 131, green: 84, blue: 49)
        case .midnightMidnight:
            return UIColor(realRed: 231, green: 231, blue: 233)
        }
    }

    var accent4: UIColor {
        switch self {
        case .orange, .green, .red, .blue, .purple, .white, .whiteBlack:
            return UIColor(white: 0.8, alpha: 1)
        case .orangeDark, .greenDark, .redDark, .blueDark, .purpleDark, .black:
            return accent1

        // On Running
        case .iceAlloy:
            return UIColor(realRed: 120, green: 116, blue: 103)
        case .eclipseTurmeric:
            return UIColor(white: 0.1, alpha: 1)
        case .frostCobalt:
            return UIColor(realRed: 176, green: 62, blue: 47)
        case .frostAcacia:
            return UIColor(realRed: 142, green: 85, blue: 86)
        case .mistBlueberry:
            return UIColor(white: 0.1, alpha: 1)
        case .creamDune:
            return UIColor(white: 0.1, alpha: 1)
        case .frostSurf:
            return UIColor(white: 0.4, alpha: 1)
        case .acaiAloe:
            return UIColor(realRed: 237, green: 247, blue: 208)

        // Hoka
        case .duskIllusion:
            return UIColor(realRed: 66, green: 98, blue: 128)
        case .oatmilkBarley:
            return UIColor(realRed: 128, green: 122, blue: 110)
        case .harbormistBlack:
            return UIColor(realRed: 25, green: 27, blue: 28)
        case .shiftingSandEggnog:
            return UIColor(realRed: 202, green: 164, blue: 133)
        case .vibrantOrangeImpala:
            return UIColor(realRed: 150, green: 35, blue: 24)
        case .ceriseCloudless:
            return UIColor(realRed: 196, green: 41, blue: 50)
        case .wheatShiftingSand:
            return UIColor(realRed: 163, green: 121, blue: 77)
        case .solarFlareSherbet:
            return UIColor(realRed: 234, green: 128, blue: 71)
        case .virtualBlueCerise:
            return UIColor(realRed: 5, green: 3, blue: 8)
        case .blackMulti:
            return UIColor(realRed: 234, green: 234, blue: 125)
        case .amberHazeSherbet:
            return UIColor(realRed: 124, green: 44, blue: 41)
        case .bellwetherBlueDazzlingBlue:
            return UIColor(realRed: 203, green: 55, blue: 48)
        case .goldenLichenCeleryRoot:
            return UIColor(realRed: 195, green: 190, blue: 93)
        case .rustEarthenware:
            return UIColor(realRed: 162, green: 62, blue: 57)
        case .blackAllAboard:
            return UIColor(realRed: 63, green: 59, blue: 60)
        case .flameVibrantOrange:
            return UIColor(realRed: 15, green: 13, blue: 16)
        case .iceWaterEveningPrimrose:
            return UIColor(realRed: 216, green: 226, blue: 234)
        case .zestLimeGlow:
            return UIColor(realRed: 70, green: 133, blue: 143)
        case .passionFruitMaize:
            return UIColor(realRed: 224, green: 76, blue: 43)
        case .coastalSkyAllAboard:
            return UIColor(realRed: 17, green: 48, blue: 122)
        case .ceramicEveningPrimrose:
            return UIColor(realRed: 203, green: 133, blue: 81)

        // Nike
        case .seaGlassMandarin:
            return UIColor(realRed: 222, green: 222, blue: 209)
        case .lightIronOreMicaGreen:
            return UIColor(realRed: 226, green: 229, blue: 226)
        case .bronzineBlackOlive:
            return UIColor(realRed: 219, green: 191, blue: 116)
        case .wolfGreyVolt:
            return UIColor(realRed: 213, green: 246, blue: 122)
        case .blackLightCrimson:
            return UIColor(realRed: 25, green: 25, blue: 24)
        case .blackSailJadeCitron:
            return UIColor(realRed: 170, green: 210, blue: 207)
        case .whiteChileRed:
            return UIColor(realRed: 189, green: 191, blue: 193)
        case .platinumWhiteGreen:
            return UIColor(realRed: 226, green: 226, blue: 226)
        case .universityRedNavy:
            return UIColor(realRed: 58, green: 52, blue: 130)
        case .blackKhakiOrange:
            return UIColor(realRed: 63, green: 87, blue: 95)
        case .deepJungleEmerald:
            return UIColor(realRed: 144, green: 170, blue: 228)
        case .whitePaleIvoryFuchsia:
            return UIColor(realRed: 19, green: 21, blue: 22)

        // Onitsuka
        case .yellowBlack:
            return UIColor(realRed: 250, green: 225, blue: 106)
        case .birchGreen:
            return UIColor(realRed: 245, green: 240, blue: 236)
        case .creamPeacoat:
            return UIColor(realRed: 245, green: 240, blue: 236)
        case .creamCilantro:
            return UIColor(realRed: 245, green: 240, blue: 236)
        case .cozyPinkCool:
            return UIColor(realRed: 236, green: 217, blue: 202)
        case .birchRust:
            return UIColor(realRed: 241, green: 237, blue: 225)
        case .beigeGreen:
            return UIColor(realRed: 209, green: 193, blue: 166)
        case .midnightMidnight:
            return UIColor(realRed: 68, green: 72, blue: 97)
        }
    }
}

fileprivate enum GearCodingKeys: String, CodingKey {
    case id
    case startDate
    case type
    case name
    case color
    case distanceTrackedMeters
    case timeTracked
}

extension Gear: Equatable {
    static func == (lhs: Gear, rhs: Gear) -> Bool {
        return lhs === rhs
    }
}

extension Activity {
    var gearIDs: [String] {
        get {
            return NSUbiquitousKeyValueStore.default.activityIDGearIDMap[self.id] ?? []
        }

        set {
            let curIDs = Set(gearIDs)
            let added = Set(newValue).subtracting(curIDs)
            let removed = curIDs.subtracting(Set(newValue))

            for gearID in added {
                let gear = ADUser.current.gear.first(where: { $0.id == gearID })
                gear?.addMetrics(for: [self])
            }

            for gearID in removed {
                let gear = ADUser.current.gear.first(where: { $0.id == gearID })
                gear?.subtractMetrics(for: [self])
            }

            NSUbiquitousKeyValueStore.default.activityIDGearIDMap[self.id] = newValue
        }
    }
}

extension NSUbiquitousKeyValueStore {
    var activityIDGearIDMap: [String: [String]] {
        get {
            if let data = data(forKey: "activityIDGearIDMap"),
               let decoded = try? JSONDecoder().decode([String: [String]].self, from: data) {
                return decoded
            }

            return [:]
        }

        set {
            if let encoded = try? JSONEncoder().encode(newValue) {
                set(encoded, forKey: "activityIDGearIDMap")
            }
        }
    }

    var selectedGearForTypes: [GearType: String] { // GearType: Gear ID
        get {
            if let data = data(forKey: "selectedGearForTypes"),
               let decoded = try? JSONDecoder().decode([GearType: String].self, from: data) {
                return decoded
            }

            return [:]
        }

        set {
            if let encoded = try? JSONEncoder().encode(newValue) {
                set(encoded, forKey: "selectedGearForTypes")
            }
        }
    }

    var lastGearRefreshDate: Date? {
        get {
            if let data = data(forKey: "lastGearRefreshDate"),
               let decoded = try? JSONDecoder().decode(Date.self, from: data) {
                return decoded
            }

            return nil
        }

        set {
            if let encoded = try? JSONEncoder().encode(newValue) {
                set(encoded, forKey: "lastGearRefreshDate")
            }
        }
    }
}
