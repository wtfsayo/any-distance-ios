// Licensed under the Any Distance Source-Available License
//
//  Activity+Media.swift
//  ADAC
//
//  Created by Jarod Luebbert on 4/21/22.
//

import UIKit
import AVFoundation

extension Activity {
    
    private var cache: HealthDataCache {
        HealthDataCache.shared
    }
    
    // MARK: Images
    
    var routeImageMini: UIImage? {
        get async throws {
            if let image = cache.image(.routeImageMini, activity: self, palette: .dark) {
                return image
            }
            
            let coordinates = try await coordinates
            
            guard !coordinates.isEmpty else { return nil }
            
            let image: UIImage? = try await withCheckedThrowingContinuation { continuation in
                RouteImageRenderer.renderMiniRoute(coordinates: coordinates) { image in
                    continuation.resume(returning: image)
                }
            }
            
            if let image = image {
                cache.cache(.routeImageMini, image: image, activity: self, palette: .dark)
            }
            
            return image
        }
    }
    
    func routeImage(with palette: Palette = .dark) async throws -> UIImage? {
        if let image = cache.image(.routeImage, activity: self, palette: palette) {
            return image
        }
        
        let coordinates = try await coordinates
        
        guard !coordinates.isEmpty else { return nil }
        
        let image: UIImage? = try await withCheckedThrowingContinuation { continuation in
            RouteImageRenderer.renderRoute(withPalette: palette,
                                      coordinates: coordinates) { image in
                continuation.resume(returning: image)
            }
        }
        
        if let image = image {
            cache.cache(.routeImage, image: image, activity: self, palette: palette)
        }
        
        return image
    }
    
    func elevationGraphImage(with palette: Palette = .dark) async throws -> UIImage? {
        if let image = cache.image(.elevationGraphImage, activity: self, palette: palette) {
            return image
        }

        let coordinates = try await coordinates
        
        guard !coordinates.isEmpty else { return nil }

        let image: UIImage? = try await withCheckedThrowingContinuation { continuation in
            ElevationGraphGenerator.renderGraph(withPalette: palette,
                                                coordinates: coordinates) { image in
                continuation.resume(returning: image)
            }
        }
        
        if let image = image {
            cache.cache(.elevationGraphImage, image: image, activity: self, palette: palette)
        }
        
        return image
    }
    
    func heartRateGraphImage(with palette: Palette = .dark) async throws -> UIImage? {
        if let image = cache.image(.heartRateGraphImage, activity: self, palette: palette) {
            return image
        }
        
        let heartRateSamples = try await heartRateSamples
        
        guard await hasHeartRateSamples else { return nil }

        let image: UIImage? = await withCheckedContinuation { continuation in
            HeartRateGraphGenerator.renderGraph(with: palette, samples: heartRateSamples) { image in
                continuation.resume(returning: image)
            }
        }
        
        if let image = image {
            cache.cache(.heartRateGraphImage, image: image, activity: self, palette: palette)
        }
        
        return image
    }
    
    func stepCountsGraphImage(with palette: Palette = .dark) async -> UIImage? {
        guard let stepCounts = await stepCounts, !stepCounts.isEmpty else {
            return nil
        }
        
        if let image = cache.image(.stepCountsGraphImage,
                                   activity: self,
                                   palette: palette,
                                   stepCount: stepCounts.reduce(0, +)) {
            return image
        }

        let image: UIImage? = await withCheckedContinuation { continuation in
            StepCountGraphRenderer.renderGraph(withPalette: palette, stepCounts: stepCounts) { image in
                continuation.resume(returning: image)
            }
        }
        
        if let image = image {
            cache.cache(.stepCountsGraphImage,
                        image: image,
                        activity: self,
                        palette: palette,
                        stepCount: stepCounts.count)
        }
        
        return image
    }

    func tinyStepCountsGraphImage(with palette: Palette = .dark) async -> UIImage? {
        guard let stepCounts = await stepCounts, !stepCounts.isEmpty else {
            return nil
        }

        let image: UIImage? = await withCheckedContinuation { continuation in
            StepCountGraphRenderer.renderTinyGraph(withPalette: palette, stepCounts: stepCounts) { image in
                continuation.resume(returning: image)
            }
        }

        return image
    }

    func splitsGraphImage(with palette: Palette = .dark) async -> UIImage? {
        if let image = cache.image(.splitsGraphImage, activity: self, palette: palette) {
            return image
        }
        
        guard let splits = try? await splits else { return nil }
        let image: UIImage? = await withCheckedContinuation { continuation in
            // we only have garmin splits in the unit they were originally
            // recorded, and no way to know that unit
            let showsUnitLabel = (self is GarminActivity) ? false : true
            SplitsGraphRenderer.renderGraph(withSplits: splits,
                                            speedInsteadOfPace: activityType.shouldShowSpeedInsteadOfPace,
                                            palette: palette,
                                            showsUnitLabel: showsUnitLabel) { image in
                continuation.resume(returning: image)
            }
        }
        
        if let image = image {
            cache.cache(.splitsGraphImage, image: image, activity: self, palette: palette)
        }
        
        return image
    }
    

    var mapRouteImage: UIImage? {
        get async {
            if let image = cache.image(.mapRouteImage, activity: self, palette: .dark) {
                return image
            }

            guard let coordinates = try? await coordinates else {
                return nil
            }

            let image = await MapKitMapRenderer.generateMapImage(from: coordinates)

            if let image = image {
                cache.cache(.mapRouteImage, image: image, activity: self, palette: .dark)
            }

            return image
        }
    }
}
