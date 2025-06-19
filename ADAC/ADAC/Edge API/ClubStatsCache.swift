// Licensed under the Any Distance Source-Available License
//
//  ClubStatsCache.swift
//  ADAC
//
//  Created by Daniel Kuntz on 4/24/23.
//

import Foundation
import Cache
import Combine

class ClubStatsCache: NSObject, ObservableObject {

    static let shared = ClubStatsCache()

    private var internalCache: Storage<Date, ClubStatsData>? // startDate, stats data

    override init() {
        let memoryConfig = MemoryConfig(expiry: .never,
                                        countLimit: 500,
                                        totalCostLimit: 10)

        internalCache = try? Storage<Date, ClubStatsData>(
            diskConfig: DiskConfig(name: "com.anydistance.ClubStatsCache"),
            memoryConfig: memoryConfig,
            transformer: TransformerFactory.forCodable(ofType: ClubStatsData.self)
        )
    }

    func cache(clubStats: ClubStatsData, for date: Date) {
        try? internalCache?.setObject(clubStats, forKey: date)
    }

    func clubStatsData(for date: Date) -> ClubStatsData? {
        try? internalCache?.object(forKey: date)
    }
}
