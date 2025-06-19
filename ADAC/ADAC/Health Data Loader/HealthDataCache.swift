// Licensed under the Any Distance Source-Available License
//
//  HealthDataCache.swift
//  ADAC
//
//  Created by Jarod Luebbert on 4/25/22.
//

import Foundation
import CoreLocation
import Cache

fileprivate extension RawRepresentable where RawValue == String {
    func with(activity: Activity) -> String {
        "\(activity.id)_\(rawValue)"
    }

    func with(activity: Activity, palette: Palette, distanceUnit: DistanceUnit, stepCount: Int? = nil) -> String {
        let prefix = "\(activity.id)_\(palette.id)_\(distanceUnit.abbreviation)"
        if let stepCount = stepCount {
            return "\(prefix)_\(stepCount)_\(rawValue)"
        } else {
            return "\(prefix)_\(rawValue)"
        }
    }

    func with(post: Post) -> String {
        if post.id.isEmpty {
            return "\(post.localHealthKitID)_\(rawValue)"
        }
        return "\(post.id)_\(rawValue)"
    }

    func with(gearColor: GearColor) -> String {
        return "\(GearType.shoes.rawValue)_\(gearColor.rawValue)"
    }

    func with(date: Date) -> String {
        "\(date.timeIntervalSince1970)_\(rawValue)"
    }
}

class HealthDataCache {
    
    enum ImageCacheKey: String {
        case routeImage = "route_image"
        case routeImageMini = "route_image_mini"
        case elevationGraphImage = "elevation_graph_image"
        case heartRateGraphImage = "heart_rate_graph_image"
        case stepCountsGraphImage = "step_counts_graph_image"
        case splitsGraphImage = "splits_graph_image"
        case mapRouteImage = "map_route_image"
        case gearTexture = "gear_texture"
    }

    private enum CacheKey: String {
        case coordinates
        case stepCounts = "step_counts"
        case stepCountTotal = "step_count_total"
        case distance
        case splits
        case heartRateData
        case gearTextures
    }
        
    static let shared = HealthDataCache()
    
    private let coordinatesCache: Storage<String, [String]>?
    private let stepCountsCache: Storage<String, [Int]>?
    private let stepCountTotalCache: Storage<String, Int>?
    private let imageCache: Storage<String, UIImage>?
    private let distancesCache: Storage<String, Float>?
    private let splitsCache: Storage<String, [Split]>?
    private let heartRateDataCache: Storage<String, [HeartRateSample]>?
    private let gearTextureCache: Storage<String, UIImage>?

    private init() {
        let diskConfig = DiskConfig(name: "com.anydistance.HealthDataCache")
        let expiration = Expiry.seconds(604800.0) // expire in one week
        let memoryConfig = MemoryConfig(expiry: expiration, countLimit: 100, totalCostLimit: 10)

        coordinatesCache = try? Storage<String, [String]>(
            diskConfig: diskConfig,
            memoryConfig: memoryConfig,
            transformer: TransformerFactory.forCodable(ofType: [String].self)
        )
        stepCountsCache = coordinatesCache?.transformCodable(ofType: [Int].self)
        stepCountTotalCache = coordinatesCache?.transformCodable(ofType: Int.self)
        imageCache = coordinatesCache?.transformImage()
        distancesCache = coordinatesCache?.transformCodable(ofType: Float.self)
        splitsCache = coordinatesCache?.transformCodable(ofType: [Split].self)
        heartRateDataCache = coordinatesCache?.transformCodable(ofType: [HeartRateSample].self)
        gearTextureCache = coordinatesCache?.transformImage()

        if !NSUbiquitousKeyValueStore.default.hasClearedCoordinatesCacheForGarminFix {
            try? coordinatesCache?.removeAll()
            try? imageCache?.removeAll()
            NSUbiquitousKeyValueStore.default.hasClearedCoordinatesCacheForGarminFix = true
        }
    }

    // MARK: - Write

    func cache(_ key: ImageCacheKey, image: UIImage, activity: Activity, palette: Palette, stepCount: Int? = nil) {
        let unit = ADUser.current.distanceUnit
        try? imageCache?.setObject(image, forKey: key.with(activity: activity, palette: palette, distanceUnit: unit, stepCount: stepCount))
    }

