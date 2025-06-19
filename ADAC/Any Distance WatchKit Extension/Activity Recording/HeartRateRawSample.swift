// Licensed under the Any Distance Source-Available License
//
//  HeartRateRawSample.swift
//  Any Distance WatchKit Extension
//
//  Created by Daniel Kuntz on 10/12/22.
//

import Foundation

struct HeartRateRawSample: Codable, Equatable {
    let bpm: Double
    let date: Date
}
