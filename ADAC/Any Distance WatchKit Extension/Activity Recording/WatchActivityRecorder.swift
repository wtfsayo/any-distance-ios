// Licensed under the Any Distance Source-Available License
//
//  WatchActivityRecorder.swift
//  Any Distance WatchKit Extension
//
//  Created by Daniel Kuntz on 8/18/22.
//

import Foundation
import HealthKit
import CoreLocation
import MapKit
import WatchKit
import Accelerate

class WatchActivityRecorder: NSObject, ObservableObject {
    #if DEBUG
    let DEBUG: Bool = false // change this one to test
    #else
    let DEBUG: Bool = false
    #endif

    let maxAllowableVelocityMetersPerSecond: Double = 30.0 // ~67mph
    let maxHorizontalAccuracyMeters: Double = 20.0

    let unit: DistanceUnit
    let activityType: ActivityType
    let goal: RecordingGoal

    @Published private(set) var state: WatchActivityRecorder.RecordingState = .ready
    @Published private(set) var duration: TimeInterval = 0.0
    @Published private(set) var distance: Double = 0.0 /// meters
    @Published private(set) var elevationAscended: Double = 0.0 /// meters
    @Published private(set) var currentHeartRate: Double = 0.0 /// BPM
    @Published private(set) var pace: TimeInterval = 0.0 /// per mile or kilometer depending on unit
    @Published private(set) var avgSpeed: Double = 0.0 /// mph or kmh depending on unit
    @Published private(set) var totalCalories: Double = 0.0
    @Published private(set) var goalProgress: Float = 0.0
    @Published private(set) var goalMet: Bool = false
    @Published private(set) var goalHalfwayPointReached: Bool = false
    @Published private(set) var miSplits: [Split] = []
    @Published private(set) var kmSplits: [Split] = []
    @Published private(set) var heartRateData: [HeartRateRawSample] = []
    @Published private(set) var currentLocation: CLLocation?
    @Published private(set) var locations: [CLLocation] = []

    private var kalmanFilter: HCKalmanAlgorithm?
    private var resetKalmanFilter: Bool = false
    private var nonDistanceBasedCoordinate: CLLocation?

    private let store: HKHealthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    private var routeBuilder: HKWorkoutRouteBuilder
    private var locationManager: CLLocationManager

    private var locationTimer: Timer?
    private var refreshTimer: Timer?
    private var prevLocationsCount: Int = 0
    private var prevLocationsCountElevationCalculation: Int = 0

    private var isMotionPaused: Bool = false

    private var prevLocationsCountMapBoundsCalculation: Int = 0
    private var minLat: CLLocationDegrees = CLLocationDegrees.greatestFiniteMagnitude
    private var maxLat: CLLocationDegrees = -CLLocationDegrees.greatestFiniteMagnitude
    private var minLon: CLLocationDegrees = CLLocationDegrees.greatestFiniteMagnitude
    private var maxLon: CLLocationDegrees = -CLLocationDegrees.greatestFiniteMagnitude

    let startDate = Date()

    var distanceInUnit: Double {
        return UnitConverter.meters(distance, toUnit: unit)
    }

    var isFinished: Bool {
        return state == .saved || state == .discarded
    }

