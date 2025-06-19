// Licensed under the Any Distance Source-Available License
//
//  ADProduct.swift
//  ADAC
//
//  Created by Daniel Kuntz on 1/23/23.
//

import Foundation
import StoreKit

struct ADProduct {
    static let threeMonthSDPromoID: String = "rc_promo_Super Distance_three_month"

    var skProduct: SKProduct?
    var productID: String

    var localizedPrice: String {
        if let skProduct = skProduct {
            return skProduct.localizedPrice
        }

        switch productID {
        case ADProduct.threeMonthSDPromoID:
            return "Free"
        default:
            return ""
        }
    }
}
