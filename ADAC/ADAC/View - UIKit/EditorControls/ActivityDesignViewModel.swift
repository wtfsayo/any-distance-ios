// Licensed under the Any Distance Source-Available License
//
//  ActivityDesignViewModel.swift
//  ADAC
//
//  Created by Jarod Luebbert on 7/25/22.
//

import Foundation
import Combine
import UIKit
import AVFoundation
import Sentry

class ActivityDesignPublishable {
    
    // MARK: Wrapper workaround
    
    /// this wrapper is needed to get around the initial values of `ActivityDesign` attributes
    /// not getting published if we just create a `PassthroughSubject`
    
    private class _Wrapper {
        @Published var design: ActivityDesign
        init(design: ActivityDesign) {
            self.design = design
        }
    }
    
    private let wrapper: _Wrapper
    
    var design: ActivityDesign {
        get {
            wrapper.design
        }
        set {
            wrapper.design = newValue
        }
    }
    
    var designPublisher: AnyPublisher<ActivityDesign, Never> {
        get {
            return wrapper.$design.eraseToAnyPublisher()
        }
    }
    
    ///
    ///

    // MARK: -
    
    let font: AnyPublisher<ADFont, Never>
    let fill: AnyPublisher<Fill?, Never>
    let alignment: AnyPublisher<StatisticAlignment, Never>
    let graphType: AnyPublisher<GraphType, Never>
    let statisticsOptions: AnyPublisher<Set<StatisticType>, Never>
    let photoZoom: AnyPublisher<Float, Never>
    let photoOffset: AnyPublisher<CGPoint, Never>
    let photoFilter: AnyPublisher<PhotoFilter, Never>
    let videoMode: AnyPublisher<VideoMode, Never>
    let graphTransform: AnyPublisher<CGAffineTransform, Never>
    let palette: AnyPublisher<Palette, Never>
    let cutoutShape: AnyPublisher<CutoutShape, Never>
    let media: AnyPublisher<ActivityDesign.Media, Never>
    
    fileprivate init(design: ActivityDesign) {
        self.wrapper = _Wrapper(design: design)
        self.font = wrapper.$design.map { $0.font }.removeDuplicatesAndErase()
        self.fill = wrapper.$design.map { $0.fill }.removeDuplicatesAndErase()
        self.alignment = wrapper.$design.map { $0.alignment }.removeDuplicatesAndErase()
        self.graphType = wrapper.$design.map { $0.graphType }.removeDuplicatesAndErase()
        self.statisticsOptions = wrapper.$design.map { $0.statisticsOptions }.removeDuplicatesAndErase()
        self.photoZoom = wrapper.$design.map { $0.photoZoom }.removeDuplicatesAndErase()
        self.photoOffset = wrapper.$design.map { $0.photoOffset }.removeDuplicatesAndErase()
        self.photoFilter = wrapper.$design.map { $0.photoFilter }.removeDuplicatesAndErase()
        self.videoMode = wrapper.$design.map { $0.videoMode }.removeDuplicatesAndErase()
        self.graphTransform = wrapper.$design.map { $0.graphTransform }.removeDuplicatesAndErase()
        self.palette = wrapper.$design.map { $0.palette }.removeDuplicatesAndErase()
        self.cutoutShape = wrapper.$design.map { $0.cutoutShape }.removeDuplicatesAndErase()
        self.media = wrapper.$design.map { $0.media }.removeDuplicatesAndErase()
    }
    
}

class ActivityDesignViewModel {
    
    let activity: Activity
    
    var design: ActivityDesign {
        get {
            designPublishable.design
        }
    }
    
    let designPublishable: ActivityDesignPublishable
        
    let changedStatistics: AnyPublisher<(ActivityDesign, Set<StatisticType>), Never>
    let graphImage: AnyPublisher<UIImage?, Never>
    
    let mediaPublisher: AnyPublisher<(asset: AVAsset?, image: UIImage?), Never>
    private let mediaPublisherValue = PassthroughSubject<(asset: AVAsset?, image: UIImage?), Never>()
    
    let imageForFilters: AnyPublisher<UIImage, Never>
    private let imageForFiltersValue = PassthroughSubject<UIImage, Never>()
    
    private let imageForPalettes = PassthroughSubject<UIImage?, Never>()
    
