// Licensed under the Any Distance Source-Available License
//
//  ActivityRecorder.swift
//  ADAC
//
//  Created by Daniel Kuntz on 5/2/22.
//

import SwiftUI
import HealthKit
import CoreLocation
import MapKit
import Combine
import HCKalmanFilter
import Accelerate
import Sentry
import ActivityKit

class ActivityRecorder: NSObject, ObservableObject {
    #if DEBUG
    let DEBUG: Bool = false // change this one to test
    #else
    let DEBUG: Bool = false
    #endif

    let maxAllowableVelocityMetersPerSecond: Double = 30.0 // ~67mph
    let maxHorizontalAccuracyMeters: Double = 20.0

    let gpsHealthCheckTimeThreshold: TimeInterval = 60
    let gpsNotificationTitle: String = "⚠️📡🛰 GPS signal lost"
    let gpsNotificationBody: String = "Open the app on your iPhone to reconnect"

    var unit: DistanceUnit
    @Published var activityType: ActivityType {
        didSet {
            if activityType.showsRoute {
                locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
            } else {
                locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
            }
        }
    }
    
    @Published var goal: RecordingGoal
    let settings: RecordingSettings
    var didSendSafetyMessageAtStart: Bool = false // flag for if the user sent a safety message text at the start

    private(set) var startDate: Date = Date()

    @Published private(set) var state: iPhoneActivityRecordingState = .ready {
        didSet {
            ADTabBar.current?.setCenterTabAppearance(for: activityType, state: state)
        }
    }
    
    @Published private(set) var duration: TimeInterval = 0.0
    @Published private(set) var distance: Double = 0.0 /// meters
    @Published private(set) var elevationAscended: Double = 0.0 /// meters
    @Published private(set) var paceMeters: TimeInterval = 0.0 /// meters
    @Published private(set) var avgSpeedMetersSecond: Double = 0.0 /// meters / second
    @Published private(set) var totalCalories: Double = 0.0
    @Published private(set) var goalProgress: Float = 0.0
    @Published private(set) var goalMet: Bool = false
    @Published private(set) var goalHalfwayPointReached: Bool = false
    @Published private(set) var miSplits: [Split] = []
    @Published private(set) var kmSplits: [Split] = []
    @Published private(set) var heartRateData: [HeartRateSample] = []
    @Published private(set) var currentLocation: CLLocation?
    @Published private(set) var graphDataSource: GraphCollectibleDataSource?
    @Published var selectedGearID: String? = NSUbiquitousKeyValueStore.default.selectedGearForTypes[.shoes]

    private var restoredState: ActivityRecorderState?
    private var locationCache: ActivityRecorderLocationCache = ActivityRecorderLocationCache()
    private var locationAccuracyHasStabilized: Bool = false
    private var resetKalmanFilter: Bool = false
    private var kalmanFilter: HCKalmanAlgorithm?
    private var nonDistanceBasedCoordinate: CLLocation?
    private(set) var locations: [CLLocation] = []
    private(set) var coordinates: ContiguousArray<CLLocationCoordinate2D> = []
    private var prevLocationsCount: Int = 0
    private var prevLocationsCountElevationCalculation: Int = 0
    private var isPreparing: Bool = false

    var finishedWorkout: Activity?
    
    private let store = HKHealthStore()
    private var workoutBuilder: HKWorkoutBuilder
    private var routeBuilder: HKWorkoutRouteBuilder
    private(set) var locationManager: CLLocationManager
    private var publisherTimer: Timer?
    private var subscribers: Set<AnyCancellable> = []

    private let screenName = "ActivityRecorder.swift"

    var distanceInUnit: Double {
        return UnitConverter.meters(distance, toUnit: unit)
    }

    var pace: TimeInterval {
        guard paceMeters.isNormal && paceMeters > 0.0 else {
            return 0.0
        }

        if ADUser.current.distanceUnit == .miles {
            return TimeInterval(paceMeters * 1609.34)
        }

        return TimeInterval(paceMeters * 1000.0)
    }

    var avgSpeed: Double {
        if ADUser.current.distanceUnit == .miles {
            return TimeInterval((avgSpeedMetersSecond / 1609.34) * 3600.0)
        }

        return TimeInterval((avgSpeedMetersSecond / 1000.0) * 3600.0)
    }

