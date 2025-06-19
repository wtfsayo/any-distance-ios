// Licensed under the Any Distance Source-Available License
//
//  ActivityProgressGraphModel.swift
//  ADAC
//
//  Created by Daniel Kuntz on 7/8/23.
//

import Foundation
import CoreLocation
import Combine
import MapKit
import SwiftUI

class ActivityProgressGraphModel: NSObject, ObservableObject {
    let CLUSTER_DISTANCE_METERS: Double = 5000 // 3.15 miles

    lazy var yearTimePeriods = generateTimePeriods(for: .year, component: .year, count: 5)
    lazy var monthTimePeriods = generateTimePeriods(for: .month, component: .month, count: 12)
    lazy var weekTimePeriods = generateTimePeriods(for: .week, component: .weekOfYear, count: 26)
    lazy var timePeriods = [yearTimePeriods, monthTimePeriods, weekTimePeriods]

    @Published var activityType: ActivityType = NSUbiquitousKeyValueStore.default.lastViewedActivityType {
        didSet {
            NSUbiquitousKeyValueStore.default.lastViewedActivityType = activityType
            load()
        }
    }

    @Published var timePeriod: TimePeriod
    @Published var viewVisible: Bool = true

    @Published private(set) var graphRenderData: GraphRenderData = GraphRenderData(metrics: [:])
    @Published var selectedGraphMetric: PartialKeyPath<Activity> = \.distanceInUserSelectedUnit
    @Published private(set) var coordinateClusters: [CoordinateCluster] = []
    @Published private(set) var loading: Bool = false
    @Published private(set) var hasPerformedInitialLoad: Bool = false

    private var geocodeCache: [MKMapPoint: String] = NSUbiquitousKeyValueStore.default.geocodeCache {
        didSet {
            NSUbiquitousKeyValueStore.default.geocodeCache = geocodeCache
        }
    }

    private var observers: Set<AnyCancellable> = []