    init(activityType: ActivityType, goal: RecordingGoal, unit: DistanceUnit) {
        self.unit = unit
        self.activityType = activityType
        self.goal = goal

        let config = HKWorkoutConfiguration()
        config.activityType = activityType.hkWorkoutType
        config.locationType = activityType.locationType
        workoutSession = try? HKWorkoutSession(healthStore: store, configuration: config)
        workoutBuilder = workoutSession?.associatedWorkoutBuilder()
        routeBuilder = HKWorkoutRouteBuilder(healthStore: store, device: .local())
        locationManager = CLLocationManager()
        super.init()

        locationManager.activityType = .fitness
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.delegate = self
        if locationManager.authorizationStatus == .notDetermined {
            state = .locationPermissionNeeded
            locationManager.requestWhenInUseAuthorization()
        } else {
            locationManager.startUpdatingLocation()
        }

        workoutBuilder?.delegate = self
        workoutBuilder?.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: config)
        switch activityType {
        case .bikeRide, .commuteRide, .virtualRide, .recumbentRide, .eBikeRide:
            workoutBuilder?.dataSource?.enableCollection(for: .quantityType(forIdentifier: .distanceCycling)!, predicate: nil)
        case .downhillSkiing, .crossCountrySkiing, .snowboard:
            workoutBuilder?.dataSource?.enableCollection(for: .quantityType(forIdentifier: .distanceDownhillSnowSports)!, predicate: nil)
        case .wheelchairRun, .wheelchairWalk:
            workoutBuilder?.dataSource?.enableCollection(for: .quantityType(forIdentifier: .distanceWheelchair)!, predicate: nil)
        case .swimming:
            workoutBuilder?.dataSource?.enableCollection(for: .quantityType(forIdentifier: .distanceSwimming)!, predicate: nil)
        case .walk, .dogWalk, .strollerWalk, .treadmillWalk, .hotGirlWalk, .walkWithCane,
                .walkWithWalker, .deskWalk, .walkingMeeting, .run, .dogRun, .strollerRun,
                .treadmillRun, .trailRun, .hike, .rucking:
            workoutBuilder?.dataSource?.enableCollection(for: .quantityType(forIdentifier: .distanceWalkingRunning)!, predicate: nil)
        default:
            break
        }