    var splits: [Split] {
        switch unit {
        case .miles:
            return miSplits
                .map { $0.completedIfPartial() }
        case .kilometers:
            return kmSplits
                .map { $0.completedIfPartial() }
        }
    }
    
    var wasRestoredFromSavedState: Bool {
        return restoredState != nil
    }

    var hasCoordinates: Bool {
        return locations.count > 2
    }

    init(activityType: ActivityType,
         goal: RecordingGoal,
         unit: DistanceUnit,
         settings: RecordingSettings,
         startLocationManager: Bool = true) {
        self.unit = unit
        self.activityType = activityType
        self.goal = goal
        self.settings = settings

        let config = HKWorkoutConfiguration()
        config.activityType = activityType.hkWorkoutType
        workoutBuilder = HKWorkoutBuilder(healthStore: store, configuration: config, device: .local())
        routeBuilder = HKWorkoutRouteBuilder(healthStore: store, device: .local())
        locationManager = CLLocationManager()
        super.init()
        locationManager.delegate = self

        if startLocationManager {
            if locationManager.authorizationStatus == .authorizedWhenInUse ||
               locationManager.authorizationStatus == .authorizedAlways {
                startUpdatingLocationIfNecessary()
            }
        }

        if settings.preventAutoLock {
            UIApplication.shared.isIdleTimerDisabled = true
        }

        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else {
                    return
                }

                if activityType.showsRoute {
                    self.locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
                    self.locationManager.distanceFilter = 1
                    self.stopUpdatingLocationIfNecessary()
                }

                if self.state == .ready && self.isPreparing {
                    try? self.start()
                }

                guard self.state == .recording else {
                    return
                }

                self.stopPublisherTimer()
                self.startPublisherTimer(withTimeInterval: 0.5)
                print("backgrounding")
            }
            .store(in: &subscribers)

        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else {
                    return
                }

                if activityType.showsRoute {
                    self.locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
                    self.locationManager.distanceFilter = kCLDistanceFilterNone
                    self.startUpdatingLocationIfNecessary()
                }
                
                if self.state == .locationPermissionNeeded &&
                   self.activityType.showsRoute &&
                   (locationManager.authorizationStatus == .authorizedWhenInUse ||
                   locationManager.authorizationStatus == .authorizedAlways) {
                    self.state = .ready
                    self.startUpdatingLocationIfNecessary()
                }

                guard self.state == .recording else {
                    return
                }