    let resetPhotoZoomOffset: AnyPublisher<UIImage, Never>
    private let resetPhotoZoomOffsetValue = PassthroughSubject<UIImage, Never>()
    
    let palettes: AnyPublisher<[Palette], Never>
    
    @Published private(set) var goal: Goal?
    @Published private(set) var routeIsAvailable: Bool = false
    @Published private(set) var availableGraphTypes: [GraphType] = [.none]
    @Published private(set) var unavailableGraphTypes: [GraphType] = []
    @Published private(set) var availableStatisticTypes: [StatisticType] = []
    @Published private(set) var superDistanceWatermarkVisible: Bool = false

    let mediaRemoved: AnyPublisher<Void, Never>
    private let mediaRemovedValue = PassthroughSubject<Void, Never>()
    let mediaAdded: AnyPublisher<Void, Never>
    private let mediaAddedValue = PassthroughSubject<Void, Never>()
    let mediaReplaced: AnyPublisher<Void, Never>
    private let mediaReplacedValue = PassthroughSubject<Void, Never>()
    
    let savedImage: AnyPublisher<UIImage, Never>
    private let savedImageValue = PassthroughSubject<UIImage, Never>()
    let savedVideo: AnyPublisher<Void, Never>
    private let savedVideoValue = PassthroughSubject<Void, Never>()
    let videoModesReady: AnyPublisher<Void, Never>
    private let videoModesReadyValue = PassthroughSubject<Void, Never>()
    
    private var subscribers: Set<AnyCancellable> = []
    
    init(activity: Activity) {
        self.activity = activity
        let design = activity.design
        self.designPublishable = ActivityDesignPublishable(design: design)
                
        changedStatistics = designPublishable.designPublisher.withPrevious()
            .map { previous, current in
                let previousStatistics = previous?.statisticsOptions ?? Set<StatisticType>()
                let currentStatistics = current.statisticsOptions
                return (current, currentStatistics.symmetricDifference(previousStatistics))
            }
            .eraseToAnyPublisher()
        
        graphImage = designPublishable.graphType
            .combineLatest(designPublishable.palette)
            .asyncMap { graphType, palette in
                guard graphType != .none else { return nil }
                
                switch graphType {
                case .none:
                    return nil
                case .route2d:
                    return try? await activity.routeImage(with: palette)
                case .route3d:
                    return nil
                case .splits:
                    return await activity.splitsGraphImage(with: palette)
                case .heartRate:
                    return try? await activity.heartRateGraphImage(with: palette)
                case .elevation:
                    return try? await activity.elevationGraphImage(with: palette)
                case .stepCount:
                    return await activity.stepCountsGraphImage(with: palette)
                }
            }
            .eraseToAnyPublisher()

        // publisher for when a design's media changes (photo/video/fill)
        mediaPublisher = mediaPublisherValue.eraseToAnyPublisher()
        
        // is always the unedited version of the photo/fill image
        imageForFilters = imageForFiltersValue.eraseToAnyPublisher()
        
        mediaAdded = mediaAddedValue.eraseToAnyPublisher()
        mediaRemoved = mediaRemovedValue.eraseToAnyPublisher()
        mediaReplaced = mediaReplacedValue.eraseToAnyPublisher()
        
        savedImage = savedImageValue.eraseToAnyPublisher()
        savedVideo = savedVideoValue.eraseToAnyPublisher()
        videoModesReady = videoModesReadyValue.eraseToAnyPublisher()
        resetPhotoZoomOffset = resetPhotoZoomOffsetValue.eraseToAnyPublisher()
        
        // anytime the design's image changes, regenerate the color palettes
        palettes = imageForPalettes.eraseToAnyPublisher()
            .asyncMap { image -> [Palette] in
                if let image = image {
                    return await Palette.palettes(from: image)
                } else {
                    return Palette.defaultPalettes
                }
            }
            .eraseToAnyPublisher()
        
        // save the design when it changes
        designPublishable.designPublisher.sink { design in
            do {
                try ActivityDesignStore.shared.save(design: design, for: activity)
                self.superDistanceWatermarkVisible = design.hasSuperDistanceFeaturesEnabled && !iAPManager.shared.hasSuperDistanceFeatures
            } catch {
                SentrySDK.capture(error: error)
            }
        }
        .store(in: &subscribers)

        iAPManager.shared.$isSubscribed
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.superDistanceWatermarkVisible = design.hasSuperDistanceFeaturesEnabled && !iAPManager.shared.hasSuperDistanceFeatures
            }.store(in: &subscribers)

