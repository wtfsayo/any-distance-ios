// Licensed under the Any Distance Source-Available License
//
//  CollectibleLocation.swift
//  ADAC
//
//  Created by Daniel Kuntz on 2/4/21.
//

import UIKit

enum CityMedal: String, CaseIterable {
    case atlanta
    case austin
    case beijing
    case bristol
    case brooklyn
    case buenos_aires
    case cairo
    case chicago
    case dc
    case edinburgh
    case glasgow
    case lisbon
    case london
    case los_angeles
    case madrid
    case mexico_city
    case moscow
    case new_orleans
    case new_york
    case osaka
    case paris
    case portland
    case rome
    case san_francisco
    case seattle
    case tokyo
    case miami
    case denver
    case gloucester
    case cardiff
    case kodiak

    var cityName: String {
        switch self {
        case .buenos_aires:
            return "Buenos Aires"
        case .dc:
            return "Washington"
        case .mexico_city:
            return "Mexico City"
        case .new_orleans:
            return "New Orleans"
        case .san_francisco:
            return "San Francisco"
        case .new_york:
            return "New York"
        case .los_angeles:
            return "Los Angeles"
        default:
            return rawValue.capitalized
        }
    }

    var possibleCityNames: [String] {
        switch self {
        case .moscow:
            return ["Moscow", "Mockba", "Москва"]
        default:
            return [cityName]
        }
    }

    var cityDisplayName: String {
        switch self {
        case .dc:
            return "Washington, DC"
        default:
            return cityName
        }
    }

    var confettiColors: [UIColor] {
        return [UIColor(realRed: 236, green: 181, blue: 112),
                UIColor(realRed: 160, green: 110, blue: 41),
                UIColor(realRed: 177, green: 134, blue: 77),
                UIColor(realRed: 44, green: 44, blue: 44)]
    }

    var blurb: String {
        switch self {
        case .atlanta:
            return "Welcome to ATL. Watch out for the wing bones in random places."
        case .austin:
            return "Violet Crown City, Austin! Welcome!"
        case .beijing:
            return "Hello from the Northern Capital."
        case .bristol:
            return "How be? Welcome to Bristol o'l butt."
        case .brooklyn:
            return "Brooklyn, you already know."
        case .buenos_aires:
            return "Queen of El Plata, Buenos Aires. Welcome!"
        case .cairo:
            return "Cairo, Egypt’s sprawling capital. Welcome!"
        case .chicago:
            return "The City that Works, welcome to Chicago!"
        case .dc:
            return "The heart of American democracy, DC. Welcome!"
        case .edinburgh:
            return "Aye. Welcome to Edinburgh!"
        case .glasgow:
            return "Welcome to Glasgow!"
        case .lisbon:
            return "Hello from Lisbon!"
        case .london:
            return "Hello there. Welcome to The Old Smoke."
        case .los_angeles:
            return "Yo from Los Angeles."
        case .madrid:
            return "Welcome! The Center of All The Roads in Spain, Madrid."
        case .mexico_city:
            return "You hit CDMX. Welcome to Mexico City!"
        case .moscow:
            return "Welcome to большая деревня!"
        case .new_orleans:
            return "NOLA welcomes you. Please drink responsibly."
        case .new_york:
            return "NYC, the large round fruit."
        case .osaka:
            return "Welcome to Osaka!"
        case .paris:
            return "Bonjour from the City of Light."
        case .portland:
            return "The City of Roses, Portland! Did you bring coat?"
        case .rome:
            return "The Eternal City, Rome. Welcome!"
        case .san_francisco:
            return "Don't call it San Fran please. Welcome to SF!"
        case .seattle:
            return "Can you see many mountains? Welcome to Seattle!"
        case .tokyo:
            return "Welcome to Toyko!"
        case .miami:
            return "Uh, uh, yeah, yeah, yeah, yeah, uh. Miami, uh, uh South Beach, bringin the heat, uh. Haha, can y'all feel that"
        case .denver:
            return "Welcome to the Queen City of the Plains. Hello Denver."
        case .gloucester:
            return "DYK: Gloucester Cathedral has appeared in two Harry Potter films - Harry Potter and the Philosopher's Stone and Harry Potter and the Chamber of Secrets."
        case .cardiff:
            return "Beware, dragons and castles."
        case .kodiak:
            return "Only about 14,000 live here, how many did you meet?"
        }
    }

    var hintBlurb: String {
        return "Earn this collectible by completing an activity in \(cityDisplayName)."
    }

    static func new(fromCityName city: String) -> CityMedal? {
        return allCases.first { location in
            location.possibleCityNames.contains(where: { $0.caseInsensitiveCompare(city) == .orderedSame })
        }
    }
}