                self.stopPublisherTimer()
                self.startPublisherTimer()
                print("foregrounding")
            }
            .store(in: &subscribers)
    }

    init(activityType: ActivityType,
         unit: DistanceUnit) {
        self.unit = unit
        self.activityType = activityType
        self.goal = RecordingGoal(type: .open, unit: .miles, target: 0.0)
        self.settings = RecordingSettings()

        let config = HKWorkoutConfiguration()
        config.activityType = activityType.hkWorkoutType
        workoutBuilder = HKWorkoutBuilder(healthStore: store, configuration: config, device: .local())
        routeBuilder = HKWorkoutRouteBuilder(healthStore: store, device: .local())
        locationManager = CLLocationManager()

        super.init()

        self.goal.objectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.objectWillChange.send()
                }
            }.store(in: &subscribers)
    }

    func reset() {
        state = .ready
        duration = 0.0
        distance = 0.0
        elevationAscended = 0.0
        paceMeters = 0.0
        avgSpeedMetersSecond = 0.0
        totalCalories = 0.0
        goalProgress = 0.0
        goalMet = false
        goalHalfwayPointReached = false
        miSplits.removeAll()
        kmSplits.removeAll()
        heartRateData.removeAll()
        graphDataSource = nil
        resetKalmanFilter = true
        locations.removeAll()
        coordinates.removeAll()
        prevLocationsCount = 0
        prevLocationsCountElevationCalculation = 0
        finishedWorkout = nil
        restoredState = nil
        publisherTimer?.invalidate()
        publisherTimer = nil

        let config = HKWorkoutConfiguration()
        config.activityType = activityType.hkWorkoutType
        workoutBuilder = HKWorkoutBuilder(healthStore: store, configuration: config, device: .local())
        routeBuilder = HKWorkoutRouteBuilder(healthStore: store, device: .local())
        if activityType.showsRoute {
            startUpdatingLocationIfNecessary()
        }
    }

    func stopUpdatingLocationIfNecessary() {
        if activityType.isDistanceBased &&
           state == .ready &&
           !isPreparing {
            locationManager.stopUpdatingLocation()
        }
    }

    func startUpdatingLocationIfNecessary() {
        if activityType.isDistanceBased &&
           state == .ready {
            locationManager.activityType = .fitness
            locationManager.allowsBackgroundLocationUpdates = true
            locationManager.pausesLocationUpdatesAutomatically = false
            locationManager.distanceFilter = kCLDistanceFilterNone
            if activityType.showsRoute {
                locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
            } else {
                locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
            }
            locationManager.delegate = self

            locationManager.startUpdatingLocation()
        }
    }

    func requestLocationAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }

    func moveToLocationPermissionState() {
        state = .locationPermissionNeeded
    }

    func prepare() async throws {
        guard state == .ready else {
            throw ActivityRecorderError.recorderFinished
        }

        isPreparing = true
        objectWillChange.send()
        do {
            try await workoutBuilder.beginCollection(at: Date())
        } catch {
            SentrySDK.capture(error: error)
            Analytics.logEvent("Error Starting Recording",
                               screenName, .otherEvent, withParameters: ["error": error.localizedDescription])
        }

        startPublisherTimer()
        startUpdatingLocationIfNecessary()
        LiveActivityManager.shared.startLiveActivity(for: self)
        updateSplits()
    }

    func start() throws {
        print("start")
        guard state == .ready else {
            throw ActivityRecorderError.recorderFinished
        }

        Analytics.logEvent("Start Recording", screenName, .otherEvent)
        state = .recording
        startDate = Date()
        isPreparing = false
    }

    func pause() async throws {
        guard state == .recording else {
            throw ActivityRecorderError.recorderFinished
        }

        Analytics.logEvent("Pause Recording", screenName, .otherEvent)
        state = .paused
        LiveActivityManager.shared.updateLiveActivity(for: self)
        let pauseEvent = HKWorkoutEvent(type: .pause,
                                        dateInterval: DateInterval(start: Date(), duration: 0),
                                        metadata: nil)
        do {
            try await workoutBuilder.addWorkoutEvents([pauseEvent])
        } catch {
            SentrySDK.capture(error: error)
            Analytics.logEvent("Error Pausing Recording",
                               screenName, .otherEvent, withParameters: ["error": error.localizedDescription])
        }

        resetKalmanFilter = true
//        stopPublisherTimer()
    }

    func resume() async throws {
        guard state == .paused else {
            throw ActivityRecorderError.recorderFinished
        }

        Analytics.logEvent("Resume Recording", screenName, .otherEvent)
        state = .recording
        let resumeEvent = HKWorkoutEvent(type: .resume,
                                         dateInterval: DateInterval(start: Date(), duration: 0),
                                         metadata: nil)
        do {
            try await workoutBuilder.addWorkoutEvents([resumeEvent])
        } catch {
            SentrySDK.capture(error: error)
            Analytics.logEvent("Error Resuming Recording",
                               screenName, .otherEvent, withParameters: ["error": error.localizedDescription])
        }

        startPublisherTimer()
    }

    func stopAndDiscardActivity() {
        Analytics.logEvent("Discard Activity", screenName, .otherEvent)
        UIApplication.shared.isIdleTimerDisabled = false
        workoutBuilder.discardWorkout()
        stopPublisherTimer()
        locationManager.stopUpdatingLocation()
        state = .discarded
        ADTabBar.current?.resetCenterTabAppearance()
        removePendingHealthCheckNotification()
        deleteState()
        Task(priority: .userInitiated) {
            await LiveActivityManager.shared.endLiveActivity()
        }
    }

    func finish(manualDistance: Double? = nil) async {
        // Check HealthKit sharing authorization to make sure we won't get an error while saving.
        guard HealthKitActivitiesStore.shared.isAuthorizedToShare() else {
            DispatchQueue.main.async {
                self.state = .paused
                let controller = UIHostingController(rootView: RecordingHealthKitAuthorizationView(onAuthorize: {
                    Task(priority: .userInitiated) {
                        await self.finish(manualDistance: manualDistance)
                    }
                }).background(BackgroundClearView()))
                UIApplication.shared.topmostViewController?.modalPresentationStyle = .automatic
                UIApplication.shared.topmostViewController?.present(controller, animated: true)
            }

            return
        }

        do {
            Analytics.logEvent("Finish Recording", screenName, .otherEvent)
            DispatchQueue.main.async {
                UIApplication.shared.isIdleTimerDisabled = false
            }
            
            if let manualDistance = manualDistance {
                distance = manualDistance

                if distanceInUnit > 0 {
                    paceMeters = (duration / Double(distance)).clamped(to: 0...5999)
                    avgSpeedMetersSecond = Double(distance) / duration
                }
            }

            deleteState()
            
            guard state == .paused else {
                throw ActivityRecorderError.recorderFinished
            }
            
            DispatchQueue.main.async {
                self.state = .saving
                self.stopPublisherTimer()
                self.removePendingHealthCheckNotification()
            }

            await LiveActivityManager.shared.endLiveActivity()

            try? await workoutBuilder.endCollection(at: Date())
            locationManager.stopUpdatingLocation()

            var events = workoutBuilder.workoutEvents
            if self.activityType.isDistanceBased && !miSplits.isEmpty && !kmSplits.isEmpty && distance > 1.0 {
                events.append(contentsOf: miSplits.map { $0.hkWorkoutEvent() })
                events.append(contentsOf: kmSplits.map { $0.hkWorkoutEvent() })
            }
            
            self.locations = calculateElevationSmoothedLocations(for: self.locations)

            let encodedNonDistanceBasedCoordinate = try? JSONEncoder().encode(LocationWrapper(from: nonDistanceBasedCoordinate))
            var nonDistanceBasedCoordinateString = ""
            if let encodedNonDistanceBasedCoordinate = encodedNonDistanceBasedCoordinate {
                nonDistanceBasedCoordinateString = String(data: encodedNonDistanceBasedCoordinate, encoding: .utf8) ?? ""
            }

            let workout = HKWorkout(activityType: activityType.hkWorkoutType,
                                    start: startDate,
                                    end: workoutBuilder.endDate ?? Date(),
                                    workoutEvents: events,
                                    totalEnergyBurned: HKQuantity(unit: .kilocalorie(), doubleValue: totalCalories),
                                    totalDistance: HKQuantity(unit: .meter(), doubleValue: distance),
                                    metadata: [HKMetadataKeyElevationAscended : HKQuantity(unit: .meter(), doubleValue: elevationAscended),
                                               HKMetadataKeyIndoorWorkout : activityType.locationType == .indoor,
//                                               HKMetadataKeyTimeZone : TimeZone.current.identifier,
                                               ADMetadataKey.totalDistanceMeters : distance,
                                               ADMetadataKey.goalType : goal.type.rawValue,
                                               ADMetadataKey.goalTarget : goal.target,
                                               ADMetadataKey.clipRoute : settings.clipRoute,
                                               ADMetadataKey.activityType : activityType.rawValue,
                                               ADMetadataKey.restoredFromSavedState : wasRestoredFromSavedState,
                                               ADMetadataKey.nonDistanceBasedCoordinate : nonDistanceBasedCoordinateString])

            try await store.save(workout)
            if self.activityType.showsRoute && !self.locations.isEmpty {
                try await routeBuilder.insertRouteData(self.locations)
                try await routeBuilder.finishRoute(with: workout, metadata: nil)
            }

            var additionalSamples: [HKSample] = []

            // Add quantity type for additional identifiers if necessary.
            if let distanceQuantity = workout.totalDistance {
                let quantityType: HKQuantityType? = {
                    switch activityType {
                    case .bikeRide, .commuteRide, .virtualRide, .recumbentRide, .eBikeRide:
                        return HKObjectType.quantityType(forIdentifier: .distanceCycling)
                    case .downhillSkiing, .crossCountrySkiing, .snowboard:
                        return HKObjectType.quantityType(forIdentifier: .distanceDownhillSnowSports)
                    case .wheelchairRun, .wheelchairWalk:
                        return HKObjectType.quantityType(forIdentifier: .distanceWheelchair)
                    case .swimming:
                        return HKObjectType.quantityType(forIdentifier: .distanceSwimming)
                    default:
                        return nil
                    }
                }()

                if let quantityType = quantityType {
                    let distanceSample = HKQuantitySample(type: quantityType,
                                                          quantity: distanceQuantity,
                                                          start: workout.startDate,
                                                          end: workout.endDate)
                    additionalSamples.append(distanceSample)
                }
            }

            // Add energy quantity so this workout counts towards the move ring.
            if let energyQuantity = workout.totalEnergyBurned {
                let energyBurnedType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
                let energySample = HKQuantitySample(type: energyBurnedType,
                                                    quantity: energyQuantity,
                                                    start: workout.startDate,
                                                    end: workout.endDate)
                additionalSamples.append(energySample)
            }

            try? await store.addSamples(additionalSamples, to: workout)

            workoutBuilder.discardWorkout()
            finishedWorkout = workout

            if let selectedGearID = selectedGearID {
                finishedWorkout?.gearIDs = [selectedGearID]
            }
            NSUbiquitousKeyValueStore.default.lastGearRefreshDate = finishedWorkout?.startDate.addingTimeInterval(1.0)

            graphDataSource = await GraphCollectibleDataSource(locations: self.locations,
                                                               splits: self.activityType.isDistanceBased ? self.splits : [],
                                                               shouldShowSpeedInsteadOfPace: self.activityType.shouldShowSpeedInsteadOfPace,
                                                               recordedWorkout: workout)
            
            DispatchQueue.main.async {
                self.state = .saved
                ReloadPublishers.adActivityRecorded.send()
                ADTabBar.current?.resetCenterTabAppearance()
            }
        } catch {
            SentrySDK.capture(error: error)
            Analytics.logEvent("Error Finishing Recording",
                               screenName, .otherEvent, withParameters: ["error": error.localizedDescription])
            state = .discarded
            await ADTabBar.current?.resetCenterTabAppearance()
        }
    }
    
    // MARK: - Timer
    
    private func startPublisherTimer(withTimeInterval interval: TimeInterval = 0.1) {
        DispatchQueue.main.async {
            self.publisherTimer = Timer.scheduledTimer(withTimeInterval: interval,
                                                       repeats: true, block: { [weak self] _ in
                guard let self = self else {
                    return
                }

                var shouldUpdateLiveActivity: Bool = false
                let timeSinceStart = TimeInterval(Int(Date().timeIntervalSince(self.startDate)))
                if timeSinceStart != LiveActivityManager.shared.liveActivityUptime {
                    LiveActivityManager.shared.liveActivityUptime = timeSinceStart
                    shouldUpdateLiveActivity = true
                }

                if Int(self.workoutBuilder.elapsedTime(at: Date())) != Int(self.duration) {
                    self.duration = self.workoutBuilder.elapsedTime(at: Date())
                    shouldUpdateLiveActivity = true
                }

                let calories = CalorieCalculator.calories(for: self.activityType,
                                                          duration: self.duration,
                                                          distance: self.distance,
                                                          elevationGain: self.elevationAscended)
                if calories != self.totalCalories {
                    self.totalCalories = calories
                }

                let newGoalProgress = self.calculateGoalProgress()
                if self.goalProgress != newGoalProgress {
                    self.goalProgress = newGoalProgress

                    if !self.goalMet {
                        self.goalMet = self.goalProgress == 1.0
                        if self.goalMet {
                            self.sendNotification(with: "Goal reached!")
                            Analytics.logEvent("Send Goal Reached Notification", self.screenName, .otherEvent)
                        }
                    }

                    if !self.goalHalfwayPointReached {
                        self.goalHalfwayPointReached = self.goalProgress >= 0.5
                        if self.goalHalfwayPointReached {
                            self.sendNotification(with: "Goal halfway point reached!")
                            Analytics.logEvent("Send Goal Halfway Notification", self.screenName, .otherEvent)
                        }
                    }
                }

                if !self.activityType.showsRoute {
                    // Save state in this block if the activity is not distance based, since the
                    // location update block never gets called.
                    Task(priority: .userInitiated) {
                        print("timer block saving state")
                        await self.saveState()
                    }
                }

                if shouldUpdateLiveActivity {
                    LiveActivityManager.shared.updateLiveActivity(for: self)
                }

                if (self.state == .recording || self.state == .paused || self.state == .waitingForGps),
                   self.activityType.showsRoute {
                    // Notification added and removed every cycle to catch app terminations.
                    self.removePendingHealthCheckNotification()
                    self.sendNotification(with: self.gpsNotificationTitle, body: self.gpsNotificationBody, afterTime: 4.0)
                }
            })
        }
    }
    
    private func stopPublisherTimer() {
        publisherTimer?.invalidate()
        publisherTimer = nil
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [self.gpsNotificationTitle])
    }

    private func removePendingHealthCheckNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [self.gpsNotificationTitle])
    }
    
    private func sendHealthCheckNotification() {
        self.sendNotification(with: gpsNotificationTitle,
                              body: gpsNotificationBody)
    }
    
    private func sendNotification(with title: String, body: String = "", afterTime time: TimeInterval = 0) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = UNNotificationSound.default
        content.interruptionLevel = .timeSensitive
        let trigger = time > 0 ? UNTimeIntervalNotificationTrigger(timeInterval: time, repeats: false) : nil
        let request = UNNotificationRequest(identifier: title, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
    
    // MARK: - Calculations
    
    private func calculateCurrentDistance(for locations: [CLLocation]) -> Double {
        guard locations.count >= 2 && locationAccuracyHasStabilized else {
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

        prevLocationsCount = locations.count
        return distance + additionalDistance
    }

    private func calculateElevationAscended(for locations: [CLLocation]) -> Double {
        let locations = locations.filter { $0.verticalAccuracy > 0 }

        guard locations.count >= 2 else {
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
                    print("finished split \(unit.fullName) \(splits[idx].duration) \(splits[idx].duration.timeFormatted(includeSeconds: true))")
                    addNewSplit()
                }
            } else {
                addNewSplit()
            }
        }

        updateSplits(for: .miles, splits: &miSplits)
        updateSplits(for: .kilometers, splits: &kmSplits)
    }

    func regionForCurrentRoute() -> MKCoordinateRegion? {
        let currentLocationRegion: MKCoordinateRegion? = {
            if let currentLocation = currentLocation {
                return MKCoordinateRegion(center: currentLocation.coordinate, latitudinalMeters: 500, longitudinalMeters: 500)
            } else {
                return nil
            }
        }()

        guard let minLat = coordinates.map({ $0.latitude }).min(),
              let maxLat = coordinates.map({ $0.latitude }).max(),
              let minLon = coordinates.map({ $0.longitude }).min(),
              let maxLon = coordinates.map({ $0.longitude }).max() else {
            return currentLocationRegion
        }

        let span = MKCoordinateSpan(latitudeDelta: max(currentLocationRegion?.span.latitudeDelta ?? 0, (maxLat - minLat) * 1.5),
                                    longitudeDelta: max(currentLocationRegion?.span.longitudeDelta ?? 0, (maxLon - minLon) * 1.5))
        let center = CLLocationCoordinate2D(latitude: ((minLat + maxLat) / 2),
                                            longitude: (minLon + maxLon) / 2)
        return MKCoordinateRegion(center: center, span: span)
    }
}

