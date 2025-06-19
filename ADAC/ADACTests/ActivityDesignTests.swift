// Licensed under the Any Distance Source-Available License
//
//  ActivityDesignTests.swift
//  ADACTests
//
//  Created by Jarod Luebbert on 5/3/22.
//

import XCTest

@testable import ADAC

class ActivityDesignTests: XCTestCase {

    func testAddingPhotoToDesign() async throws {
        // load test image and save
        let testImage = UIImage(named: "ActivityDesignImage", in: Bundle(for: type(of: self)), with: nil)
        XCTAssertNotNil(testImage, "Loaded test image")
        var design = ActivityDesign(isStepCount: false)
        await design.save(photo: testImage!)
        let image = await design.photo
        XCTAssertNotNil(image, "Loaded image for design")
        
        design.photoFilter = .film_bw3
        let filteredImage = await design.photoWithFilter
        XCTAssertNotNil(filteredImage, "Loaded filtered image for design")
        
        design.photoFilter = .none
        let nilImage = await design.photoWithFilter
        XCTAssertNil(nilImage, "Returned nil image for design with no filter")
    }

}
