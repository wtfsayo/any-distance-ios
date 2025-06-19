// Licensed under the Any Distance Source-Available License
//
//  LegacyStepCountCache.swift
//  ADAC
//
//  Created by Daniel Kuntz on 4/9/21.
//

import Foundation

final class LegacyStepCountCache {
    
    private static var dailyStepCounts: [DailyStepCount] = []
    
    private static func cacheFileName(for stepCount: DailyStepCount) -> String {
        return String(Int(stepCount.startDate.timeIntervalSince1970)) + cacheFileSuffix
    }

    static var cacheFileSuffix: String {
        return "_steps_daily.json"
    }

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

            let stepCountFilePaths = filePaths.filter { $0.contains(cacheFileSuffix) }
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

        dailyStepCounts.sort(by: { $0.startDate > $1.startDate })

        return dailyStepCounts
    }

    // MARK: - Write

    // Used for testing only
    static func cacheStepCount(_ stepCount: DailyStepCount) {
        dailyStepCounts.append(stepCount)

        do {
            let documentsDirectory = try FileManager.default.url(for: .documentDirectory,
                                                                    in: .userDomainMask,
                                                                    appropriateFor: nil,
                                                                    create: true)
            let fileUrl: URL = documentsDirectory.appendingPathComponent(cacheFileName(for: stepCount))
            try JSONEncoder().encode(stepCount).write(to: fileUrl)
        } catch {
            print(error)
        }
    }

}


