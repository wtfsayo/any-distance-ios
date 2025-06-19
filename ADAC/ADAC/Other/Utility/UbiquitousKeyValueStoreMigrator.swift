// Licensed under the Any Distance Source-Available License
//
//  UbiquitousKeyValueStoreMigrator.swift
//  ADAC
//
//  Created by Daniel Kuntz on 3/19/24.
//

import Foundation

class UbiquitousKeyValueStoreMigrator {
    static func migrateIfNecessary() {
        if UserDefaults.standard.hasMigrated {
            return
        }

        let dictionary = UserDefaults.standard.dictionaryRepresentation()
        let keys = dictionary.keys.filter { key in
            // Filter out apple keys
            if key.hasPrefix("com.apple") || key.hasPrefix("com.revenuecat") {
                return false
            }

            // Filter out uppercase keys used by Apple (all AD keys start with lowercase)
            if let first = key.first, String(first) == first.uppercased() {
                return false
            }

            // Filter out HealthKit auth keys
            if key == "hasAskedForHealthKitReadPermission" ||
               key == "hasAskedForHealthKitRingsPermission" ||
               key == "hasFinishedOnboarding" {
                return false
            }

            return true
        }
        print(keys)

        for key in dictionary.keys {
            NSUbiquitousKeyValueStore.default.set(dictionary[key], forKey: key)
        }

        UserDefaults.standard.hasMigrated = true
    }
}

fileprivate extension UserDefaults {
    var hasMigrated: Bool {
        get {
            return bool(forKey: "hasMigratedToUbiquitousKeyValueStore")
        }

        set {
            set(newValue, forKey: "hasMigratedToUbiquitousKeyValueStore")
        }
    }
}