        workoutSession?.delegate = self
        workoutSession?.prepare()

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
            self.updateStats()
        }

        #if !targetEnvironment(simulator)
        if DEBUG {
            locationTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                let location = CLLocation(coordinate: .init(latitude: 33.75, longitude: -84.38), altitude: 300, horizontalAccuracy: 1, verticalAccuracy: 1, timestamp: Date())
                self.locationManager(self.locationManager, didUpdateLocations: [location])
            }
        }
        #endif
    }

    func start() async throws {
        guard state == .ready else {
            throw WatchActivityRecorderError.recorderFinished
        }

        #if !targetEnvironment(simulator)
        workoutSession?.startActivity(with: Date())
        try await workoutBuilder?.beginCollection(at: Date())
        #endif

        self.state = .recording
        iPhonePreferences.shared.triggerActivityStartedNotificationOniPhone()
        iPhonePreferences.shared.sendLiveActivityData(for: self)
    }

    func pause() async throws {
        guard state == .recording else {
            throw WatchActivityRecorderError.recorderFinished
        }

        #if !targetEnvironment(simulator)
        workoutSession?.pause()
        #endif

        state = .paused
        iPhonePreferences.shared.sendLiveActivityData(for: self)
    }

    private func pauseForMotionPaused() {
        guard state == .recording else {
            return
        }

        state = .paused
        isMotionPaused = true
        iPhonePreferences.shared.sendLiveActivityData(for: self)
        WKInterfaceDevice.current().play(.notification)
    }

    func resume() async throws {
        guard state == .paused else {
            throw WatchActivityRecorderError.recorderFinished
        }

        #if !targetEnvironment(simulator)
        workoutSession?.resume()
        #endif

        state = .recording
        resetMotionPausedInternalState()
        iPhonePreferences.shared.sendLiveActivityData(for: self)
    }

    private func resumeForMotionResumed() {
        guard state == .paused else {
            return
        }

        state = .recording
        resetMotionPausedInternalState()
        iPhonePreferences.shared.sendLiveActivityData(for: self)
        WKInterfaceDevice.current().play(.notification)
    }

    private func resetMotionPausedInternalState() {
        isMotionPaused = false
    }

    func stopAndDiscardActivity() {
        locationManager.stopUpdatingHeading()
        locationManager.delegate = nil
        state = .discarded
        workoutSession?.stopActivity(with: Date())
        workoutSession?.end()
        iPhonePreferences.shared.sendLiveActivityData(for: self)

        Task(priority: .userInitiated) {
            try await self.workoutBuilder?.endCollection(at: Date())
            self.workoutBuilder?.discardWorkout()
        }
    }

    func finish() async {
        NSUbiquitousKeyValueStore.default.recentlyRecordedActivityTypes.insert(activityType, at: 0)
        DispatchQueue.main.async {
            self.state = .saved
            iPhonePreferences.shared.sendLiveActivityData(for: self)
        }
        locationManager.stopUpdatingLocation()
        locationManager.delegate = nil
        refreshTimer?.invalidate()
        refreshTimer = nil

        do {
            #if !targetEnvironment(simulator)
            var events: [HKWorkoutEvent] = workoutBuilder?.workoutEvents ?? []
            if self.activityType.isDistanceBased && !miSplits.isEmpty && !kmSplits.isEmpty {
                events.append(contentsOf: miSplits.map { $0.hkWorkoutEvent() })
                events.append(contentsOf: kmSplits.map { $0.hkWorkoutEvent() })
            }

            workoutSession?.stopActivity(with: Date())
            workoutSession?.end()
            try await workoutBuilder?.endCollection(at: Date())

            let encodedNonDistanceBasedCoordinate = try? JSONEncoder().encode(LocationWrapper(from: nonDistanceBasedCoordinate))
            var nonDistanceBasedCoordinateString = ""
            if let encodedNonDistanceBasedCoordinate = encodedNonDistanceBasedCoordinate {
                nonDistanceBasedCoordinateString = String(data: encodedNonDistanceBasedCoordinate, encoding: .utf8) ?? ""
            }

            let workout = HKWorkout(activityType: activityType.hkWorkoutType,
                                    start: startDate,
                                    end: workoutBuilder?.endDate ?? Date(),
                                    workoutEvents: events,
                                    totalEnergyBurned: HKQuantity(unit: .kilocalorie(), doubleValue: totalCalories),
                                    totalDistance: HKQuantity(unit: .meter(), doubleValue: distance),
                                    metadata: [HKMetadataKeyElevationAscended : HKQuantity(unit: .meter(), doubleValue: elevationAscended),
                                               HKMetadataKeyIndoorWorkout : activityType.locationType == .indoor,
                                               ADMetadataKey.totalDistanceMeters : distance,
                                               ADMetadataKey.goalType : goal.type.rawValue,
                                               ADMetadataKey.goalTarget : goal.target,
                                               ADMetadataKey.activityType : activityType.rawValue,
                                               ADMetadataKey.clipRoute : iPhonePreferences.shared.shouldClipRoute && activityType.supportsRouteClip,
                                               ADMetadataKey.wasRecordedOnWatch : true,
                                               ADMetadataKey.nonDistanceBasedCoordinate : nonDistanceBasedCoordinateString])

            try await store.save(workout)
            if self.activityType.showsRoute, !self.locations.isEmpty {
                try await routeBuilder.insertRouteData(locations)
                try await routeBuilder.finishRoute(with: workout, metadata: nil)
            }

            workoutBuilder?.discardWorkout()
            #endif
        } catch {
            print(error.localizedDescription)
        }
    }

    // MARK: - Calculations

    private func calculateCurrentDistance() -> Double {
        guard !locations.isEmpty else {
            return 0.0
        }

        var additionalDistance: Double = 0
        if state == .recording {
            for i in (prevLocationsCount-1).clamped(to: 0...locations.count-2)..<locations.count-1 {
                let location = locations[i]
                let next = locations[i+1]
                additionalDistance += next.distanceAccountingForElevation(from: location)
            }
        }

        return distance + additionalDistance
    }

    private func calculateElevationAscended() -> Double {
        #if !targetEnvironment(simulator)
        let locations = locations.filter { $0.verticalAccuracy > 0 }
        #endif

        guard !locations.isEmpty else {
            return 0.0
        }

        var additionalElevation: Double = 0
        if state == .recording {
            for i in (prevLocationsCountElevationCalculation-1).clamped(to: 0...locations.count-2)..<locations.count-1 {
                let location = locations[i]
                let nextLocation = locations[i+1]
                if nextLocation.altitude > location.altitude {
                    additionalElevation += nextLocation.altitude - location.altitude
                }
            }
        }

        prevLocationsCountElevationCalculation = locations.count
        return elevationAscended + additionalElevation
    }

    private func calculateGoalProgress() -> Float {
        var progress: Float = 0
        switch goal.type {
        case .time:
            progress = Float(duration) / goal.target
        case .calories:
            progress = Float(totalCalories) / goal.target
        case .distance:
            progress = Float(distanceInUnit) / goal.target
        default: break
        }
        return progress.clamped(to: 0...1)
    }

    private func calculateElevationSmoothedLocations(for locations: [CLLocation]) -> [CLLocation] {
        guard locations.count > 1 else {
            return locations
        }

        let altitudes = locations.map { $0.altitude }
        let bin: Int = 30
        return locations.enumerated().map { i, coord in
            let i = i - (bin/2)
            let lower = i.clamped(to: 0...(locations.count - (bin/2) - 1).clamped(to: 0...Int.max))
            let upper = (i + bin).clamped(to: lower...(locations.count - 1))
            let avgElevation = vDSP.mean(altitudes[lower...upper])
            return CLLocation(coordinate: coord.coordinate,
                              altitude: avgElevation,
                              horizontalAccuracy: coord.horizontalAccuracy,
                              verticalAccuracy: coord.verticalAccuracy,
                              timestamp: coord.timestamp)
        }
    }

    private func updateSplits() {
        guard let workoutBuilder = workoutBuilder else {
            return
        }

        func updateSplits(for unit: DistanceUnit, splits: inout [Split]) {
            func addNewSplit() {
                print("adding new split with start distance - \(distance)")
                let newSplit = Split(unit: unit,
                                     startDate: Date(),
                                     duration: 0,
                                     startDistanceMeters: distance,
                                     totalDistanceMeters: distance,
                                     isPartial: true)
                splits.append(newSplit)
            }

            let unitDistance = UnitConverter.value(1, inUnitToMeters: unit)
            if let idx = splits.firstIndex(where: { $0.isPartial }) {
                splits[idx].duration = workoutBuilder.elapsedTime(at: Date()) - workoutBuilder.elapsedTime(at: splits[idx].startDate)
                splits[idx].totalDistanceMeters = distance
                if splits[idx].currentSplitDistanceMeters >= unitDistance {
                    splits[idx] = splits[idx].completedIfPartial()
                    print(duration)
                    print("finished split \(unit.fullName) \(splits[idx].duration)")
                    addNewSplit()
                }
            } else {
                addNewSplit()
            }
        }

        updateSplits(for: .miles, splits: &miSplits)
        updateSplits(for: .kilometers, splits: &kmSplits)
    }

    private func updateStats() {
        let prevDuration = self.duration

        if DEBUG {
            self.duration = Date().timeIntervalSince(startDate)
        } else {
            if let elapsedTime = workoutBuilder?.elapsedTime {
                self.duration = elapsedTime
            }
        }

        if self.locations.count > self.prevLocationsCount && self.locations.count > 1 {
            self.distance = calculateCurrentDistance()
            self.elevationAscended = calculateElevationAscended()
            self.updateSplits()
            self.prevLocationsCount = self.locations.count

            if distanceInUnit > 0.01 {
                self.avgSpeed = distanceInUnit / (duration / 3600)
                self.pace = duration / distanceInUnit
            }
        }

        self.goalProgress = self.calculateGoalProgress()
        if !self.goalMet {
            self.goalMet = self.goalProgress == 1.0
            if self.goalMet {
//                self.sendNotification(with: "Goal reached!")
            }
        }

        if !self.goalHalfwayPointReached {
            self.goalHalfwayPointReached = self.goalProgress >= 0.5
            if self.goalHalfwayPointReached {
//                self.sendNotification(with: "Goal halfway point reached!")
            }
        }

        if Int(self.duration) != Int(prevDuration) {
            iPhonePreferences.shared.sendLiveActivityData(for: self)
        }
    }

    func regionForCurrentRoute() -> MKCoordinateRegion? {
        let currentLocationRegion: MKCoordinateRegion? = {
            if let currentLocation = currentLocation {
                return MKCoordinateRegion(center: currentLocation.coordinate, latitudinalMeters: 500, longitudinalMeters: 500)
            } else {
                return nil
            }
        }()

        let (minLat, maxLat, minLon, maxLon) = self.bounds(for: locations)
        let span = MKCoordinateSpan(latitudeDelta: max(currentLocationRegion?.span.latitudeDelta ?? 0, (maxLat - minLat) * 1.5),
                                    longitudeDelta: max(currentLocationRegion?.span.longitudeDelta ?? 0, (maxLon - minLon) * 1.5))
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2,
                                            longitude: (minLon + maxLon) / 2)
        return MKCoordinateRegion(center: center, span: span)
    }

    private func bounds(for locations: [CLLocation]) -> (minLat: CLLocationDegrees,
                                                         maxLat: CLLocationDegrees,
                                                         minLon: CLLocationDegrees,
                                                         maxLon: CLLocationDegrees) {
        guard !locations.isEmpty else {
            return (minLat: 0, maxLat: 0, minLon: 0, maxLon: 0)
        }

        guard locations.count > prevLocationsCountMapBoundsCalculation else {
            return (minLat: minLat, maxLat: maxLat, minLon: minLon, maxLon: maxLon)
        }

        let newLocations = locations[prevLocationsCountMapBoundsCalculation..<locations.count]

        for location in newLocations {
            if location.coordinate.latitude < minLat {
                minLat = location.coordinate.latitude
            }

            if location.coordinate.latitude > maxLat {
                maxLat = location.coordinate.latitude
            }

            if location.coordinate.longitude < minLon {
                minLon = location.coordinate.longitude
            }

            if location.coordinate.longitude > maxLon {
                maxLon = location.coordinate.longitude
            }
        }

        prevLocationsCountMapBoundsCalculation = locations.count
        return (minLat: minLat, maxLat: maxLat, minLon: minLon, maxLon: maxLon)
    }
}

