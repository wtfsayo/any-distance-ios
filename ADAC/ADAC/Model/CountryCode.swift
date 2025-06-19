// Licensed under the Any Distance Source-Available License
//
//  CountryCode.swift
//  ADAC
//
//  Created by Daniel Kuntz on 2/27/23.
//

import Foundation
import CoreTelephony

struct CountryCode {
    static let prefixCodes = ["AF": "93", "AE": "971", "AL": "355", "AN": "599", "AS":"1", "AD": "376", "AO": "244", "AI": "1", "AG":"1", "AR": "54","AM": "374", "AW": "297", "AU":"61", "AT": "43","AZ": "994", "BS": "1", "BH":"973", "BF": "226","BI": "257", "BD": "880", "BB": "1", "BY": "375", "BE":"32","BZ": "501", "BJ": "229", "BM": "1", "BT":"975", "BA": "387", "BW": "267", "BR": "55", "BG": "359", "BO": "591", "BL": "590", "BN": "673", "CC": "61", "CD":"243","CI": "225", "KH":"855", "CM": "237", "CA": "1", "CV": "238", "KY":"345", "CF":"236", "CH": "41", "CL": "56", "CN":"86","CX": "61", "CO": "57", "KM": "269", "CG":"242", "CK": "682", "CR": "506", "CU":"53", "CY":"357","CZ": "420", "DE": "49", "DK": "45", "DJ":"253", "DM": "1", "DO": "1", "DZ": "213", "EC": "593", "EG":"20", "ER": "291", "EE":"372","ES": "34", "ET": "251", "FM": "691", "FK": "500", "FO": "298", "FJ": "679", "FI":"358", "FR": "33", "GB":"44", "GF": "594", "GA":"241", "GS": "500", "GM":"220", "GE":"995","GH":"233", "GI": "350", "GQ": "240", "GR": "30", "GG": "44", "GL": "299", "GD":"1", "GP": "590", "GU": "1", "GT": "502", "GN":"224","GW": "245", "GY": "595", "HT": "509", "HR": "385", "HN":"504", "HU": "36", "HK": "852", "IR": "98", "IM": "44", "IL": "972", "IO":"246", "IS": "354", "IN": "91", "ID":"62", "IQ":"964", "IE": "353","IT":"39", "JM":"1", "JP": "81", "JO": "962", "JE":"44", "KP": "850", "KR": "82","KZ":"77", "KE": "254", "KI": "686", "KW": "965", "KG":"996","KN":"1", "LC": "1", "LV": "371", "LB": "961", "LK":"94", "LS": "266", "LR":"231", "LI": "423", "LT": "370", "LU": "352", "LA": "856", "LY":"218", "MO": "853", "MK": "389", "MG":"261", "MW": "265", "MY": "60","MV": "960", "ML":"223", "MT": "356", "MH": "692", "MQ": "596", "MR":"222", "MU": "230", "MX": "52","MC": "377", "MN": "976", "ME": "382", "MP": "1", "MS": "1", "MA":"212", "MM": "95", "MF": "590", "MD":"373", "MZ": "258", "NA":"264", "NR":"674", "NP":"977", "NL": "31","NC": "687", "NZ":"64", "NI": "505", "NE": "227", "NG": "234", "NU":"683", "NF": "672", "NO": "47","OM": "968", "PK": "92", "PM": "508", "PW": "680", "PF": "689", "PA": "507", "PG":"675", "PY": "595", "PE": "51", "PH": "63", "PL":"48", "PN": "872","PT": "351", "PR": "1","PS": "970", "QA": "974", "RO":"40", "RE":"262", "RS": "381", "RU": "7", "RW": "250", "SM": "378", "SA":"966", "SN": "221", "SC": "248", "SL":"232","SG": "65", "SK": "421", "SI": "386", "SB":"677", "SH": "290", "SD": "249", "SR": "597","SZ": "268", "SE":"46", "SV": "503", "ST": "239","SO": "252", "SJ": "47", "SY":"963", "TW": "886", "TZ": "255", "TL": "670", "TD": "235", "TJ": "992", "TH": "66", "TG":"228", "TK": "690", "TO": "676", "TT": "1", "TN":"216","TR": "90", "TM": "993", "TC": "1", "TV":"688", "UG": "256", "UA": "380", "US": "1", "UY": "598","UZ": "998", "VA":"379", "VE":"58", "VN": "84", "VG": "1", "VI": "1","VC":"1", "VU":"678", "WS": "685", "WF": "681", "YE": "967", "YT": "262","ZA": "27" , "ZM": "260", "ZW": "263"]

