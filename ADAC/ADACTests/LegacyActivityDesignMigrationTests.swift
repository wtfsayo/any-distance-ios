// Licensed under the Any Distance Source-Available License
//
//  LegacyActivityDesignMigrationTests.swift
//  ADACTests
//
//  Created by Jarod Luebbert on 5/2/22.
//

import XCTest

@testable import ADAC

fileprivate extension LegacyActivityDesignCache {
    
    static func createDesign(forActivityId id: Int, isStepCount: Bool = false) -> LegacyActivityDesign? {
        var design: LegacyActivityDesign? = nil
        
        if let activity = LegacyActivityCache.activity(withId: id) {
            design = LegacyActivityDesign(activityId: id,
                                           isStepCountDesign: isStepCount,
                                           stepCountEnabled: false,
                                           elevationEnabled: (activity.elevationGainInUserSelectedUnit ?? 0) <= 400,
                                           activeCalEnabled: (activity.distanceInUserSelectedUnit ?? 0) <= 0.1)

        } else {
            design = LegacyActivityDesign(activityId: id,
                                           isStepCountDesign: isStepCount,
                                           stepCountEnabled: true,
                                           elevationEnabled: false,
                                           activeCalEnabled: false)
        }
        
        if let design = design {
            cacheDesign(design)
        }

        return design
    }
    
    private static func cacheDesign(_ design: LegacyActivityDesign) {
        do {
            let documentsDirectory = try FileManager.default.url(for: .documentDirectory,
                                                                 in: .userDomainMask,
                                                                 appropriateFor: nil,
                                                                 create: true)
            let cacheFileName = "\(design.activityId)\(LegacyActivityDesign.cacheFileSuffix)"
            let fileUrl: URL = documentsDirectory.appendingPathComponent(cacheFileName)
            try JSONEncoder().encode(design).write(to: fileUrl)
        } catch {
            print(error)
        }
    }
    
    static func writePhoto(_ image: UIImage?, fileName: String) {
        do {
            let documentsDirectory = try FileManager.default.url(for: .documentDirectory,
                                                                 in: .userDomainMask,
                                                                 appropriateFor: nil,
                                                                 create: true)
            let url = documentsDirectory.appendingPathComponent(fileName)
            if let data = image?.jpegData(compressionQuality: 1) {
                try data.write(to: url)
            } else {
                try FileManager.default.removeItem(at: url)
            }
        } catch {
            print(error)
        }
    }
}

class LegacyActivityDesignMigrationTests: XCTestCase {

    override func setUpWithError() throws {
        NSUbiquitousKeyValueStore.default.removeObject(forKey: "hasMigratedLegacyActivityDesigns")
    }

    override func tearDownWithError() throws {
        // delete cached files for a fresh start
        let fileManager = FileManager.default
        let documentsDirectory = try fileManager.url(for: .documentDirectory,
                                                     in: .userDomainMask,
                                                     appropriateFor: nil,
                                                     create: true)
        let filePaths = try fileManager.contentsOfDirectory(at: documentsDirectory,
                                                            includingPropertiesForKeys: nil)
        let filesToDelete = [
            LegacyActivityDesign.cacheFileSuffix,
            LegacyStepCountCache.cacheFileSuffix,
            LegacyActivity.appleHealthCacheFileSuffix,
            ActivityDesignStore.shared.filename,
            ActivitiesData.activitiesWithGoalMetFilename,
        ]
        
        for path in filePaths {
            if filesToDelete.map({ path.absoluteString.contains($0) }).contains(true) {
                try fileManager.removeItemIfExists(at: path)
            }
        }
    }
    
    func testMigratesGoalMetDateFromActivity() async throws {
        // create legacy activity/design
        let legacyActivity = LegacyActivity(id: 1)
        legacyActivity.distance = 5.0
        legacyActivity.totalElevationGain = 1000.0
        legacyActivity.goalMetDate = Date()
        LegacyActivityCache.cacheActivity(legacyActivity)
        
        // migrate
        let migrator = LegacyActivityDesignMigrator()
        try await migrator.migrateActivityDesigns()
        
        // fetch migrated design
        let activity = LegacyActivityWrapper(from: legacyActivity)
        XCTAssertTrue(ActivitiesData.shared.goalMet(for: activity), "Migrated goal met date")
    }

    func testMigratesLegacyActivityDesign() async throws {
        // create legacy activity/design
        let legacyActivity = LegacyActivity(id: 1)
        legacyActivity.distance = 5.0
        legacyActivity.totalElevationGain = 1000.0
        LegacyActivityCache.cacheActivity(legacyActivity)
        let legacyDesign = LegacyActivityDesignCache.createDesign(forActivityId: legacyActivity.id)
        XCTAssertNotNil(legacyDesign, "Saved legacy activity design")
        
        // load test image and save
        let testImage = UIImage(named: "ActivityDesignImage", in: Bundle(for: type(of: self)), with: nil)
        LegacyActivityDesignCache.writePhoto(testImage, fileName: legacyDesign!.photoFileName)
        
        // migrate
        let migrator = LegacyActivityDesignMigrator()
        try await migrator.migrateActivityDesigns()

        // fetch migrated design
        let activity = LegacyActivityWrapper(from: legacyActivity)
        let design = ActivityDesignStore.shared.design(for: activity)
        XCTAssertNotNil(design, "Migrated design from legacy design")
        
        // test migrated filename
        XCTAssertNotNil(design.legacyPhotoFilename, "Set legacy photo filename for migrated design")
        
        // test loading images at all sizes
        for size in ActivityDesign.PhotoSize.allCases {
            let image = await design.photo(with: size)
            XCTAssertNotNil(image, "Loaded image for migrated design")
        }
    }
    
    func testMigratesLegacyDailyStepCountDesign() async throws {
        // create step count/design
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -1, to: endDate)!
        let dailyStepCount = DailyStepCount(startDate: startDate, endDate: endDate, timezone: Calendar.current.timeZone, count: 500)
        LegacyStepCountCache.cacheStepCount(dailyStepCount)
        let legacyDesign = LegacyActivityDesignCache.createDesign(forActivityId: dailyStepCount.legacyId,
                                                            isStepCount: true)
        XCTAssertNotNil(legacyDesign)
        
        let testImage = UIImage(named: "ActivityDesignImage", in: Bundle(for: type(of: self)), with: nil)
        LegacyActivityDesignCache.writePhoto(testImage, fileName: legacyDesign!.photoFileName)
        
        // migrate
        let migrator = LegacyActivityDesignMigrator()
        try await migrator.migrateActivityDesigns()

        // fetch migrated design
        let design = ActivityDesignStore.shared.design(for: dailyStepCount)
        XCTAssertNotNil(design)
        
        // test migrated filename
        XCTAssertNotNil(design.legacyPhotoFilename, "Set legacy photo filename for migrated design")
        
        // test loading images at all sizes
        for size in ActivityDesign.PhotoSize.allCases {
            let image = await design.photo(with: size)
            XCTAssertNotNil(image, "Loaded image for migrated design")
        }
    }

}
