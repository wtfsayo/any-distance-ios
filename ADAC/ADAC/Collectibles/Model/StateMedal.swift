// Licensed under the Any Distance Source-Available License
//
//  CollectibleStateLocation.swift
//  ADAC
//
//  Created by Daniel Kuntz on 6/16/21.
//

import UIKit

enum StateMedal: String, CaseIterable {
    case al
    case ak
    case `as`
    case az
    case ar
    case ca
    case co
    case ct
    case de
    case dc
    case fm
    case fl
    case ga
    case gu
    case hi
    case id
    case il
    case `in`
    case ia
    case ks
    case ky
    case la
    case me
    case mh
    case md
    case ma
    case mi
    case mn
    case ms
    case mo
    case mt
    case ne
    case nv
    case nh
    case nj
    case nm
    case ny
    case nc
    case nd
    case mp
    case oh
    case ok
    case or
    case pw
    case pa
    case pr
    case ri
    case sc
    case sd
    case tn
    case tx
    case ut
    case vt
    case vi
    case va
    case wa
    case wv
    case wi
    case wy

    var abbreviation: String {
        return rawValue.uppercased()
    }

    var stateName: String {
        switch self {
        case .al:
            return "Alabama"
        case .ak:
            return "Alaska"
        case .`as`:
            return "American Samoa"
        case .az:
            return "Arizona"
        case .ar:
            return "Arkansas"
        case .ca:
            return "California"
        case .co:
            return "Colorado"
        case .ct:
            return "Connecticut"
        case .de:
            return "Delaware"
        case .dc:
            return "District of Columbia"
        case .fm:
            return "Federated States of Micronesia"
        case .fl:
            return "Florida"
        case .ga:
            return "Georgia"
        case .gu:
            return "Guam"
        case .hi:
            return "Hawaii"
        case .id:
            return "Idaho"
        case .il:
            return "Illinois"
        case .`in`:
            return "Indiana"
        case .ia:
            return "Iowa"
        case .ks:
            return "Kansas"
        case .ky:
            return "Kentucky"
        case .la:
            return "Louisiana"
        case .me:
            return "Maine"
        case .mh:
            return "Marshall Islands"
        case .md:
            return "Maryland"
        case .ma:
            return "Massachusetts"
        case .mi:
            return "Michigan"
        case .mn:
            return "Minnesota"
        case .ms:
            return "Mississippi"
        case .mo:
            return "Missouri"
        case .mt:
            return "Montana"
        case .ne:
            return "Nebraska"
        case .nv:
            return "Nevada"
        case .nh:
            return "New Hampshire"
        case .nj:
            return "New Jersey"
        case .nm:
            return "New Mexico"
        case .ny:
            return "New York"
        case .nc:
            return "North Carolina"
        case .nd:
            return "North Dakota"
        case .mp:
            return "Northern Mariana Islands"
        case .oh:
            return "Ohio"
        case .ok:
            return "Oklahoma"
        case .or:
            return "Oregon"
        case .pw:
            return "Palau"
        case .pa:
            return "Pennsylvania"
        case .pr:
            return "Puerto Rico"
        case .ri:
            return "Rhode Island"
        case .sc:
            return "South Carolina"
        case .sd:
            return "South Dakota"
        case .tn:
            return "Tennessee"
        case .tx:
            return "Texas"
        case .ut:
            return "Utah"
        case .vt:
            return "Vermont"
        case .vi:
            return "Virgin Islands"
        case .va:
            return "Virginia"
        case .wa:
            return "Washington"
        case .wv:
            return "West Virginia"
        case .wi:
            return "Wisconsin"
        case .wy:
            return "Wyoming"
        }
    }

    var confettiColors: [UIColor] {
        return [UIColor.white,
                UIColor(realRed: 76, green: 99, blue: 163),
                UIColor(realRed: 34, green: 55, blue: 113),
                UIColor(realRed: 187, green: 43, blue: 33)]
    }

    var blurb: String {
        return "Welcome to \(stateName)."
    }

    var hintBlurb: String {
        return "Earn this collectible by completing an activity in \(stateName)"
    }

    static func new(fromAbbreviation abbreviation: String) -> StateMedal? {
        return allCases.first(where: { $0.abbreviation.caseInsensitiveCompare(abbreviation) == .orderedSame })
    }
}
