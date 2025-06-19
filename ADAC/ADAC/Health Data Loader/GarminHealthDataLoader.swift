// Licensed under the Any Distance Source-Available License
//
//  GarminHealthDataLoader.swift
//  ADAC
//
//  Created by Jarod Luebbert on 4/20/22.
//

import Foundation
import CoreLocation

fileprivate extension Double {
    var timeString: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .full
        return formatter.string(from: self)!
    }
}

fileprivate extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}

class GarminHealthDataLoader: HealthDataLoader {
    
    func coordinates(for activity: Activity) async throws -> [CLLocation] {
        guard let garminActivity = activity as? GarminActivity else {
            throw HealthDataLoaderError.typeMismatch
        }

        let coordinates = garminActivity.samples.compactMap { sample -> CLLocation? in
            guard let lat = sample.latD,
                  let long = sample.lonD else {
                return nil
            }

            if lat == 0.0 && long == 0.0 {
                return nil
            }
            
            if let elevation = sample.eM {
                let location2D = CLLocationCoordinate2D(latitude: lat, longitude: long)
                return CLLocation(coordinate: location2D,
                                  altitude: elevation,
                                  horizontalAccuracy: 0,
                                  verticalAccuracy: 0,
                                  timestamp: Date(timeIntervalSince1970: sample.sTS ?? 0.0))
            } else {
                return CLLocation(latitude: lat, longitude: long)
            }
        }
        
        return  coordinates
    }
    
    func heartRateSamples(for activity: Activity) async throws -> [HeartRateSample] {
        guard let garminActivity = activity as? GarminActivity else {
            throw HealthDataLoaderError.typeMismatch
        }
        
        let samplesWithHeartRate = garminActivity.samples.filter {
            $0.hR != nil
        }
        
        guard samplesWithHeartRate.count >= Int(HeartRateGraph.numberOfSamplesRequired) else {
            return []
        }
        
        let groupSize = samplesWithHeartRate.count / Int(HeartRateGraph.numberOfSamplesRequired)
        let groupedHeartRates = samplesWithHeartRate.chunked(into: groupSize)
        let samples = groupedHeartRates.compactMap { hrGroup -> HeartRateSample? in
            let heartRates = hrGroup.compactMap { $0.hR }
            guard let min = heartRates.min(),
                  let max = heartRates.max(),
                  let start = hrGroup.first?.sTS,
                  let end = hrGroup.last?.sTS,
                  let duration = hrGroup.last?.cDS else {
                return nil
            }
            
            let average = heartRates.reduce(0, +) / hrGroup.count
            return HeartRateSample(minimumBpm: Double(min),
                                   averageBpm: Double(average),
                                   maximumBpm: Double(max),
                                   startDate: Date(timeIntervalSince1970: start),
                                   endDate: Date(timeIntervalSince1970: end + Double(duration)))
        }

        return samples
    }
    
    func stepCounts(for activity: Activity) async -> [Int]? {
        guard let garminActivity = activity as? GarminActivity else {
            return nil
        }

        guard let stepCount = garminActivity.stepCount else { return nil }

        return [stepCount]
    }
    
    func distance(for date: Date) async throws -> Float? {
        return nil
    }
    
    func splits(for activity: Activity,
                unit: DistanceUnit = ADUser.current.distanceUnit) async throws -> [Split] {
        guard let garminActivity = activity as? GarminActivity else {
            throw HealthDataLoaderError.typeMismatch
        }
        
        guard let laps = garminActivity.laps, !laps.isEmpty else { return [] }

        var splits: [Split] = []
        let samples = garminActivity.samples
            .filter { $0.sTS != nil }
            .sorted(by: { $0.sTS! < $1.sTS! })
        var currentDuration: Double = 0.0
        var currentDistance: Double = 0.0

        for (i, lap) in laps.enumerated() {
            let nextLapStartTime: TimeInterval
            if i + 1 < laps.count {
                nextLapStartTime = laps[i + 1].startTimeInSeconds
            } else {
                nextLapStartTime = garminActivity.movingTime
            }
            
            guard let endSample = samples.last(where: { $0.sTS! < nextLapStartTime }) ?? samples.last,
                  let endTimerDuration = endSample.mDS,
                  let endDistance = endSample.tDM else {
                continue
            }
            
            let lapDuration = Double(endTimerDuration) - currentDuration
            let lapDistance = endDistance - currentDistance

            let split = Split(unit: .kilometers,
                              startDate: Date(timeIntervalSince1970: lap.startTimeInSeconds),
                              duration: lapDuration,
                              startDistanceMeters: currentDistance,
                              totalDistanceMeters: lapDistance,
                              isPartial: false)
            splits.append(split)
            
            currentDuration = Double(endTimerDuration)
            currentDistance = endDistance
        }

        guard !splits.isEmpty else {
            throw HealthDataLoaderError.noSplits
        }

        return splits
    }
}
