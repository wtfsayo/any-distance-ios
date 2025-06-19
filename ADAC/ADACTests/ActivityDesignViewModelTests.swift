// Licensed under the Any Distance Source-Available License
//
//  ActivityDesignViewModelTests.swift
//  ADACTests
//
//  Created by Jarod Luebbert on 9/16/22.
//

import XCTest
import Combine

@testable import ADAC

final class ActivityDesignViewModelTests: XCTestCase {
    
    private var disposables = Set<AnyCancellable>()

    func testLoadMedia() throws {
        let activity = MockActivity(activityType: .run,
                                    distance: 5.0,
                                    movingTime: 30.0 * 60.0,
                                    startDate: Date(),
                                    startDateLocal: Date(),
                                    endDate: Date(),
                                    endDateLocal: Date(),
                                    coordinates: [],
                                    activeCalories: 100.0,
                                    paceInUserSelectedUnit: 0.0,
                                    totalElevationGain: 5.0,
                                    distanceInUserSelectedUnit: 5.0,
                                    stepCount: nil)
        let design = ActivityDesign(for: activity)
        
        XCTAssertNoThrow(try ActivityDesignStore.shared.save(design: design, for: activity))
        
        let viewModel = ActivityDesignViewModel(activity: activity)
        
        let testImage = UIImage(named: "ActivityDesignImage",
                                in: Bundle(for: type(of: self)),
                                with: nil)!

        viewModel.save(image: testImage)
        
        let loadedPhotoExpectation = expectation(description: "Loaded Photo")
        viewModel.mediaPublisher
            .sink { asset, image in
                XCTAssertNotNil(image)
                loadedPhotoExpectation.fulfill()
            }
            .store(in: &disposables)
        
        let changedPalettes = expectation(description: "Changed Palettes")
        viewModel.palettes
            .sink { palettes in
                XCTAssertNotEqual(Palette.defaultPalettes, palettes)
                changedPalettes.fulfill()
            }
            .store(in: &disposables)
        
        let changedImageForFilters = expectation(description: "Changed Image For Filters")
        viewModel.imageForFilters
            .sink { _ in
                changedImageForFilters.fulfill()
            }
            .store(in: &disposables)
        
        let mediaTypeChanged = expectation(description: "Media Type Changed")
        viewModel.designPublishable.media
            .sink { media in
                XCTAssert(media == .photo)
                mediaTypeChanged.fulfill()
            }
            .store(in: &disposables)
        
        Task {
            await viewModel.loadMedia()
        }
        
        waitForExpectations(timeout: 5.0)
        
        disposables.removeAll()
        
        let videoURL = Bundle(for: type(of: self)).url(forResource: "Test", withExtension: "mp4")
        XCTAssertNotNil(videoURL, "Video URL not found")
        
        let videoSavedExpectation = expectation(description: "Video Saved")
        viewModel.mediaPublisher
            .sink { asset, image in
                XCTAssertNotNil(asset)
                XCTAssertNil(image)
                videoSavedExpectation.fulfill()
            }
            .store(in: &disposables)
        
        viewModel.saveVideo(from: videoURL!)
        
        waitForExpectations(timeout: 5.0)
    }

    func testAddingVideoChangesPalette() throws {
        let activity = MockActivity(activityType: .run,
                                    distance: 5.0,
                                    movingTime: 30.0 * 60.0,
                                    startDate: Date(),
                                    startDateLocal: Date(),
                                    endDate: Date(),
                                    endDateLocal: Date(),
                                    coordinates: [],
                                    activeCalories: 100.0,
                                    paceInUserSelectedUnit: 0.0,
                                    totalElevationGain: 5.0,
                                    distanceInUserSelectedUnit: 5.0,
                                    stepCount: nil)
        let design = ActivityDesign(for: activity)
        
        XCTAssertNoThrow(try ActivityDesignStore.shared.save(design: design, for: activity))
        
        let viewModel = ActivityDesignViewModel(activity: activity)
        
        let videoURL = Bundle(for: type(of: self)).url(forResource: "Test", withExtension: "mp4")
        XCTAssertNotNil(videoURL, "Video URL not found")
        
        let videoSavedExpectation = expectation(description: "Video Saved")
        viewModel.mediaPublisher
            .sink { asset, image in
                XCTAssertNotNil(asset)
                XCTAssertNil(image)
                videoSavedExpectation.fulfill()
            }
            .store(in: &disposables)
        
        let changedPalettes = expectation(description: "Changed Palettes")
        viewModel.palettes
            .sink { palettes in
                XCTAssertNotEqual(Palette.defaultPalettes, palettes)
                changedPalettes.fulfill()
            }
            .store(in: &disposables)

        let mediaTypeChanged = expectation(description: "Media Type Changed")
        viewModel.designPublishable.media
            .dropFirst()
            .sink { media in
                XCTAssert(media == .video)
                mediaTypeChanged.fulfill()
            }
            .store(in: &disposables)
        
        viewModel.saveVideo(from: videoURL!)
                
        waitForExpectations(timeout: 10.0)
    }
    
