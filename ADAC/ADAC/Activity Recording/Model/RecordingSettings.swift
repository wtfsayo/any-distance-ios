// Licensed under the Any Distance Source-Available License
//
//  RecordingSettings.swift
//  ADAC
//
//  Created by Any Distance on 8/2/22.
//

import Foundation

struct RecordingSettings: Codable {
    var routeClipDescriptionString: String {
        let percentString = String(Int(routeClipPercentage * 100))
        return "This will clip the first and last \(percentString)% of your route if you choose to share it."
    }

    var routeClipPercentageString: String {
        return String(Int(routeClipPercentage * 100)) + "%"
    }
    
    var clipRoute: Bool = false
    var showSafetyMessagePrompt: Bool = false
    var preventAutoLock: Bool = false
    var routeClipPercentage: Double = 0.1
}
