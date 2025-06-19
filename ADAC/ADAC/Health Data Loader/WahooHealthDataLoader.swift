// Licensed under the Any Distance Source-Available License
//
//  WahooHealthDataLoader.swift
//  ADAC
//
//  Created by Jarod Luebbert on 4/20/22.
//

import Foundation
import CoreLocation
import FitFileParser
import OAuthSwift

class WahooHealthDataLoader: HealthDataLoader {
    
    func coordinates(for activity: Activity) async throws -> [CLLocation] {
        guard let wahooActivity = activity as? WahooActivity else {
            throw HealthDataLoaderError.typeMismatch
        }
        
        var summary = wahooActivity.summary
        
        if summary == nil {
            summary = try await WahooActivitiesStore.shared.summary(for: wahooActivity)
        }
        
        guard let url = summary?.fitFileURL else {
            return []
        }
        
        let (localURL, _) = try await URLSession.shared.download(from: url)
        
        guard let fitFile = FitFile(file: localURL) else { return [] }

        let messages = fitFile.messages(forMessageType: .record)
        let coordinates: [CLLocation] = messages.map { message in
            if let one_gps = message.interpretedValue(key: "position") {
                if case let FitValue.coordinate(coord) = one_gps {
                    return CLLocation(latitude: coord.latitude, longitude: coord.longitude)
                }
            }
            return nil
        }.compactMap { $0 }
        
        return coordinates
    }
    
    // TODO: Add Wahoo heart rate data and step counts
    func heartRateSamples(for activity: Activity) async throws -> [HeartRateSample] {
        return []
    }
    
    func stepCounts(for activity: Activity) async -> [Int]? {
        return []
    }
    
    func distance(for date: Date) async throws -> Float? {
        return nil
    }
    
    func splits(for activity: Activity, unit: DistanceUnit) async throws -> [Split] {
        return []
    }
    
}