    func testChangingMediaResetsOffsetAndZoom() throws {
        let activity = MockActivity(activityType: .run,
                                    distance: 5.0,
                                    movingTime: 30.0 * 60.0,
                                    startDate: Date(),
                                    startDateLocal: Date(),
                                    endDate: Date(),
                                    endDateLocal: Date(),
                                    coordinates: [],
                                    activeCalories: 100.0,
                                    paceInUserSelectedUnit: 0.0,
                                    totalElevationGain: 5.0,
                                    distanceInUserSelectedUnit: 5.0,
                                    stepCount: nil)
        let design = ActivityDesign(for: activity)
        
        XCTAssertNoThrow(try ActivityDesignStore.shared.save(design: design, for: activity))
        
        let viewModel = ActivityDesignViewModel(activity: activity)
        
        let testImage = UIImage(named: "ActivityDesignImage",
                                in: Bundle(for: type(of: self)),
                                with: nil)!
        
        let loadedPhotoExpectation = expectation(description: "Loaded Photo")
        viewModel.mediaPublisher
            .sink { asset, image in
                XCTAssertNotNil(image)
                loadedPhotoExpectation.fulfill()
            }
            .store(in: &disposables)
                
        viewModel.save(image: testImage)
        viewModel.set(photoOffset: .init(x: 100.0, y: 100.0))
        viewModel.set(photoZoom: 5.0)

        waitForExpectations(timeout: 5.0)
        
        disposables.removeAll()
        
        let changedFillExpectation = expectation(description: "Changed Fill")
        viewModel.designPublishable.fill
            .dropFirst()
            .sink { fill in
                XCTAssertEqual(fill, .being)
                changedFillExpectation.fulfill()
            }
            .store(in: &disposables)

        let resetPhotoOffset = expectation(description: "Reset Photo Offset")
        viewModel.designPublishable.photoOffset
            .dropFirst()
            .sink { offset in
                XCTAssertEqual(offset, .zero)
                resetPhotoOffset.fulfill()
            }
            .store(in: &disposables)
        
        let resetPhotoZoom = expectation(description: "Reset Photo Zoom")
        viewModel.designPublishable.photoZoom
            .dropFirst()
            .sink { photoZoom in
                XCTAssertEqual(photoZoom, 1.0)
                resetPhotoZoom.fulfill()
            }
            .store(in: &disposables)
        
        viewModel.set(fill: .being)
        
        waitForExpectations(timeout: 5.0)
    }
    
    func testChangingGraphType() throws {
        let activity = MockActivity(activityType: .run,
                                    distance: 5.0,
                                    movingTime: 30.0 * 60.0,
                                    startDate: Date(),
                                    startDateLocal: Date(),
                                    endDate: Date(),
                                    endDateLocal: Date(),
                                    coordinates: [],
                                    activeCalories: 100.0,
                                    paceInUserSelectedUnit: 0.0,
                                    totalElevationGain: 5.0,
                                    distanceInUserSelectedUnit: 5.0,
                                    stepCount: nil)
        let design = ActivityDesign(for: activity)
        
        XCTAssertNoThrow(try ActivityDesignStore.shared.save(design: design, for: activity))
        
        let viewModel = ActivityDesignViewModel(activity: activity)

        viewModel.set(graphType: .heartRate)
        let transform: CGAffineTransform = .identity.translatedBy(x: 100.0, y: 100.0)
        viewModel.set(graphTransform: transform)
        
        let changedGraphType = expectation(description: "Changed Graph Type")
        viewModel.designPublishable.graphType
            .sink { graphType in
                XCTAssertEqual(graphType, .heartRate)
                changedGraphType.fulfill()
            }
            .store(in: &disposables)
        
        let movedGraph = expectation(description: "Moved Graph")
        viewModel.designPublishable.graphTransform
            .sink { graphTransform in
                XCTAssertEqual(graphTransform, transform)
                movedGraph.fulfill()
            }
            .store(in: &disposables)

        waitForExpectations(timeout: 2.0)
        
        disposables.removeAll()
        
        viewModel.set(graphType: .none)
        
        let resetGraphType = expectation(description: "Reset Graph Type")
        viewModel.designPublishable.graphType
            .sink { graphType in
                XCTAssertEqual(graphType, .none)
                resetGraphType.fulfill()
            }
            .store(in: &disposables)
        
        let resetGraphTransform = expectation(description: "Reset Graph Transform")
        viewModel.designPublishable.graphTransform
            .sink { graphTransform in
                XCTAssertEqual(graphTransform, .identity)
                resetGraphTransform.fulfill()
            }
            .store(in: &disposables)

        waitForExpectations(timeout: 2.0)
    }

}