    func cache(_ key: ImageCacheKey, image: UIImage, post: Post) {
        try? imageCache?.setObject(image, forKey: key.with(post: post))
    }

    func cache(texture: UIImage, for gearColor: GearColor) {
        try? imageCache?.setObject(texture, forKey: ImageCacheKey.gearTexture.with(gearColor: gearColor))
    }

    func cache(coordinates: [CLLocation], for activity: Activity) {
        let locations = coordinates.compactMap { LocationWrapper(from: $0)?.toString() }
        let key = CacheKey.coordinates.with(activity: activity)
        try? coordinatesCache?.setObject(locations, forKey: key)
    }

    func cache(stepCounts: [Int], for activity: Activity) {
        let key = CacheKey.stepCounts.with(activity: activity)
        try? stepCountsCache?.setObject(stepCounts, forKey: key)
    }

    func cache(stepCountTotal: Int, for activity: Activity) {
        let key = CacheKey.stepCountTotal.with(activity: activity)
        try? stepCountTotalCache?.setObject(stepCountTotal, forKey: key)
    }

    func cache(distance: Float, for date: Date) {
        let key = CacheKey.distance.with(date: date)
        try? distancesCache?.setObject(distance, forKey: key)
    }

    func cache(splits: [Split], for activity: Activity) {
        let key = CacheKey.splits.with(activity: activity)
        try? splitsCache?.setObject(splits, forKey: key)
    }

    func cache(heartRateData: [HeartRateSample], for activity: Activity) {
        let key = CacheKey.heartRateData.with(activity: activity)
        try? heartRateDataCache?.setObject(heartRateData, forKey: key)
    }

    // MARK: - Read

    func image(_ key: ImageCacheKey, activity: Activity, palette: Palette, stepCount: Int? = nil) -> UIImage? {
        let unit = ADUser.current.distanceUnit
        let cacheKey = key.with(activity: activity,
                                palette: palette,
                                distanceUnit: unit,
                                stepCount: stepCount)
        return try? imageCache?.object(forKey: cacheKey)
    }

    func image(_ key: ImageCacheKey, post: Post) -> UIImage? {
        let cacheKey = key.with(post: post)
        return try? imageCache?.object(forKey: cacheKey)
    }

    func texture(for gearColor: GearColor) -> UIImage? {
        let cacheKey = ImageCacheKey.gearTexture.with(gearColor: gearColor)
        return try? imageCache?.object(forKey: cacheKey)
    }

    func coordinates(for activity: Activity) -> [CLLocation]? {
        let key = CacheKey.coordinates.with(activity: activity)
        return try? coordinatesCache?.object(forKey: key).compactMap { CLLocation(wrapper: LocationWrapper(string: $0)) }
    }
    
    func stepCounts(for activity: Activity) -> [Int]? {
        let key = CacheKey.stepCounts.with(activity: activity)
        return try? stepCountsCache?.object(forKey: key)
    }

    func stepCountTotal(for activity: Activity) -> Int? {
        let key = CacheKey.stepCountTotal.with(activity: activity)
        return try? stepCountTotalCache?.object(forKey: key)
    }

    func distance(for date: Date) -> Float? {
        let key = CacheKey.distance.with(date: date)
        return try? distancesCache?.object(forKey: key)
    }

    func splits(for activity: Activity) -> [Split]? {
        let key = CacheKey.splits.with(activity: activity)
        return try? splitsCache?.object(forKey: key)
    }

    func heartRateData(for activity: Activity) -> [HeartRateSample]? {
        let key = CacheKey.heartRateData.with(activity: activity)
        return try? heartRateDataCache?.object(forKey: key)
    }
}

fileprivate extension NSUbiquitousKeyValueStore {
    var hasClearedCoordinatesCacheForGarminFix: Bool {
        get {
            return bool(forKey: "hasClearedCoordinatesCacheForGarminFix")
        }

        set {
            set(newValue, forKey: "hasClearedCoordinatesCacheForGarminFix")
        }
    }
}