// MARK: - HKWorkoutSessionDelegate

extension WatchActivityRecorder: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession,
                        didChangeTo toState: HKWorkoutSessionState,
                        from fromState: HKWorkoutSessionState,
                        date: Date) {
        print("workoutSession didChangeTo \(toState)")
    }

    func workoutSession(_ workoutSession: HKWorkoutSession, didGenerate event: HKWorkoutEvent) {
        print("workoutSession didGenerate \(event)")

        guard NSUbiquitousKeyValueStore.default.autoPauseOn else {
            return
        }
        
        switch event.type {
        case .motionPaused:
            pauseForMotionPaused()
            Task(priority: .userInitiated) {
                let pauseEvent = HKWorkoutEvent(type: .pause,
                                                dateInterval: DateInterval(start: Date(), duration: 0.0),
                                                metadata: nil)
                try? await workoutBuilder?.addWorkoutEvents([pauseEvent])
            }
        case .motionResumed:
            resumeForMotionResumed()
            Task(priority: .userInitiated) {
                let resumeEvent = HKWorkoutEvent(type: .resume,
                                                 dateInterval: DateInterval(start: Date(), duration: 0.0),
                                                 metadata: nil)
                try? await workoutBuilder?.addWorkoutEvents([resumeEvent])
            }
        case .pauseOrResumeRequest:
            Task(priority: .userInitiated) {
                if state == .paused {
                    try? await self.resume()
                    WKInterfaceDevice.current().play(.start)
                } else if state == .recording {
                    try? await self.pause()
                    WKInterfaceDevice.current().play(.stop)
                }
            }
        default: break
        }
    }

    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("workoutSession didFailWithError \(error)")
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WatchActivityRecorder: HKLiveWorkoutBuilderDelegate {
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        print("workoutBuilder didCollectDataOf:")

        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else {
                continue
            }

            let statistics = workoutBuilder.statistics(for: quantityType)

            switch quantityType.identifier {
            case HKQuantityTypeIdentifier.heartRate.rawValue:
                self.currentHeartRate = statistics?.mostRecentQuantity()?.doubleValue(for: .count().unitDivided(by: .minute())) ?? self.currentHeartRate
                self.heartRateData.append(HeartRateRawSample(bpm: self.currentHeartRate, date: Date()))
            case HKQuantityTypeIdentifier.activeEnergyBurned.rawValue:
                self.totalCalories = statistics?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? self.totalCalories
            default:
                break
            }
        }

        updateStats()
    }

    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        print("workoutBuilderDidCollectEvent")
    }
}