        superDistanceWatermarkVisible = design.hasSuperDistanceFeaturesEnabled && !iAPManager.shared.hasSuperDistanceFeatures

        Task {
            let coordinates = (try? await activity.coordinates) ?? []
            let hasRoute = !coordinates.isEmpty
            self.routeIsAvailable = hasRoute
            if hasRoute {
                availableGraphTypes.append(contentsOf: [.route2d, .route3d])
                
                if coordinates.contains(where: { $0.altitude != 0.0 }) {
                    availableGraphTypes.append(.elevation)
                } else {
                    unavailableGraphTypes.append(.elevation)
                }
            } else {
                unavailableGraphTypes.append(contentsOf: [.route2d, .route3d])
                unavailableGraphTypes.append(.elevation)
                unavailableGraphTypes.append(.splits)
            }
        }
        
        Task {
            let hasHeartRateSamples = await activity.hasHeartRateSamples
            if hasHeartRateSamples {
                availableGraphTypes.append(.heartRate)
            } else {
                unavailableGraphTypes.append(.heartRate)
            }
        }

        if activity.activityType.isDistanceBased {
            Task {
                let splits = (try? await activity.splits) ?? []
                if !splits.isEmpty {
                    availableGraphTypes.append(.splits)
                } else {
                    unavailableGraphTypes.append(.splits)
                }
            }
        }

        let goal = ADUser.current.goalToDisplay(forActivity: activity)
        self.goal = goal
        if goal != nil {
            availableStatisticTypes.append(.goal)
        }
        
        availableStatisticTypes.append(contentsOf: StatisticType.stats(for: activity))
        
        Task {
            if let _ = try? await activity.cityAndState {
                availableStatisticTypes.append(.location)
            }
        }
        