// MARK: - CLLocationManagerDelegate

extension ActivityRecorder: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        defer {
            if activityType.showsRoute {
                Task(priority: .userInitiated) {
                    await self.saveState()
                }
            } else {
                self.nonDistanceBasedCoordinate = locations.first ?? self.nonDistanceBasedCoordinate
            }
        }

        guard activityType.showsRoute else {
            return
        }
        
        if self.state == .waitingForGps {
            self.state = .recording
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
                let coord = CLLocationCoordinate2D(latitude: location.coordinate.latitude + duration * 0.0001,
                                                   longitude: location.coordinate.longitude + duration * 0.0001)
                return CLLocation(coordinate: coord,
                                  altitude: location.altitude + Double.random(in: -5...5),
                                  horizontalAccuracy: location.horizontalAccuracy,
                                  verticalAccuracy: location.verticalAccuracy,
                                  timestamp: location.timestamp)
            }
        }

        guard !filteredLocations.isEmpty else { return }
        let kalmanSmoothedLocations = kalmanSmoothedLocations(for: filteredLocations)

        var velocityFilteredLocations: [CLLocation] = DEBUG ? kalmanSmoothedLocations : []
        if !DEBUG {
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
        }

        guard state == .recording else {
            return
        }
        
        if self.activityType.showsRoute {
            self.locations.append(contentsOf: velocityFilteredLocations)
            self.coordinates.append(contentsOf: velocityFilteredLocations.map { $0.coordinate })
            
            self.currentLocation = velocityFilteredLocations.first
            
            checkLocationAccuracy()
            guard locationAccuracyHasStabilized else {
                return
            }

            let elevationSmoothedLocations = calculateElevationSmoothedLocations(for: self.locations)
            self.distance = calculateCurrentDistance(for: elevationSmoothedLocations)
            self.elevationAscended = calculateElevationAscended(for: elevationSmoothedLocations)
            self.updateSplits()

            if self.distanceInUnit > 0 {
                self.paceMeters = (self.duration / Double(self.distance)).clamped(to: 0...5999)
                self.avgSpeedMetersSecond = Double(self.distance) / self.duration
            }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse ||
           manager.authorizationStatus == .authorizedAlways {
            Analytics.logEvent("Location permission granted", screenName, .otherEvent)
            if state == .locationPermissionNeeded {
                state = .ready
            }
            startUpdatingLocationIfNecessary()
        }
    }

    /// Checks if the last N locations have a vertical accuracy standard deviation below a certain
    /// threshold. Vertical accuracy tends to stabilize once GPS is locked in.
    private func checkLocationAccuracy() {
        if DEBUG {
            locationAccuracyHasStabilized = true
            return
        }
        
        let n: Int = 15
        let stdDeviationThreshold: Double = 0.3
        
        guard locations.count >= n && !locationAccuracyHasStabilized else {
            return
        }
        
        let lastN = Array(locations.dropFirst(locations.count - n))
        let stdDeviation = lastN.map { $0.verticalAccuracy }.stdDeviation()
        if stdDeviation < stdDeviationThreshold {
            locationAccuracyHasStabilized = true
            locations.removeFirst(n)
            coordinates.removeFirst(n)
            print("stabilize")
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

// MARK: - State Restoration

extension ActivityRecorder {
    func saveState() async {
        guard state != .ready && state != .saving && state != .saved && state != .couldNotSave && state != .discarded else {
            deleteState()
            return
        }

        let wrappedCurrentLocation = LocationWrapper(from: self.currentLocation)
        var events = self.workoutBuilder.workoutEvents
        events.append(HKWorkoutEvent(type: .marker,
                                     dateInterval: DateInterval(start: Date(), duration: 0.0),
                                     metadata: [ADEventType.key: ADEventType.saveState.rawValue]))
        let wrappedEvents = events.map { HKWorkoutEventWrapper(event: $0) }

        let state = ActivityRecorderState(unit: self.unit,
                                          activityType: self.activityType,
                                          goal: self.goal,
                                          settings: self.settings,
                                          startDate: self.startDate,
                                          state: self.state,
                                          duration: self.duration,
                                          distance: self.distance,
                                          elevationAscended: self.elevationAscended,
                                          pace: self.paceMeters,
                                          avgSpeed: self.avgSpeedMetersSecond,
                                          totalCalories: self.totalCalories,
                                          goalProgress: self.goalProgress,
                                          goalMet: self.goalMet,
                                          goalHalfwayPointReached: self.goalHalfwayPointReached,
                                          miSplits: self.miSplits,
                                          kmSplits: self.kmSplits,
                                          heartRateData: self.heartRateData,
                                          currentLocation: wrappedCurrentLocation,
                                          locations: nil,
                                          workoutEvents: wrappedEvents,
                                          didSendSafetyMessageAtStart: didSendSafetyMessageAtStart)

        try? locationCache.writeLocations(self.locations, forActivityWith: self.startDate)

        DispatchQueue.main.async {
            NSUbiquitousKeyValueStore.default.activityRecorderState = state
        }
    }
    
    func deleteState() {
        NSUbiquitousKeyValueStore.default.activityRecorderState = nil
        try? locationCache.deleteFile(forActivityWith: self.startDate)
    }
    
    convenience init(savedState state: ActivityRecorderState, workout: Activity? = nil) {
        self.init(activityType: state.activityType,
                  goal: state.goal,
                  unit: state.unit,
                  settings: state.settings,
                  startLocationManager: workout == nil)

        self.state = state.state
        self.didSendSafetyMessageAtStart = state.didSendSafetyMessageAtStart
        self.startDate = state.startDate
        self.duration = state.duration
        self.distance = state.distance
        self.elevationAscended = state.elevationAscended
        self.paceMeters = state.pace
        self.avgSpeedMetersSecond = state.avgSpeed
        self.totalCalories = state.totalCalories
        self.goalProgress = state.goalProgress.clamped(to: 0...1)
        self.goalMet = state.goalMet
        self.goalHalfwayPointReached = state.goalHalfwayPointReached
        self.miSplits = state.miSplits
        self.kmSplits = state.kmSplits
        self.heartRateData = state.heartRateData
        self.currentLocation = CLLocation(wrapper: state.currentLocation)
        if let locations = state.locations {
            self.locations = locations.compactMap { CLLocation(wrapper: $0) }
        } else {
            self.locations = (try? locationCache.locations(forActivityWith: state.startDate)) ?? []
            self.prevLocationsCount = self.locations.count
            self.prevLocationsCountElevationCalculation = self.locations.count
        }
        self.coordinates = ContiguousArray(self.locations.map { $0.coordinate })
        self.locationAccuracyHasStabilized = true
        self.restoredState = state
        self.finishedWorkout = workout
        
        Task(priority: .background) {
            if self.state == .saved {
                self.locationManager.stopUpdatingLocation()
                self.locationManager.delegate = nil
                if let workout = workout {
                    let collectibles = ADUser.current.collectibles(for: workout)
                    self.graphDataSource = await GraphCollectibleDataSource(locations: self.locations,
                                                               splits: self.splits,
                                                               shouldShowSpeedInsteadOfPace: self.activityType.shouldShowSpeedInsteadOfPace,
                                                               recordedWorkout: workout,
                                                               collectibles: collectibles)
                }
            } else {
                // This was restored from a "GPS Lost" scenario
                var events = state.workoutEvents.map { HKWorkoutEvent(wrapper: $0) }
                if let mostRecentSaveEvent = events
                    .filter({ (($0.metadata?[ADEventType.key] as? String) ?? "") == ADEventType.saveState.rawValue })
                    .sorted(by: { $0.dateInterval.start > $1.dateInterval.start })
                    .first {
                    // Add a pause event when the state was last saved, and a resume event now so that
                    // the duration is calculated correctly
                    let pauseEvent = HKWorkoutEvent(type: .pause,
                                                    dateInterval: mostRecentSaveEvent.dateInterval,
                                                    metadata: nil)
                    let resumeEvent = HKWorkoutEvent(type: .resume,
                                                     dateInterval: DateInterval(start: Date(), duration: 0.0),
                                                     metadata: nil)
                    events.append(contentsOf: [pauseEvent, resumeEvent])
                }
                let restoreEvent = HKWorkoutEvent(type: .marker,
                                                  dateInterval: DateInterval(start: Date(), duration: 0),
                                                  metadata: [ADEventType.key: ADEventType.restoreState.rawValue])
                events.append(restoreEvent)

                try? await workoutBuilder.beginCollection(at: startDate)
                try? await workoutBuilder.addWorkoutEvents(events)
                LiveActivityManager.shared.startLiveActivity(for: self)
            }
        }
        
        if self.state == .recording {
            startPublisherTimer()
        }
    }

    convenience init(post: Post) {
        self.init(activityType: post.activityType,
                  unit: ADUser.current.distanceUnit)

        self.state = .saved
        self.startDate = post.activityStartDateUTC
        self.duration = post.movingTime ?? 0.0
        self.distance = Double(post.distanceMeters ?? 0.0)
        self.elevationAscended = Double(post.totalElevationGainMeters ?? 0.0)
        self.paceMeters = Double(post.paceMeters ?? 0.0)
        self.avgSpeedMetersSecond = Double(post.averageSpeedMetersSecond ?? 0.0)
        self.totalCalories = Double(post.activeCalories ?? 0.0)
        self.miSplits = post.activityType.isDistanceBased ? (post.miSplits ?? []) : []
        self.kmSplits = post.activityType.isDistanceBased ? (post.kmSplits ?? []) : []
        self.locations = (post.coordinates?.compactMap { CLLocation(wrapper: $0) }) ?? []
        self.coordinates = ContiguousArray(self.locations.map { $0.coordinate })
        self.locationAccuracyHasStabilized = true

        Task(priority: .userInitiated) {
            self.graphDataSource = await GraphCollectibleDataSource(locations: self.locations,
                                                                    splits: ADUser.current.distanceUnit == .miles ? miSplits : kmSplits,
                                                                    shouldShowSpeedInsteadOfPace: self.activityType.shouldShowSpeedInsteadOfPace,
                                                                    collectibles: post.collectibles)
        }
    }
}

enum ActivityRecorderError: Error {
    case workoutNotReturned
    case recorderFinished
}

extension ActivityRecorderError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .workoutNotReturned:
            return "Workout not returned"
        case .recorderFinished:
            return "Recorder finished"
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