    override init() {
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.month, .year], from: Date()))!
        timePeriod = TimePeriod(timebox: .month, startDate: startOfMonth)

        super.init()

        if let selectedSegment = NSUbiquitousKeyValueStore.default.selectedTimePeriodSegment {
            let selectedIndices = NSUbiquitousKeyValueStore.default.selectedTimePeriodIndices
            timePeriod = timePeriods[selectedSegment][selectedIndices[selectedSegment]]
        }

        load()

        ADUser.current.$distanceUnit
            .sink { [weak self] _ in
                self?.load()
            }.store(in: &observers)

        ActivitiesData.shared.activitiesReloadedPublisher
            .sink { [weak self] _ in
                self?.load()
            }.store(in: &observers)
    }

    private func generateTimePeriods(for timebox: Timebox, 
                                     component: Calendar.Component,
                                     count: Int) -> [TimePeriod] {
        var timePeriods: [TimePeriod] = []
        let calendar = Calendar.current
        var curStart: Date = {
            switch timebox {
            case .year:
                return calendar.date(from: calendar.dateComponents([.year], from: Date()))!
            case .month:
                return calendar.date(from: calendar.dateComponents([.month, .year], from: Date()))!
            case .week:
                guard let monday = calendar.nextWeekend(startingAfter: Date(), direction: .backward)?.end else {
                    return Date()
                }

                if monday.timeIntervalSince(Date()) > 0.0 {
                    return calendar.date(byAdding: .weekOfYear, value: -1, to: monday)!
                } else {
                    return monday
                }
            }
        }()

        for _ in stride(from: 0, to: -1 * count, by: -1) {
            let period = TimePeriod(timebox: timebox, startDate: curStart)
            timePeriods.append(period)
            curStart = calendar.date(byAdding: component, value: -1, to: curStart)!
        }

        return timePeriods
    }

    func load() {
        self.loading = true

        Task(priority: .userInitiated) {
            let store = HealthKitActivitiesStore.shared
            guard let activities = try? await store.getActivities(with: activityType,
                                                                  startDate: timePeriod.prevPeriodStartDate,
                                                                  endDate: timePeriod.endDate) else {
                self.loading = false
                self.hasPerformedInitialLoad = true
                return
            }

            await withTaskGroup(of: Bool.self) { group in
                group.addTask {
                    await self.calculateCoordinateClusters(with: self.timePeriod.startDate,
                                                           endDate: self.timePeriod.endDate,
                                                           activities: activities)
                    return true
                }

                group.addTask {
                    try? await self.calculateGraphData(for: self.timePeriod, 
                                                       activities: activities)
                    return true
                }
            }

            await MainActor.run {
                self.loading = false
                self.hasPerformedInitialLoad = true
            }
        }
    }

    func calculateCoordinateClusters(with startDate: Date, endDate: Date, activities: [Activity]) async {
        let filteredActivities = activities.filter { $0.startDateLocal >= startDate && $0.endDateLocal <= endDate }
        let store = HealthKitActivitiesStore.shared
        let activityCoordinates = (try? await store.getRouteData(for: filteredActivities)) ?? []

        func rect(for coordinates: [CLLocationCoordinate2D]) -> MKMapRect? {
            var minLat: CLLocationDegrees? = coordinates.first?.latitude
            var maxLat: CLLocationDegrees? = coordinates.first?.latitude
            var minLon: CLLocationDegrees? = coordinates.first?.longitude
            var maxLon: CLLocationDegrees? = coordinates.first?.longitude

            coordinates.forEach { coord in
                if coord.latitude < (minLat ?? CLLocationDegrees.greatestFiniteMagnitude) {
                    minLat = coord.latitude
                }
                if coord.latitude > (maxLat ?? 0) {
                    maxLat = coord.latitude
                }
                if coord.longitude < (minLon ?? CLLocationDegrees.greatestFiniteMagnitude) {
                    minLon = coord.longitude
                }
                if coord.longitude > (maxLon ?? 0) {
                    maxLon = coord.longitude
                }
            }

            guard let minLat = minLat,
                  let maxLat = maxLat,
                  let minLon = minLon,
                  let maxLon = maxLon else {
                return nil
            }

            let span = MKCoordinateSpan(latitudeDelta: (maxLat - minLat),
                                        longitudeDelta: (maxLon - minLon))
            let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2,
                                                longitude: ((minLon + maxLon) / 2))
            let region = MKCoordinateRegion(center: center, span: span)
            let rect = region.mapRect()
            return rect
        }

        var clusters: [CoordinateCluster] = []
        for coords in activityCoordinates {
            let rect = rect(for: coords)
            guard let rect = rect, coords.count >= 5 else {
                continue
            }

            if clusters.isEmpty {
                let cluster = CoordinateCluster(geocodedName: "",
                                                coordinates: [coords],
                                                rect: rect)
                clusters.append(cluster)
            } else if let firstCoord = coords.first {
                let mapPoint = MKMapPoint(firstCoord)
                let closestClusterIdx = clusters.firstIndex { cluster in
                    let midPoint = MKMapPoint(x: cluster.rect.midX, y: cluster.rect.midY)
                    let distance = midPoint.distance(to: mapPoint)
                    return distance < CLUSTER_DISTANCE_METERS
                }

                if let closestClusterIdx = closestClusterIdx {
                    clusters[closestClusterIdx].coordinates.append(coords)
                    clusters[closestClusterIdx].rect = clusters[closestClusterIdx].rect.union(rect)
                } else {
                    let cluster = CoordinateCluster(geocodedName: "",
                                                    coordinates: [coords],
                                                    rect: rect)
                    clusters.append(cluster)
                }
            }
        }

        clusters = clusters.sorted(by: { $0.coordinates.count > $1.coordinates.count })

        var copiedGeocodeCache = self.geocodeCache
        let geocoder = CLGeocoder()
        for (idx, cluster) in clusters.enumerated() {
            let mapMidPoint = MKMapPoint(x: cluster.rect.midX, y: cluster.rect.midY)

            var minDistance = CLLocationDistance.greatestFiniteMagnitude
            for key in copiedGeocodeCache.keys {
                let distance = key.distance(to: mapMidPoint)
                if distance < CLUSTER_DISTANCE_METERS && distance < minDistance {
                    clusters[idx].geocodedName = copiedGeocodeCache[key]!
                    minDistance = distance
                }
            }
            if clusters[idx].geocodedName != "" {
                continue
            }

            let midPoint = mapMidPoint.coordinate
            let coord = CLLocation(latitude: midPoint.latitude, longitude: midPoint.longitude)
            let placemarks = try? await geocoder.reverseGeocodeLocation(coord)
            if let firstLocation = placemarks?[0],
               let city = firstLocation.locality {
                clusters[idx].geocodedName = city
                copiedGeocodeCache[mapMidPoint] = city
            }
        }
        geocodeCache = copiedGeocodeCache

        var consolidatedClusters: [CoordinateCluster] = []
        for cluster in clusters {
            if let idx = consolidatedClusters.firstIndex(where: { $0.geocodedName == cluster.geocodedName }) {
                consolidatedClusters[idx].coordinates.append(contentsOf: cluster.coordinates)
                consolidatedClusters[idx].rect = cluster.rect.union(consolidatedClusters[idx].rect)
            } else {
                consolidatedClusters.append(cluster)
            }
        }

        let clustersCopy = consolidatedClusters
        await MainActor.run {
            self.coordinateClusters = clustersCopy
        }
    }

    func calculateGraphData(for timePeriod: TimePeriod, activities: [Activity]) async throws {
        do {
            var fields: [PartialKeyPath<Activity>] {
                if activityType.isDistanceBased {
                    if activityType.shouldShowSpeedInsteadOfPace {
                        return [\.distanceInUserSelectedUnit,
                                \.movingTime,
                                \.elevationGainInUserSelectedUnit,
                                \.activeCalories,
                                \.averageSpeedInUserSelectedUnit]
                    } else {
                        return [\.distanceInUserSelectedUnit,
                                \.movingTime,
                                \.elevationGainInUserSelectedUnit,
                                \.activeCalories,
                                \.paceInUserSelectedUnit]
                    }
                } else {
                    return [\.movingTime,
                            \.activeCalories]
                }
            }

            let store = HealthKitActivitiesStore.shared
            var data = try await store.getHistoricalData(for: activities,
                                                         startDate: timePeriod.startDate,
                                                         endDate: min(Date(), timePeriod.endDate),
                                                         fields: fields)

            var prevPeriodData = try await store.getHistoricalData(for: activities,
                                                                   startDate: timePeriod.prevPeriodStartDate,
                                                                   endDate: timePeriod.prevPeriodEndDate,
                                                                   fields: fields)

            var metrics: [PartialKeyPath<Activity>: GraphRenderDataMetric] = [:]

            func ifNaNZero(_ value: Float) -> Float {
                return value.isNaN ? 0.0 : value
            }

            for field in fields {
                if field == \.movingTime {
                    data[field] = data[field]?.map { $0 / 3600 }
                    prevPeriodData[field] = prevPeriodData[field]?.map { $0 / 3600 }
                }

                let cumulativeData = data[field]?.reduce([], { $0 + [($0.last ?? 0) + $1] }) ?? []
                let cumulativePrevPeriodData = prevPeriodData[field]?.reduce([], { $0 + [($0.last ?? 0) + $1] }) ?? []
                let fullDataCount = max(Int(self.timePeriod.endDate.timeIntervalSince(self.timePeriod.startDate) / 86400.0),
                                        Int(self.timePeriod.prevPeriodEndDate.timeIntervalSince(self.timePeriod.prevPeriodStartDate) / 86400.0))
                let maxValue = max(data[field]?.max() ?? 0.0, prevPeriodData[field]?.max() ?? 0.0)
                let cumulativeMax = max(cumulativeData.last ?? 0.0, cumulativePrevPeriodData.last ?? 0.0)
                let total = data[field]?.sum() ?? 0.0

                let dataAvg = ifNaNZero(data[field]!.filter({ $0 != 0.0 }).avg())
                let prevPeriodDataAvg = ifNaNZero(prevPeriodData[field]!.filter({ $0 != 0.0 }).avg())

                let averagePercentDifference = ifNaNZero(((dataAvg / prevPeriodDataAvg) - 1.0).clamped(to: -10.0...10.0))
                let cumulativePercentDifference: Float = {
                    guard !cumulativeData.isEmpty && !cumulativePrevPeriodData.isEmpty else {
                        return 0.0
                    }

                    let dataIdx = cumulativeData.count > cumulativePrevPeriodData.count ? (cumulativePrevPeriodData.count - 1) : (cumulativeData.count - 1)

                    if (cumulativeData[dataIdx]) == 0.0 && cumulativePrevPeriodData[dataIdx] == 0.0 {
                        return 0.0
                    }

                    return (((cumulativeData[dataIdx]) / (cumulativePrevPeriodData[dataIdx]).clamped(to: 0.01...Float.greatestFiniteMagnitude)) - 1.0)
                        .clamped(to: -10.0...10.0)
                }()

                var graphData: [Float] = data[field]?.reduce([Float](), { $0 + [$1 == 0.0 ? ($0.last ?? 0) : $1] }) ?? []
                var prevPeriodGraphData: [Float] = prevPeriodData[field]?.reduce([Float](), { $0 + [$1 == 0.0 ? ($0.last ?? 0) : $1] }) ?? []

                if field == \.paceInUserSelectedUnit || field == \.averageSpeedInUserSelectedUnit {
                    // Make sure there are no zeroes at the start
                    var firstNonZeroIdx = graphData.firstIndex(where: { !$0.isZero }) ?? 0
                    (0..<firstNonZeroIdx).forEach { idx in
                        graphData[idx] = graphData[firstNonZeroIdx]
                    }

                    firstNonZeroIdx = prevPeriodGraphData.firstIndex(where: { !$0.isZero }) ?? 0
                    (0..<firstNonZeroIdx).forEach { idx in
                        prevPeriodGraphData[idx] = prevPeriodGraphData[firstNonZeroIdx]
                    }
                }

                let metric = GraphRenderDataMetric(field: field,
                                                   fullDataCount: fullDataCount,
                                                   data: graphData,
                                                   prevPeriodData: prevPeriodGraphData,
                                                   cumulativeData: cumulativeData,
                                                   prevPeriodCumulativeData: cumulativePrevPeriodData,
                                                   max: maxValue,
                                                   cumulativeMax: cumulativeMax,
                                                   total: total,
                                                   avg: dataAvg,
                                                   prevPeriodAvg: prevPeriodDataAvg,
                                                   avgPercentDifference: averagePercentDifference,
                                                   cumulativePercentDifference: cumulativePercentDifference)
                metrics[field] = metric
            }

            let threadSafeMetrics = metrics
            DispatchQueue.main.async {
                self.graphRenderData = GraphRenderData(timebox: timePeriod.timebox,
                                                       metrics: threadSafeMetrics)

                if !threadSafeMetrics.keys.contains(self.selectedGraphMetric) {
                    self.selectedGraphMetric = threadSafeMetrics.keys.contains(\.paceInUserSelectedUnit) ? \.paceInUserSelectedUnit :  \.averageSpeedInUserSelectedUnit
                }
                self.loading = false
            }
        }
    }
}