        // when the palettes change, re-apply the selected palette if
        // the underlying color has changed
        palettes.sink { [weak self] palettes in
            guard let self = self else { return }
            
            if let foundPalette = palettes.first(where: { $0.name == self.design.palette.name }) {
                if self.design.palette != foundPalette {
                    self.set(palette: foundPalette)
                }
            }
        }.store(in: &subscribers)
    }
    
    // MARK: - Media
    
    func loadMedia() async {
        let media = design.media
        var image: UIImage? = nil
        var asset: AVAsset? = nil
        
        switch media {
        case .video:
            switch design.videoMode {
            case .loop:
                asset = design.videoAsset
            case .bounce:
                asset = await design.videoAssetWithBounce
            }
            
            videoModesReadyValue.send(())
            
            if let videoURL = design.videoAssetURL {
                Task {
                    let image = await VideoFrameGrabber.firstFrameForVideo(at: videoURL)
                    self.imageForPalettes.send(image)
                }
            }
        case .photo:
            if design.photoFilter != .none {
                image = await design.photoWithFilter
            } else {
                image = await design.photo
            }
            
            if let image = await design.photo {
                imageForFiltersValue.send(image)
            }

        case .fill:
            if design.photoFilter != .none {
                image = await design.fillWithFilter
            } else {
                image = design.fill?.image
            }
            
            if let image = design.fill?.image {
                imageForFiltersValue.send(image)
            }
        case .none, .arVideo:
            break
        }
        
        if media != .video { // for video we grab the first frame async
            imageForPalettes.send(image)
        }
        
        mediaPublisherValue.send((asset: asset, image: image))
    }
    
    func save(image: UIImage, isARMedia: Bool = false) {
        Task {
            await designPublishable.design.save(photo: image)
        }
        
        var design = design
        design.fill = nil
        design.media = .photo
        design.photoFilter = .none
        design.photoOffset = .zero
        design.photoZoom = 1.0
        design.media = .photo
        if isARMedia {
            design.graphType = .none
        }
        designPublishable.design = design
        
        imageForPalettes.send(image)
        imageForFiltersValue.send(image)
        resetPhotoZoomOffsetValue.send(image)
        
        mediaPublisherValue.send((asset: nil, image: image))
        
        savedImageValue.send(image)
    }
    
    func saveVideo(from url: URL, isARMedia: Bool = false) {
        var design = design
        design.fill = nil
        design.media = .video
        design.photoFilter = .none
        // default to loop mode
        design.videoMode = .loop
        design.photoOffset = .zero
        design.photoZoom = 1.0
        design.media = .video
        if isARMedia {
            design.graphType = .none
        }
        designPublishable.design = design

        Task {
            await designPublishable.design.saveVideo(from: url)
            if let image = await designPublishable.design.photo {
                imageForPalettes.send(image)
            }
            videoModesReadyValue.send(())
            savedVideoValue.send(())

            if let savedAssetUrl = designPublishable.design.videoAssetURL {
                mediaPublisherValue.send((asset: AVAsset(url: savedAssetUrl), image: nil))
            }
        }
    }
    
    func set(fill: Fill?) {
        guard fill != design.fill else { return }
        
        var design = design
        design.photoFilter = .none
        design.fill = fill
        design.media = fill != nil ? .fill : .none
        design.photoOffset = .zero
        design.photoZoom = 1.0
        design.removeVideo()
        design.removePhoto()
        designPublishable.design = design
        
        imageForPalettes.send(fill?.image)
        
        if let image = fill?.image {
            imageForFiltersValue.send(image)
            resetPhotoZoomOffsetValue.send(image)
            
            Task {
                await designPublishable.design.save(photo: image)
            }
        }
        
        mediaPublisherValue.send((asset: nil, image: fill?.image))
    }
    
    func set(photoFilter: PhotoFilter) {
        guard photoFilter != design.photoFilter else { return }
        
        designPublishable.design.photoFilter = photoFilter
        
        Task {
            var image: UIImage? = nil
            
            switch design.media {
            case .fill:
                image = await design.fillWithFilter
            case .photo:
                if photoFilter != .none {
                    image = await design.photoWithFilter
                } else {
                    image = await design.photo
                }
            default:
                break
            }

            imageForPalettes.send(image)
            
            mediaPublisherValue.send((asset: nil, image: image))
        }
    }
    
    // MARK: - UI Actions
    
    func mediaAddTapped() {
        mediaAddedValue.send()
    }
    
    func mediaReplaceTapped() {
        mediaReplacedValue.send()
    }
    
    func mediaRemoveTapped() {
        var design = design
        design.media = .none
        design.fill = nil
        design.photoFilter = .none
        design.removePhoto()
        design.removeVideo()
        designPublishable.design = design
        mediaRemovedValue.send()
    }
        
    // MARK: - Setters
    
    func toggle(statistic: StatisticType) {
        designPublishable.design.toggle(statisticType: statistic)
    }
    
    func set(videoMode: VideoMode) {
        guard videoMode != design.videoMode else { return }
        
        designPublishable.design.videoMode = videoMode
        
        Task {
            switch videoMode {
            case .loop:
                mediaPublisherValue.send((asset: design.videoAsset, image: nil))
            case .bounce:
                mediaPublisherValue.send((asset: await design.videoAssetWithBounce, image: nil))
            }
        }
    }
    
    func set(cutoutShape: CutoutShape) {
        guard cutoutShape != design.cutoutShape else { return }
        designPublishable.design.cutoutShape = cutoutShape
    }
    
    func set(alignment: StatisticAlignment) {
        guard alignment != design.alignment else { return }
        designPublishable.design.alignment = alignment
    }
        
    func set(palette: Palette) {
        guard palette != design.palette else { return }
        designPublishable.design.palette = palette
    }
    
    func set(font: ADFont) {
        designPublishable.design.font = font
    }
        
    func set(graphType: GraphType) {
        guard graphType != design.graphType else { return }
        var design = design
        design.graphType = graphType
        design.graphTransform = .identity
        designPublishable.design = design
    }
    
    func set(graphTransform: CGAffineTransform) {
        guard graphTransform != designPublishable.design.graphTransform else { return }
        designPublishable.design.graphTransform = graphTransform
    }
    
    func set(photoZoom: Float) {
        designPublishable.design.photoZoom = photoZoom
    }
    
    func set(photoOffset: CGPoint) {
        designPublishable.design.photoOffset = photoOffset
    }
    
}
