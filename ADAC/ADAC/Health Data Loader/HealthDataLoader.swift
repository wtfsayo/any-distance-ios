// Licensed under the Any Distance Source-Available License
//
//  CoordinatesLoader.swift
//  ADAC
//
//  Created by Jarod Luebbert on 4/20/22.
//

import Foundation
import CoreLocation
import HealthKit

enum HealthDataLoaderError: Error {
    case typeMismatch
    case missingLoaderForActivityType
    case noSplits
}

protocol HealthDataLoader {
    
    func coordinates(for activity: Activity) async throws -> [CLLocation]
    
    func heartRateSamples(for activity: Activity) async throws -> [HeartRateSample]
    
    func stepCounts(for activity: Activity) async -> [Int]?
    
    func distance(for date: Date) async throws -> Float?
    
    func splits(for activity: Activity, unit: DistanceUnit) async throws -> [Split]
    
}

// MARK: - Activity

extension Activity {
    
    var loader: HealthDataLoader {
        get throws {
            return try HealthDataLoaderFactory.loader(for: self)
        }
    }
    
    var coordinates: [CLLocation] {
        get async throws {
            if let coordinates = HealthDataCache.shared.coordinates(for: self),
               !coordinates.isEmpty {
                if clipsRoute {
                    return try loader.coordinates(byClipping: coordinates)
                }
                return coordinates
            }
            
            let coordinates = try await loader.coordinates(for: self)
            let coordinatesWithElevations = try await loader.coordinatesWithElevations(coordinates)
            
            HealthDataCache.shared.cache(coordinates: coordinatesWithElevations, for: self)
            
            if clipsRoute {
                return try loader.coordinates(byClipping: coordinatesWithElevations)
            }
            return coordinatesWithElevations
        }
    }

    var unclippedCoordinates: [CLLocation] {
        get async throws {
            if let coordinates = HealthDataCache.shared.coordinates(for: self),
               !coordinates.isEmpty {
                return coordinates
            }

            let coordinates = try await loader.coordinates(for: self)
            let coordinatesWithElevations = try await loader.coordinatesWithElevations(coordinates)

            HealthDataCache.shared.cache(coordinates: coordinatesWithElevations, for: self)
            return coordinatesWithElevations
        }
    }

    var nonDistanceBasedCoordinate: CLLocation? {
        get {
            guard !activityType.showsRoute,
                  let hkWorkout = self as? HKWorkout,
                  let coordinateString = hkWorkout.metadata?[ADMetadataKey.nonDistanceBasedCoordinate] as? String,
                  let coordinateData = coordinateString.data(using: .utf8),
                  let wrappedCoordinate = try? JSONDecoder().decode(LocationWrapper.self, from: coordinateData),
                  let coordinate = CLLocation(wrapper: wrappedCoordinate) else {
                return nil
            }

            return coordinate
        }
    }
    
    var heartRateSamples: [HeartRateSample] {
        get async throws {
            if let heartRateSamples = HealthDataCache.shared.heartRateData(for: self),
               !heartRateSamples.isEmpty {
                return heartRateSamples
            }

            let heartRateSamples = try await loader.heartRateSamples(for: self)
            HealthDataCache.shared.cache(heartRateData: heartRateSamples, for: self)
            return heartRateSamples
        }
    }
    
    var hasHeartRateSamples: Bool {
        get async {
            if let samples = try? await heartRateSamples {
                return Double(samples.count) >= floor(HeartRateGraph.numberOfSamplesRequired)
            }
            return false
        }
    }
    
    var cityAndState: String? {
        get async throws {
            var coordinate: CLLocation? {
                get async throws {
                    if activityType.isDistanceBased {
                        let coordinates = try await coordinates
                        return coordinates.first
                    } else {
                        return nonDistanceBasedCoordinate
                    }
                }
            }

            guard let coordinate = try await coordinate else {
                return nil
            }
            
            let cityAndState: String? = try await withCheckedThrowingContinuation { continuation in
                let geocoder = CLGeocoder()
                geocoder.reverseGeocodeLocation(coordinate, 
                                                preferredLocale: Locale(identifier: "en_US")) { (placemarks, error) in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let firstLocation = placemarks?[0],
                              let city = firstLocation.locality,
                              let state = firstLocation.administrativeArea {
                        continuation.resume(returning: city.uppercased() + ", " + state.uppercased())
                    } else {
                        continuation.resume(returning: nil)
                    }
                }
            }
            
            return cityAndState
        }
    }
    
