// Licensed under the Any Distance Source-Available License
//
//  Activity+DebugData.swift
//  ADAC
//
//  Created by Daniel Kuntz on 8/25/22.
//

import Foundation
import HealthKit

extension Activity {
    var debugData: String {
        get async {
            var string = ""
            string.append(id, forKey: "id")
            string.append(activityType.rawValue, forKey: "activityType")
            string.append(String(distance), forKey: "distance")
            string.append(String(movingTime), forKey: "movingTime")
            string.append(startDate.description, forKey: "startDate")
            string.append(startDateLocal.description, forKey: "startDateLocal")
            string.append(endDate.description, forKey: "endDate")
            string.append(endDateLocal.description, forKey: "endDateLocal")
            
            do {
                let splits = try await splits
                let encodedSplits = try JSONEncoder().encode(splits)
                let splitsString = String(data: encodedSplits, encoding: .utf8) ?? "nil"
                string.append(splitsString, forKey: "splits")
            } catch {
                string.append(error.localizedDescription, forKey: "splits")
            }

            do {
                let heartRateSamples = try await heartRateSamples
                let encodedHeartRateSamples = try JSONEncoder().encode(heartRateSamples)
                let heartRateSamplesString = String(data: encodedHeartRateSamples, encoding: .utf8) ?? "nil"
                string.append(heartRateSamplesString, forKey: "heartRateData")
            } catch {
                string.append(error.localizedDescription, forKey: "heartRateData")
            }

            string.append(String(stepCount ?? 0), forKey: "stepCount")
            string.append(workoutSource?.rawValue ?? "nil", forKey: "workoutSource")
            string.append(String(clipsRoute), forKey: "clipsRoute")
            string.append(String(activeCalories), forKey: "activeCalories")
            string.append(String(totalElevationGain), forKey: "totalElevationGain")

            if let hkWorkout = self as? HKWorkout {
                string.append(String(hkWorkout.hasHKIndoorWorkoutMetadataKey), forKey: "hasHKIndoorWorkoutMetadataKey")
                string.append(hkWorkout.device?.model ?? "", forKey: "deviceModel")
                string.append(hkWorkout.metadata?.debugDescription ?? "nil", forKey: "metadata")

                let events = hkWorkout.workoutEvents?.map({ $0.debugDescription }).joined(separator: "\n")
                string.append(events ?? "nil", forKey: "workoutEvents")
            }

            string.append("\n\n\n")
            
            do {
                let coords = try await coordinates
                let coordinatesString = coords.map({ $0.description })
                    .joined(separator: "\n")
                string.append(coordinatesString, forKey: "coordinates")
            } catch {
                string.append(error.localizedDescription, forKey: "coordinates")
            }

            return string
        }

    }
}

fileprivate extension String {
    mutating func append(_ value: String, forKey key: String) {
        self.append("\(key) = \(value)\n")
    }
}