extension ActivityProgressGraphModel {
    enum Timebox: Int, Codable {
        case year
        case month
        case week

        func xLabel(for dataPointIdx: Int) -> String? {
            switch self {
            case .week:
                return ["M", "T", "W", "T", "F", "S", "S"][safe: dataPointIdx]
            case .month:
                return (dataPointIdx % 7 == 0) ? String(dataPointIdx + 1) : nil
            case .year:
                switch dataPointIdx {
                case 0:
                    return "J"
                case 31:
                    return "F"
                case 59:
                    return "M"
                case 90:
                    return "A"
                case 120:
                    return "M"
                case 151:
                    return "J"
                case 181:
                    return "J"
                case 212:
                    return "A"
                case 243:
                    return "S"
                case 273:
                    return "O"
                case 304:
                    return "N"
                case 335:
                    return "D"
                default:
                    return nil
                }
            }
        }

        var displayName: String {
            switch self {
            case .week:
                return "week"
            case .month:
                return "month"
            case .year:
                return "year"
            }
        }
    }

    struct TimePeriod: Equatable, Codable {
        var timebox: Timebox
        var startDate: Date
        var endDate: Date!
        var prevPeriodStartDate: Date!
        var prevPeriodEndDate: Date!
        var label: String!

        var calendarComponent: Calendar.Component {
            switch timebox {
            case .year:
                return .year
            case .month:
                return .month
            case .week:
                return .weekOfYear
            }
        }

