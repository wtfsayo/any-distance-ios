// Licensed under the Any Distance Source-Available License
//
//  StepCountCache.swift
//  ADAC
//
//  Created by Daniel Kuntz on 4/9/21.
//

import Foundation

final class StepCountCache {
    private static var dailyStepCounts: [DailyStepCount] = []

    // MARK: - Read

    static func allDailyStepCounts() -> [DailyStepCount] {
        if !dailyStepCounts.isEmpty {
            return dailyStepCounts
        }

        do {
            let documentsDirectory = try FileManager.default.url(for: .documentDirectory,
                                                                 in: .userDomainMask,
                                                                 appropriateFor: nil,
                                                                 create: true)

            let enumerator = FileManager.default.enumerator(atPath: documentsDirectory.path)
            let filePaths = enumerator?.allObjects as! [String]

            let stepCountFilePaths = filePaths.filter { $0.contains(DailyStepCount.cacheFileSuffix) }
            for path in stepCountFilePaths {
                let url = documentsDirectory.appendingPathComponent(path)

                do {
                    let stepCount = try JSONDecoder().decode(DailyStepCount.self,
                                                             from: Data(contentsOf: url))
                    dailyStepCounts.append(stepCount)
                } catch {
                    print(error)
                }
            }
        } catch {
            print(error)
        }

        dailyStepCounts.sort(by: { $0.date > $1.date })

        return dailyStepCounts
    }

    static func stepCountDistanceMeters(forGoal goal: Goal) -> Float {
        guard goal.activityType == .walk else {
            return 0
        }

        var stepCountDistanceMeters: Float = 0
        let latestStepCounts = dailyStepCounts.filter {
            $0.dateInLocalTimeZone >= goal.startDate &&
            $0.dateInLocalTimeZone < goal.endDate
        }

        for stepCount in latestStepCounts {
            stepCountDistanceMeters += stepCount.distanceMeters ?? 0
        }

        return stepCountDistanceMeters
    }

    // MARK: - Write

    @MainActor
    static func cacheStepCount(_ stepCount: DailyStepCount) {
        func writeJson(_ stepCount: DailyStepCount) {
            do {
                let documentsDirectory = try FileManager.default.url(for: .documentDirectory,
                                                                        in: .userDomainMask,
                                                                        appropriateFor: nil,
                                                                        create: true)
                let fileUrl: URL = documentsDirectory.appendingPathComponent(stepCount.cacheFileName)
                try JSONEncoder().encode(stepCount).write(to: fileUrl)
            } catch {
                print(error)
            }
        }

        let idx = dailyStepCounts.firstIndex { existingStepCount in
            return existingStepCount.date.convertFromTimeZone(stepCount.timezone,
                                                              toTimeZone: existingStepCount.timezone) == stepCount.date
        }

        if let idx = idx {
            dailyStepCounts[idx].count = stepCount.count
            dailyStepCounts[idx].distanceMeters = stepCount.distanceMeters
            dailyStepCounts[idx].graphImage = nil
            if dailyStepCounts[idx].timezoneId == nil {
                dailyStepCounts[idx].timezoneId = stepCount.timezoneId
            }

            writeJson(dailyStepCounts[idx])
            return
        }

        if let idx = dailyStepCounts.firstIndex(where: { $0.dateInLocalTimeZone < stepCount.dateInLocalTimeZone }) {
            dailyStepCounts.insert(stepCount, at: idx)
        } else {
            dailyStepCounts.append(stepCount)
        }

        writeJson(stepCount)
    }

    static func stepCount(forDate date: Date) -> DailyStepCount? {
        return dailyStepCounts.first(where: { $0.date == date })
    }
}


