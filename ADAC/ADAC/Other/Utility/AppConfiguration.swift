// Licensed under the Any Distance Source-Available License
//
//  AppConfiguration.swift
//  ADAC
//
//  Created by Daniel Kuntz on 2/1/21.
//

import Foundation

enum AppConfiguration: String {
    case debug
    case testFlight
    case appStore
}

struct Config {
    static let isTestFlight = Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"

    static var isDebug: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    static var appConfiguration: AppConfiguration {
        if isDebug {
            return .debug
        } else if isTestFlight {
            return .testFlight
        } else {
            return .appStore
        }
    }
}