        init(timebox: Timebox, startDate: Date) {
            self.timebox = timebox
            self.startDate = startDate
            self.endDate = Calendar.current.date(byAdding: calendarComponent, value: 1, to: startDate)!
            self.prevPeriodStartDate = Calendar.current.date(byAdding: calendarComponent, value: -1, to: startDate)!
            self.prevPeriodEndDate = Calendar.current.date(byAdding: calendarComponent, value: -1, to: endDate)!
            self.label = {
                let calendar = Calendar.current
                switch timebox {
                case .year:
                    let yearComponent = calendar.component(.year, from: startDate)
                    if yearComponent == calendar.component(.year, from: Date()) {
                        return "This Year"
                    } else {
                        return String(yearComponent)
                    }
                case .month:
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "MMMM YYYY"
                    let monthName = dateFormatter.string(from: startDate)
                    if monthName == dateFormatter.string(from: Date()) {
                        return "This Month"
                    } else {
                        return monthName
                    }
                case .week:
                    if calendar.date(byAdding: .weekOfYear, value: -1, to: Date())! < startDate {
                        return "This Week"
                    } else {
                        return "\(startDate.formatted(withFormat: "M/d/YY")) – \(endDate.formatted(withFormat: "M/d/YY"))"
                    }
                }
            }()
        }