    var stepCounts: [Int]? {
        get async {
            guard let stepCount = self as? DailyStepCount else {
                return nil
            }

            // Decide whether to load new 30-minute counts based on whether the total step count
            // for this day has changed.
            let currentCount = stepCount.count
            let cachedCount = HealthDataCache.shared.stepCountTotal(for: self)

            func loadNewCounts() async -> [Int]? {
                let stepCounts = try? await loader.stepCounts(for: self)

                if let stepCounts = stepCounts {
                    HealthDataCache.shared.cache(stepCounts: stepCounts, for: self)
                }

                return stepCounts
            }

            if let cachedCount = cachedCount {
                if currentCount != cachedCount {
                    HealthDataCache.shared.cache(stepCountTotal: currentCount, for: self)
                    return await loadNewCounts()
                }
            } else {
                HealthDataCache.shared.cache(stepCountTotal: currentCount, for: self)
                return await loadNewCounts()
            }

            if let stepCounts = HealthDataCache.shared.stepCounts(for: self) {
                return stepCounts
            }
            
            return await loadNewCounts()
        }
    }
    
    var splits: [Split] {
        get async {
            if let splits = HealthDataCache.shared.splits(for: self) {
                return splits
            }
            
            guard let splits = try? await loader.splits(for: self,
                                                        unit: ADUser.current.distanceUnit) else {
                return []
            }
            
            HealthDataCache.shared.cache(splits: splits, for: self)
            
            return splits
        }
    }
    
}

// MARK: - Factory

fileprivate class HealthDataLoaderFactory {
    
    static func loader(for activity: Activity) throws -> HealthDataLoader {
        switch activity {
        case _ as HKWorkout:
            return HealthKitHealthDataLoader()
        case _ as WahooActivity:
            return WahooHealthDataLoader()
        case _ as GarminActivity:
            return GarminHealthDataLoader()
        case _ as DailyStepCount:
            return HealthKitDailyStepsDataLoader()
        default:
            throw HealthDataLoaderError.missingLoaderForActivityType
        }
    }
    
}

// MARK: - Elevation Data

extension HealthDataLoader {
    
    fileprivate func coordinatesWithElevations(_ coordinates: [CLLocation]) async -> [CLLocation] {
        guard !coordinates.isEmpty,
              coordinates.first(where: { $0.altitude != 0.0 }) == nil else {
            return coordinates
        }
        
        let coordinates: [CLLocation] = await withCheckedContinuation { continuation in
            GoogleElevationAPI.fetchElevationsForRoute(withCoordinates: coordinates) { elevationData in
                let coordinatesWithElevations = self.coordinates(from: coordinates,
                                                                 with: elevationData)
                continuation.resume(returning: coordinatesWithElevations)
            }
        }
        
        return coordinates
    }
    
    private func coordinates(from coordinates: [CLLocation], with elevationData: [Float]) -> [CLLocation] {
        guard !elevationData.isEmpty, !coordinates.isEmpty else {
            return coordinates
        }
        
        var newCoords: [CLLocation] = []
        if elevationData.count == coordinates.count {
            for i in 0..<coordinates.count {
                let newCoord = CLLocation(coordinate: coordinates[i].coordinate,
                                          altitude: CLLocationDistance(elevationData[i]),
                                          horizontalAccuracy: coordinates[i].horizontalAccuracy,
                                          verticalAccuracy: coordinates[i].verticalAccuracy,
                                          timestamp: coordinates[i].timestamp)
                newCoords.append(newCoord)
            }
        } else {
            let dataStride = Float(elevationData.count - 1) / Float(coordinates.count - 1)
            for (i, coord) in coordinates.enumerated() {
                let dataLowerIdx = Int(Float(i) * dataStride).clamped(to: 0...(elevationData.count-1))
                let dataUpperIdx = Int(ceilf(Float(i) * dataStride)).clamped(to: 0...(elevationData.count-1))
                let p = (Float(i) * dataStride) - Float(dataLowerIdx)
                let altitude = (elevationData[dataLowerIdx] * p) + (elevationData[dataUpperIdx] * (1 - p))
                let newCoord = CLLocation(coordinate: coord.coordinate,
                                          altitude: CLLocationDistance(altitude),
                                          horizontalAccuracy: coord.horizontalAccuracy,
                                          verticalAccuracy: coord.verticalAccuracy,
                                          timestamp: coord.timestamp)
                newCoords.append(newCoord)
            }
        }
        
        return newCoords
    }
    
    fileprivate func coordinates(byClipping coordinates: [CLLocation]) -> [CLLocation] {
        let countToClip = Int(NSUbiquitousKeyValueStore.default.defaultRecordingSettings.routeClipPercentage * Double(coordinates.count))
        return Array(coordinates[countToClip..<coordinates.count-countToClip])
    }
}