extension WatchActivityRecorder: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        defer {
            if !self.activityType.isDistanceBased {
                self.nonDistanceBasedCoordinate = locations.first ?? self.nonDistanceBasedCoordinate
            }
        }

        if state != .recording {
            self.currentLocation = locations.first
        }

        var filteredLocations = locations.filter { (location: CLLocation) -> Bool in
            location.horizontalAccuracy <= maxHorizontalAccuracyMeters &&
            location.horizontalAccuracy >= 0.0
        }

        if DEBUG {
            filteredLocations = filteredLocations.map { location in
                let coord = CLLocationCoordinate2D(latitude: location.coordinate.latitude + (duration * 0.0002 * sin(duration * 0.07)),
                                                   longitude: location.coordinate.longitude + (duration * 0.0002 * cos(duration * 0.08)))
                return CLLocation(coordinate: coord,
                                  altitude: location.altitude + Double.random(in: -5...5),
                                  horizontalAccuracy: location.horizontalAccuracy,
                                  verticalAccuracy: location.verticalAccuracy,
                                  timestamp: location.timestamp)
            }
        }

        guard !filteredLocations.isEmpty else { return }
        let kalmanSmoothedLocations = kalmanSmoothedLocations(for: filteredLocations)

        var velocityFilteredLocations: [CLLocation] = []
        for (i, location) in kalmanSmoothedLocations.enumerated() {
            guard let last = velocityFilteredLocations[safe: i - 1] ?? self.locations.last else {
                velocityFilteredLocations.append(location)
                continue
            }

            let distance = location.distanceAccountingForElevation(from: last)
            let time = location.timestamp.timeIntervalSince(last.timestamp)
            let velocity = distance / time
            if velocity < maxAllowableVelocityMetersPerSecond {
                velocityFilteredLocations.append(location)
            }
        }

        updateStats()
        guard state == .recording else {
            return
        }

        if self.activityType.showsRoute {
            self.locations.append(contentsOf: velocityFilteredLocations)
            self.currentLocation = velocityFilteredLocations.first
//            print("current: \(self.currentLocation)")
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse && state == .locationPermissionNeeded {
            state = .ready
            locationManager.startUpdatingLocation()
        }
    }

    private func kalmanSmoothedLocations(for locations: [CLLocation]) -> [CLLocation] {
        guard let firstLocation = locations.first else {
            return []
        }

        if kalmanFilter == nil {
            kalmanFilter = HCKalmanAlgorithm(initialLocation: firstLocation)
            kalmanFilter?.rValue = 100.0
        }

        if resetKalmanFilter {
            kalmanFilter?.resetKalman(newStartLocation: firstLocation)
            resetKalmanFilter = false
        }

        return locations.compactMap { location in
            let processed = kalmanFilter?.processState(currentLocation: location)
            if processed?.coordinate.latitude.isNaN ?? false {
                kalmanFilter?.resetKalman(newStartLocation: location)
                return location
            } else {
                return processed
            }
        }
    }
}

