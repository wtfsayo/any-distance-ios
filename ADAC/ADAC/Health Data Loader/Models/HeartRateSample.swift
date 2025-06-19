// Licensed under the Any Distance Source-Available License
//
//  HeartRateSample.swift
//  ADAC
//
//  Created by Jarod Luebbert on 4/22/22.
//

import Foundation

struct HeartRateSample: Codable {
    let minimumBpm: Double
    let averageBpm: Double
    let maximumBpm: Double
    let startDate: Date
    let endDate: Date
}