        var requiresSuperDistance: Bool {
            return label != "This Month" && label != "This Week"
        }
    }

    struct GraphRenderData {
        private(set) var id: String = UUID().uuidString
        private(set) var timebox: Timebox = .week
        private(set) var metrics: [PartialKeyPath<Activity>: GraphRenderDataMetric]
    }

    struct GraphRenderDataMetric {
        private(set) var field: PartialKeyPath<Activity>
        private(set) var fullDataCount: Int
        private(set) var data: [Float]
        private(set) var prevPeriodData: [Float]
        private(set) var cumulativeData: [Float]
        private(set) var prevPeriodCumulativeData: [Float]
        private(set) var max: Float
        private(set) var cumulativeMax: Float
        private(set) var total: Float
        private(set) var avg: Float
        private(set) var prevPeriodAvg: Float
        private(set) var avgPercentDifference: Float
        private(set) var cumulativePercentDifference: Float

        var isEmpty: Bool {
            return !defaultData.contains(where: { $0 != 0.0 }) &&
                   !prevPeriodData.contains(where: { $0 != 0.0})
        }

        var defaultsToCumulative: Bool {
            if field == \.paceInUserSelectedUnit || field == \.averageSpeedInUserSelectedUnit {
                return false
            }
            return true
        }

        var defaultData: [Float] {
            return defaultsToCumulative ? cumulativeData : data
        }

        var defaultPrevPeriodData: [Float] {
            return defaultsToCumulative ? prevPeriodCumulativeData : prevPeriodData
        }

        var defaultPercentDifference: Float {
            return defaultsToCumulative ? cumulativePercentDifference : avgPercentDifference
        }

        var defaultMaxValue: Float {
            return defaultsToCumulative ? cumulativeMax : max
        }

        var defaultDisplayMetric: Float {
            return defaultsToCumulative ? total : avg
        }

        func dataFormat(_ value: Float) -> String {
            if field == \.paceInUserSelectedUnit {
                return TimeInterval(value).timeFormatted() + field.unit
            } else if field == \.movingTime {
                let hours = Int(value)
                let minutes = Int(60 * (value.truncatingRemainder(dividingBy: 1)))
                var str = ""
                if hours > 0 {
                    str += "\(hours)hr "
                }
                str += "\(minutes)min"

                return str
            } else if field == \.activeCalories || field == \.elevationGainInUserSelectedUnit {
                return String(Int(value.rounded())) + field.unit.lowercased()
            } else {
                return String(value.rounded(toPlaces: 1)) + field.unit.lowercased()
            }
        }

        var formattedDisplayMetric: String {
            if field == \.paceInUserSelectedUnit {
                return TimeInterval(defaultDisplayMetric).timeFormatted()
            } else if field == \.activeCalories ||
                      field == \.elevationGainInUserSelectedUnit {
                return String(Int(defaultDisplayMetric.rounded()))
            } else {
                return String(defaultDisplayMetric.rounded(toPlaces: 1))
            }
        }
    }

    struct CoordinateCluster {
        var geocodedName: String
        var coordinates: [[CLLocationCoordinate2D]] = []
        var rect: MKMapRect
    }
}

