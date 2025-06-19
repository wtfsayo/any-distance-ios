// Licensed under the Any Distance Source-Available License
//
//  GraphCollectibleDataSource.swift
//  ADAC
//
//  Created by Any Distance on 8/1/22.
//

import UIKit
import HealthKit
import CoreLocation

class GraphCollectibleDataSource: NSObject, ObservableObject {
    static let graphSize: CGSize = CGSize(width: 1500, height: 800)

    var recordedWorkout: Activity?
    @Published var splitsGraphImage: UIImage?
    @Published var elevationGraphImage: UIImage?
    @Published var heartRateGraphImage: UIImage?
    @Published var collectibles: [Collectible] = []

    var hasData: Bool {
        return splitsGraphImage != nil || elevationGraphImage != nil || heartRateGraphImage != nil || !collectibles.isEmpty
    }
    
    init(locations: [CLLocation],
         splits: [Split],
         shouldShowSpeedInsteadOfPace: Bool,
         recordedWorkout: Activity? = nil,
         collectibles: [Collectible] = []) async {
        self.recordedWorkout = recordedWorkout
        super.init()

        if locations.count > 30 {
            Task(priority: .userInitiated) {
                let image = await withCheckedContinuation { continuation in
                    ElevationGraphGenerator.renderGraph(coordinates: locations,
                                                        size: GraphCollectibleDataSource.graphSize,
                                                        lineWidth: 11) { image in
                        DispatchQueue.global(qos: .userInitiated).async {
                            let resizedImage = image?
                                .preparingThumbnail(of: CGSize(width: 800, height: 427))
                            continuation.resume(returning: resizedImage)
                        }
                    }
                }
                await MainActor.run {
                    elevationGraphImage = image
                }
            }
        }

        if !splits.isEmpty {
            Task(priority: .userInitiated) {
                var palette = Palette.dark
                palette.accentColor = UIColor.adOrangeLighter
                let image = await withCheckedContinuation { continuation in
                    SplitsGraphRenderer.renderGraph(withSplits: splits,
                                                    speedInsteadOfPace: shouldShowSpeedInsteadOfPace,
                                                    palette: palette,
                                                    limit: 1000) { image in
                        DispatchQueue.global(qos: .userInitiated).async {
                            let resizedImage = image?
                                .preparingThumbnail(of: CGSize(width: 800, height: 427))
                            continuation.resume(returning: resizedImage)
                        }
                    }
                }
                await MainActor.run {
                    splitsGraphImage = image
                }
            }
        }

        if let recordedWorkout = recordedWorkout,
           let samples = try? await recordedWorkout.heartRateSamples,
           samples.count > 3 {
            Task(priority: .userInitiated) {
                let image = await withCheckedContinuation { continuation in
                    HeartRateGraphGenerator.renderGraph(samples: samples) { image in
                        DispatchQueue.global(qos: .userInitiated).async {
                            let resizedImage = image?
                                .preparingThumbnail(of: CGSize(width: 800, height: 427))
                            continuation.resume(returning: resizedImage)
                        }
                    }
                }
                await MainActor.run {
                    heartRateGraphImage = image
                }
            }
        }

        if collectibles.isEmpty, let recordedWorkout = recordedWorkout {
            let collectibles = await CollectibleCalculator.collectibles(for: [recordedWorkout])
            let (grantedCollectibles, _) = CollectibleCalculator.userCollectiblesAfterGranting(collectibles, sendEvents: false)
            self.collectibles = grantedCollectibles
        } else {
            self.collectibles = collectibles
        }
    }
}
