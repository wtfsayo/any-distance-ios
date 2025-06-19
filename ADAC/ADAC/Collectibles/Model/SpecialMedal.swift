// Licensed under the Any Distance Source-Available License
//
//  SpecialMedal.swift
//  ADAC
//
//  Created by Daniel Kuntz on 5/3/22.
//

import UIKit

enum SpecialMedal: String, CaseIterable {

    /// The name of the asset has to follow the format medal_special_CASENAME.
    /// i.e. the name of the asset for spring_forward_2021 is medal_special_spring_forward_2021.png
    case juneteenth_2021
    case pride_2021
    case spring_forward_2021
    case launch
    case day1
    case beta
    case haloween_1
    case superdistance
    case preseed

    var date: BasicDate? {
        switch self {
        case .juneteenth_2021:
            return BasicDate(month: 6, day: 19, year: 2021)
        case .haloween_1:
            return BasicDate(month: 10, day: 31)
        case .spring_forward_2021:
            return BasicDate(month: 3, day: 14, year: 2021)
        case .pride_2021:
            return BasicDate(month: 6, day: nil, year: 2021)
        case .day1:
            return BasicDate(from: Date())
        default:
            return nil
        }
    }

    var description: String {
        switch self {
        case .juneteenth_2021:
            return "Juneteenth 2021"
        case .haloween_1:
            return "Halloween"
        case .day1:
            return "Day 1"
        case .beta:
            return "Beta Tester"
        case .launch:
            return "Launch Week"
        case .spring_forward_2021:
            return "Spring Forward"
        case .pride_2021:
            return "Pride Month 2021"
        case .superdistance:
            return "You Are Super"
        case .preseed:
            return "Investor"
        }
    }

    var confettiColors: [UIColor] {
        switch self {
        case .juneteenth_2021:
            return [UIColor(hex: "173063"),
                    UIColor(hex: "DE0119")]
        case .day1:
            return [UIColor(realRed: 238, green: 185, blue: 119),
                    UIColor(realRed: 199, green: 167, blue: 109),
                    UIColor(realRed: 157, green: 107, blue: 39),
                    UIColor(realRed: 44, green: 44, blue: 44)]
        case .beta:
            return [UIColor.white,
                    UIColor(realRed: 212, green: 219, blue: 224),
                    UIColor(realRed: 107, green: 173, blue: 229),
                    UIColor(realRed: 62, green: 100, blue: 211),
                    UIColor(realRed: 75, green: 122, blue: 215)]
        case .haloween_1:
            return [UIColor(realRed: 229, green: 103, blue: 59),
                    UIColor(realRed: 234, green: 143, blue: 79),
                    UIColor(realRed: 45, green: 45, blue: 45),
                    UIColor(realRed: 162, green: 66, blue: 37)]
        case .launch:
            return [UIColor(realRed: 236, green: 181, blue: 112),
                    UIColor(realRed: 160, green: 110, blue: 41),
                    UIColor(realRed: 177, green: 134, blue: 77),
                    UIColor(realRed: 44, green: 44, blue: 44)]
        case .spring_forward_2021:
            return [UIColor(realRed: 241, green: 175, blue: 69),
                    UIColor(realRed: 173, green: 96, blue: 38),
                    UIColor(realRed: 57, green: 19, blue: 26),
                    UIColor(realRed: 9, green: 13, blue: 40)]
        case .pride_2021:
            return [UIColor(hex: "F75506"),
                    UIColor(hex: "EF8EC9"),
                    UIColor(hex: "FB0604"),
                    UIColor(hex: "F7C709"),
                    UIColor(hex: "07A224"),
                    UIColor(hex: "8BBDF4")]
        case .superdistance:
            return [UIColor.adRed,
                    UIColor.adYellow,
                    UIColor.adOrange,
                    UIColor.adOrangeLighter]
        case .preseed:
            return [UIColor(realRed: 239, green: 140, blue: 115),
                    UIColor(realRed: 236, green: 243, blue: 142),
                    UIColor(realRed: 97, green: 210, blue: 250),
                    UIColor(realRed: 140, green: 242, blue: 252)]
        }
    }

    var medalImageHasBlackBackground: Bool {
        switch self {
        case .day1, .launch, .superdistance:
            return true
        default:
            return false
        }
    }

    var blurb: String {
        switch self {
        case .haloween_1:
            return "Being active on Halloween? Spooky stuff."
        case .day1:
            return "Starting is the hardest part. Let's get going. Day 1!"
        case .beta:
            return "Thank you so much for being part of the Any Distance Beta! January - February 2021. We owe you! - Luke & Dan."
        case .launch:
            return "You were active during the first week Any Distance launched on the App Store. Thanks for joining us."
        case .spring_forward_2021:
            return "You made it. It's been a long year and the sun is ready to say hello. Happy Daylight Savings 2021."
        case .pride_2021:
            return "🏳️‍🌈 In June, we celebrate and support the LGBTQ+ community. Medal design contributed by @zachacole."
        case .juneteenth_2021:
            return "Today we recognize Juneteenth – a holiday celebrating the emancipation of those who had been enslaved in the USA.\n\nMedal design based on the Juneteenth flag by Ben Haith and Lisa Jeanne Graf."
        case .superdistance:
            return "Thank you for supporting Any Distance! We truly appreciate it. This is your exclusive collectible medal."
        case .preseed:
            return "Thanks for going the distance with us. Love, Luke & Dan."
        }
    }

    var hintBlurb: String {
        if self.rawValue == SpecialMedal.superdistance.rawValue {
            return "Subscribe to Super Distance to earn this medal."
        }

        guard let date = self.date, let swiftDate = date.swiftDate() else {
            return ""
        }

        var formattedDate = swiftDate.formatted(withStyle: .long)
        if date.day == nil {
            let month = DateFormatter().monthSymbols[date.month - 1]
            if let year = date.year {
                return "Earn this collectible by completing an activity in the month of \(month), \(year)."
            }

            return "Earn this collectible by completing an activity in the month of \(month)."
        }

        if Calendar.current.component(.year, from: swiftDate) == 1 {
            formattedDate = String(formattedDate.dropLast(3))
        }

        return "Earn this collectible by completing an activity on \(formattedDate)."
    }

    var hasCtaButton: Bool {
        switch self {
        case .pride_2021, .juneteenth_2021:
            return true
        default:
            return false
        }
    }

    var ctaLabelTitle: String? {
        switch self {
        case .pride_2021:
            return "Support"
        case .juneteenth_2021:
            return "Learn More"
        default:
            return nil
        }
    }

    var ctaButtonBackgroundColor: UIColor? {
        switch self {
        case .pride_2021:
            return UIColor(hex: "7206F7")
        case .juneteenth_2021:
            return UIColor(hex: "173063")
        default:
            return nil
        }
    }

    var ctaButtonLabelColor: UIColor? {
        switch self {
        case .pride_2021, .juneteenth_2021:
            return .white
        default:
            return nil
        }
    }

    var ctaUrl: URL? {
        switch self {
        case .pride_2021:
            return URL(string: "https://www.thetrevorproject.org/")
        case .juneteenth_2021:
            return URL(string: "https://en.wikipedia.org/wiki/Juneteenth")
        default:
            return nil
        }
    }
}