extension ActivityProgressGraphModel {
    static func color(for percent: Float,
                      selected: Bool = false,
                      field: PartialKeyPath<Activity>) -> Color {
        let green = selected ? Color(uiColor: Color.goalGreen.toUIColor()!.darker(by: 35)!) : Color.goalGreen
        let orange = selected ? Color(uiColor: Color.goalOrange.toUIColor()!.darker(by: 20)!) : Color.goalOrange
        let yellow = selected ? Color(uiColor: UIColor.adYellow.darker(by: 25)!) : Color.adYellow
        let percent = field == \.paceInUserSelectedUnit || field == \.averageSpeedInUserSelectedUnit ? -1 * percent : percent

        switch percent {
        case 0.0:
            return selected ? .black : .white
        case 0.0...0.25:
            return green
        case -0.25...0.0:
            return yellow
        default:
            return percent > 0.0 ? green : orange
        }
    }
}

extension MKMapPoint: Hashable {
    public static func == (lhs: MKMapPoint, rhs: MKMapPoint) -> Bool {
        return lhs.x == rhs.x && lhs.y == rhs.y
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.x)
        hasher.combine(self.y)
    }
}

extension PartialKeyPath<Activity> {
    var displayName: String {
        if self == \.distanceInUserSelectedUnit {
            return "DISTANCE"
        } else if self == \.movingTime {
            return "MOVING TIME"
        } else if self == \.elevationGainInUserSelectedUnit {
            return "ELEVATION GAIN"
        } else if self == \.activeCalories {
            return "ENERGY BURNED"
        } else if self == \.paceInUserSelectedUnit {
            return "AVG PACE"
        } else if self == \.averageSpeedInUserSelectedUnit {
            return "AVG SPEED"
        } else {
            return ""
        }
    }

    var unit: String {
        if self == \.distanceInUserSelectedUnit {
            return ADUser.current.distanceUnit.abbreviation
        } else if self == \.movingTime {
            return "hr"
        } else if self == \.elevationGainInUserSelectedUnit {
            return ADUser.current.distanceUnit == .miles ? "ft" : "m"
        } else if self == \.activeCalories {
            return "cal"
        } else if self == \.paceInUserSelectedUnit {
            return "/" + ADUser.current.distanceUnit.abbreviation
        } else if self == \.averageSpeedInUserSelectedUnit {
            return ADUser.current.distanceUnit == .miles ? "mph" : "km/h"
        } else {
            return ""
        }
    }

    var sortOrder: Int {
        if self == \.distanceInUserSelectedUnit {
            return 0
        } else if self == \.movingTime {
            return 1
        } else if self == \.elevationGainInUserSelectedUnit {
            return 2
        } else if self == \.activeCalories {
            return 3
        } else if self == \.paceInUserSelectedUnit {
            return 4
        } else if self == \.averageSpeedInUserSelectedUnit {
            return 5
        } else {
            return 10
        }
    }
}

extension NSUbiquitousKeyValueStore {
    var selectedTimePeriodSegment: Int? {
        get {
            return object(forKey: "selectedTimePeriodSegment") as? Int
        }

        set {
            set(newValue, forKey: "selectedTimePeriodSegment")
        }
    }

    var selectedTimePeriodIndices: [Int] {
        get {
            if let array = object(forKey: "selectedTimePeriodIndices") as? [Int] {
                return array
            }
            return [0, 0, 0]
        }

        set {
            set(newValue, forKey: "selectedTimePeriodIndices")
        }
    }
}

fileprivate extension NSUbiquitousKeyValueStore {
    var lastViewedActivityType: ActivityType {
        get {
            if let type = ActivityType(rawValue: string(forKey: "lastViewedActivityType") ?? "") {
                return type
            }

            return ActivitiesData.shared.activities
                .map { $0.activity }
                .filter { $0.activityType != .stepCount }
                .first?.activityType ?? .walk
        }

        set {
            set(newValue.rawValue, forKey: "lastViewedActivityType")
        }
    }

    var geocodeCache: [MKMapPoint: String] {
        get {
            if let data = data(forKey: "geocodeCache") {
                return (try? JSONDecoder().decode([MKMapPoint: String].self, from: data)) ?? [:]
            }
            return [:]
        }

        set {
            if let encoded = try? JSONEncoder().encode(newValue) {
                set(encoded, forKey: "geocodeCache")
            }
        }
    }
}

extension MKMapPoint: Codable {
    enum CodingKeys: String, CodingKey {
        case x
        case y
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.x, forKey: .x)
        try container.encode(self.y, forKey: .y)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let x = try container.decode(Double.self, forKey: .x)
        let y = try container.decode(Double.self, forKey: .y)
        self.init(x: x, y: y)
    }
}