enum WatchActivityRecorderError: Error {
    case workoutNotReturned
    case recorderFinished
    case builderError
}

extension WatchActivityRecorder {
    enum RecordingState: Int, Codable {
        case locationPermissionNeeded
        case ready
        case recording
        case paused
        case saving
        case saved
        case couldNotSave
        case discarded

        var displayName: String {
            switch self {
            case .locationPermissionNeeded:
                return ""
            case .ready:
                return "Get ready!"
            case .recording:
                return "Tracking"
            case .paused:
                return "Paused"
            case .saving:
                return "Saving"
            case .saved:
                return "Saved"
            case .couldNotSave:
                return "Error saving"
            case .discarded:
                return "Discarded"
            }
        }

        var displayColor: UIColor {
            switch self {
            case .ready:
                return .adOrangeLighter
            default:
                return .white
            }
        }

        var isFinished: Bool {
            return self == .saved
        }

        var iPhoneRecordingState: iPhoneActivityRecordingState {
            switch self {
            case .locationPermissionNeeded:
                return .locationPermissionNeeded
            case .ready:
                return .ready
            case .recording:
                return .recording
            case .paused:
                return .paused
            case .saving:
                return .saving
            case .saved:
                return .saved
            case .couldNotSave:
                return .couldNotSave
            case .discarded:
                return .discarded
            }
        }
    }
}

fileprivate extension CLLocation {
    func distanceAccountingForElevation(from coordinate: CLLocation) -> CLLocationDistance {
        let distanceWithoutElevation = self.distance(from: coordinate)
        let elevationDelta = abs(self.altitude - coordinate.altitude)
        return sqrt(pow(distanceWithoutElevation, 2) + pow(elevationDelta, 2))
    }
}