    static func format(for code: String) -> String {
        switch code {
        case "BR":
            return "XX XXXX-XXXXX"
        case "HK":
            return "XXXX-XXXX"
        case "IN":
            return "XXXXX-XXXXXX"
        case "DE":
            return "XXXXXXXXXXX"
        case "FR":
            return "XX XX XX XX XX"
        case "ES":
            return "XXX XXX XXX"
        case "PL":
            return "XXX XXX XXX"
        case "NO":
            return "XX XX XX XX"
        case "AU":
            return "XXX XXX XXX"
        case "GB":
            return "XXXXXXXXXX"
        case "AT":
            return "XXXXXXXXXX"
        case "DK":
            return "XX-XX-XX-XX"
        case "CN":
            return "XXX-XXXX-XXXX"
        case "LR":
            return "X XXX XXXX"
        case "LV":
            return "XXX XX XXX"
        case "LU":
            return "XXXX XXXX"
        case "SG":
            return "XXXX XXXX"
        case "CL":
            return "XXX XXX XXX"
        case "EE":
            return "XXX XXXX"
        case "PT":
            return "XXX XXX XXX"
        case "ID":
            return "XXXX-XXXX-XXXX"
        case "MU":
            return "XXXX XXXX"
        case "HU":
            return "XX XXX XXXX"
        case "BY":
            return "XXXXXXXX"
        case "GE":
            return "XXX XXX XXX"
        case "BH":
            return "XXXXXXXX"
        case "LT":
            return "XX XXX XXXX"
        case "UY":
            return "XXXX XXXX"
        case "MK":
            return "XX XXXXXX"
        case "CR":
            return "XXXX-XXXX"
        case "SI":
            return "XXX XX XX"
        case "KR":
            return "XX XXXX XXXX"
        case "CZ":
            return "XXX XXX XXX"
        case "QA":
            return "XX XXXXXX"
        case "US":
            return "XXX-XXX-XXXX"
        default:
            return ""
        }
    }

    static func placeholder(for code: String) -> String {
        return format(for: code)
            .replacingOccurrences(of: "X", with: "0")
    }

    /// Maximum number of digits for phone to be valid. Area code (including +) concatenated with
    /// phone, E164 formatted.
    static func maxCount(for code: String) -> Int {
        switch code {
        case "AT":
            return 15
        case "AU":
            return 13
        case "IN":
            return 20
        case "LU":
            return 13
        case "EE":
            return 12
        case "ID":
            return 16
        case "BY":
            return 20
        case "KR":
            return 13
        case "QA":
            return 12
        default:
            let format = format(for: code)
            if format.isEmpty {
                return 25
            } else {
                let numberCount = format
                    .filter { $0 == "X" }
                    .count
                let codeCount = (prefixCodes[code] ?? "").count + 1
                return numberCount + codeCount
            }
        }
    }

    /// Minimum number of digits for phone to be valid. Area code (including +) concatenated with
    /// phone, E164 formatted.
    static func minCount(for code: String) -> Int {
        switch code {
        case "DE":
            return 10
        case "AT":
            return 5
        case "BR":
            return 13
        case "IN":
            return 13
        case "AU":
            return 12
        case "LU":
            return 10
        case "EE":
            return 11
        case "ID":
            return 13
        case "BY":
            return 12
        case "HU":
            return 9
        case "KR":
            return 11
        case "QA":
            return 7
        default:
            let format = format(for: code)
            if format.isEmpty {
                return (prefixCodes[code]?.count ?? 0) + 5
            }

            return maxCount(for: code)
        }
    }

    static func code(for autofillNumber: String) -> String {
        if autofillNumber.hasPrefix("+1") {
            return "US"
        }

        guard autofillNumber.first == "+", autofillNumber.count >= 2 else {
            return "US"
        }

        let candidates: [String] = Array(prefixCodes.keys).sorted()
        return candidates.first(where: { autofillNumber.hasPrefix("+" + (prefixCodes[$0] ?? "-")) }) ?? "US"
    }
}
