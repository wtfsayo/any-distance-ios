// Licensed under the Any Distance Source-Available License
//
//  HeartRateSampleAggregator.swift
//  Any Distance WatchKit Extension
//
//  Created by Daniel Kuntz on 10/12/22.
//

import Foundation

struct HeartRateSampleAggregator {
    static func aggregateRawSamples(_ rawSamples: [HeartRateRawSample]) -> [HeartRateSample] {
        guard !rawSamples.isEmpty else {
            return []
        }

        let interval: TimeInterval = 30
        let startOffset: TimeInterval = -60 * 11
        let mostRecentDate = Date(timeIntervalSince1970: Double(30 * Int((Date().timeIntervalSince1970 / 30).rounded())))
        var samples: [HeartRateSample] = []

        for offset in stride(from: startOffset, to: 0, by: interval) {
            let startDate = mostRecentDate.addingTimeInterval(offset)
            let endDate = mostRecentDate.addingTimeInterval(offset + interval)
            let rawSamplesInDateRange = rawSamples.filter { $0.date >= startDate && $0.date <= endDate }
            if rawSamplesInDateRange.isEmpty {
                continue
            }

            let bpms = rawSamplesInDateRange.map { $0.bpm }
            let minBpm = bpms.min()!
            let maxBpm = bpms.max()!
            let avgBpm = bpms.reduce(0.0, +) / Double(bpms.count)
            let sample =  HeartRateSample(minimumBpm: minBpm,
                                          averageBpm: avgBpm,
                                          maximumBpm: maxBpm,
                                          startDate: startDate,
                                          endDate: endDate)
            samples.append(sample)
        }

        print(samples.map { "\($0.startDate) - \($0.averageBpm)" })
        return samples
    }
}
