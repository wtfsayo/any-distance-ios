// Licensed under the Any Distance Source-Available License
//
//  ExternalService+Keys.swift
//  ADAC
//
//  Created by Jarod Luebbert on 4/13/22.
//

import Foundation
import Keys

extension ExternalService {
    
    private static let keys = ADACKeys()
    
    var consumerKey: String {
        switch self {
        case .wahoo:
#if DEBUG
            return Self.keys.wahooConsumerKey_Sandbox
#else
            return Self.keys.wahooConsumerKey
#endif
        case .garmin:
#if DEBUG
            return Self.keys.garminConsumerKey_Sandbox
#else
            return Self.keys.garminConsumerKey
#endif
        case .appleHealth:
            return ""
        }
    }
    
    var consumerSecret: String {
        switch self {
        case .wahoo:
#if DEBUG
            return Self.keys.wahooConsumerSecret_Sandbox
#else
            return Self.keys.wahooConsumerSecret
#endif
        case .garmin:
#if DEBUG
            return Self.keys.garminConsumerSecret_Sandbox
#else
            return Self.keys.garminConsumerSecret
#endif
        case .appleHealth:
            return ""
        }
    }
    
}
