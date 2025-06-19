// Licensed under the Any Distance Source-Available License
//
//  ADUser.swift
//  ADAC
//
//  Created by Daniel Kuntz on 12/21/20.
//

import Foundation
import CloudKit
import BetterCodable
import Combine
import OneSignal
import Sentry
import Combine
import Mixpanel

class ADUser: NSObject, ObservableObject, Codable {
    typealias ID = String
    typealias AppleSignInID = String

    @Published var id: ID = ""
    @Published var createdAt: Date?
    @Published var appleSignInID: AppleSignInID = ""
    @Published var name: String = ""
    @Published var email: String = ""
    @Published var wantsToBeEmailed: Bool = false
    @Published var distanceUnit: DistanceUnit = .miles
    @Published var signupDate: Date?
    @Published var lastCollectiblesRefreshDate: Date?
    @Published var lastGoalRefreshDate: Date?
    @Published var lastTotalDistanceRefreshDate: Date?
    @Published var lastTotalTimeRefreshDate: Date?
    @Published var goals: [Goal] = []
    @Published var gear: [Gear] = []
    @Published var collectibles: [Collectible] = []
    @Published var totalDistanceTrackedMeters: Double?
    @Published var totalTimeTracked: TimeInterval = 0
    @Published var subscriptionProductID: String?
    @Published var username: String?
    @Published var bio: String = ""
    @Published var phoneNumber: String?
    @Published var location: String = ""
    @Published var profilePhotoUrl: URL?
    @Published var coverPhotoUrl: URL?
    @Published var recentActivityTypes: [ActivityType] = []
    @Published var allowsTags: Bool = true
    @Published var notificationTags: [String]?
    @Published var friendIDs: [ADUser.ID] = []
    @Published var blockedIDs: [ADUser.ID] = []
    @Published var friendships: [Friendship] = []

    static var current: ADUser = NSUbiquitousKeyValueStore.default.currentUser
    private var subscribers: Set<AnyCancellable> = []

    // MARK: - Codable

    override init() {
        super.init()
        self.observeSelf()
    }

    private func observeSelf() {
        objectWillChange
            .receive(on: DispatchQueue.main)
            .throttle(for: 1.0, scheduler: RunLoop.main, latest: true)
            .sink { _ in
                if self === ADUser.current {
                    self.saveToUserDefaults()
                }
            }
            .store(in: &subscribers)

        $friendIDs
            .receive(on: DispatchQueue.main)
            .throttle(for: 1.0, scheduler: RunLoop.main, latest: true)
            .sink { _ in
                if self === ADUser.current {
                    UserManager.shared.initializeConnectedServices()
                    Mixpanel.mainInstance().people
                        .set(properties: [
                        "numFriends": ADUser.current.friendIDs.count,
                        "numInvitesSent": NSUbiquitousKeyValueStore.default.invitedPhoneNumbers.count
                    ])
                    OneSignal.sendTag("num_friends", value: "\(ADUser.current.friendIDs.count)")
                }
            }
            .store(in: &subscribers)
    }

    func saveToUserDefaults() {
        print("Updating current user in UserDefaults")
        NSUbiquitousKeyValueStore.default.currentUser = self
        UserDefaults.appGroup.goalActivityType = self.goals.first?.activityType ?? .run
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: ADUserCodingKeys.self)
        try container.encode(self.id, forKey: .id)
        try container.encode(self.createdAt, forKey: .createdAt)
        try container.encode(self.appleSignInID, forKey: .appleSignInID)
        try container.encode(self.name, forKey: .name)
        try container.encode(self.email, forKey: .email)
        try container.encode(self.wantsToBeEmailed, forKey: .wantsToBeEmailed)
        try container.encode(self.distanceUnit, forKey: .distanceUnit)
        try container.encodeIfPresent(self.signupDate, forKey: .signupDate)
        try container.encodeIfPresent(self.lastCollectiblesRefreshDate, forKey: .lastCollectiblesRefreshDate)
        try container.encodeIfPresent(self.lastGoalRefreshDate, forKey: .lastGoalRefreshDate)
        try container.encodeIfPresent(self.lastTotalDistanceRefreshDate, forKey: .lastTotalDistanceRefreshDate)
        try container.encodeIfPresent(self.lastTotalTimeRefreshDate, forKey: .lastTotalTimeRefreshDate)
        try container.encode(self.goals, forKey: .goals)
        try container.encode(self.gear, forKey: .gear)
        try container.encode(self.collectibles, forKey: .collectibles)
        try container.encodeIfPresent(self.totalDistanceTrackedMeters, forKey: .totalDistanceTrackedMeters)
        try container.encodeIfPresent(self.totalTimeTracked, forKey: .totalTimeTracked)
        try container.encodeIfPresent(self.subscriptionProductID, forKey: .subscriptionProductID)
        try container.encodeIfPresent(self.username, forKey: .username)
        try container.encode(self.bio, forKey: .bio)
        try container.encodeIfPresent(self.phoneNumber, forKey: .phoneNumber)
        try container.encode(self.location, forKey: .location)
        try container.encodeIfPresent(self.profilePhotoUrl, forKey: .profilePhotoUrl)
        try container.encodeIfPresent(self.coverPhotoUrl, forKey: .coverPhotoUrl)
        try container.encode(self.recentActivityTypes, forKey: .recentActivityTypes)
        try container.encode(self.allowsTags, forKey: .allowsTags)
        try container.encode(self.notificationTags, forKey: .notificationTags)
        try container.encode(self.friendIDs, forKey: .friendIDs)
        try container.encode(self.blockedIDs, forKey: .blockedIDs)
        try container.encode(self.friendships, forKey: .friendships)
    }

    required init(from decoder: Decoder) throws {
        super.init()
        self.observeSelf()
        let container = try decoder.container(keyedBy: ADUserCodingKeys.self)

        if let appleSignInID = (try? container.decode(AppleSignInID.self, forKey: .appleSignInID)) {
            // "id" and "appleSignInID" were correctly encoded to their respective keys, meaning
            // this user has migrated to Edge.
            self.appleSignInID = appleSignInID
            self.id = (try? container.decode(ID.self, forKey: .id)) ?? id
        } else {
            // "appleSignInID" was previously encoded as "id". This is a legacy CloudKit user.
            self.appleSignInID = (try? container.decode(String.self, forKey: .id)) ?? appleSignInID
            self.id = ""
        }

        self.createdAt = (try? container.decode(Date.self, forKey: .createdAt)) ?? createdAt
        self.appleSignInID = (try? container.decode(String.self, forKey: .appleSignInID)) ?? appleSignInID
        self.name = (try? container.decode(String.self, forKey: .name)) ?? name
        self.email = (try? container.decode(String.self, forKey: .email)) ?? email
        self.wantsToBeEmailed = (try? container.decode(Bool.self, forKey: .wantsToBeEmailed)) ?? wantsToBeEmailed

        for key in ADUserCodingKeys.distanceUnit.possibleKeyNames {
            do {
                self.distanceUnit = try container.decode(DistanceUnit.self, forKey: key)
            } catch {
                continue
            }
            break
        }

        self.signupDate = try? container.decodeIfPresent(Date.self, forKey: .signupDate)

        for key in ADUserCodingKeys.lastCollectiblesRefreshDate.possibleKeyNames {
            do {
                self.lastCollectiblesRefreshDate = try container.decode(Date.self, forKey: key)
            } catch {
                continue
            }
            break
        }

        self.lastGoalRefreshDate = try? container.decodeIfPresent(Date.self, forKey: .lastGoalRefreshDate)
        self.lastTotalDistanceRefreshDate = try? container.decodeIfPresent(Date.self, forKey: .lastTotalDistanceRefreshDate)
        self.lastTotalTimeRefreshDate = try? container.decodeIfPresent(Date.self, forKey: .lastTotalTimeRefreshDate)
        self.goals = (try? container.decode([Goal].self, forKey: .goals)) ?? goals
        self.gear = (try? container.decode([Gear].self, forKey: .gear)) ?? gear

        for key in ADUserCodingKeys.collectibles.possibleKeyNames {
            do {
                self.collectibles = try container.decode([FailableDecodable<Collectible>].self,
                                                         forKey: key).compactMap { $0.base }
            } catch {
                continue
            }
            break
        }

        self.totalDistanceTrackedMeters = try? container.decodeIfPresent(Double.self, forKey: .totalDistanceTrackedMeters)
        self.totalTimeTracked = (try? container.decodeIfPresent(TimeInterval.self, forKey: .totalTimeTracked)) ?? calculateTotalTimeTracked()
        self.subscriptionProductID = try? container.decodeIfPresent(String.self, forKey: .subscriptionProductID)
        self.username = try? container.decodeIfPresent(String.self, forKey: .username)
        self.bio = (try? container.decodeIfPresent(String.self, forKey: .bio)) ?? bio
        self.phoneNumber = try? container.decodeIfPresent(String.self, forKey: .phoneNumber)
        self.location = (try? container.decodeIfPresent(String.self, forKey: .location)) ?? location
        self.profilePhotoUrl = try? container.decodeIfPresent(URL.self, forKey: .profilePhotoUrl)
        self.coverPhotoUrl = try? container.decodeIfPresent(URL.self, forKey: .coverPhotoUrl)
        self.recentActivityTypes = (try? container.decode([ActivityType].self, forKey: .recentActivityTypes)) ?? recentActivityTypes
        self.allowsTags = (try? container.decodeIfPresent(Bool.self, forKey: .allowsTags)) ?? allowsTags
        self.notificationTags = (try? container.decodeIfPresent([String].self, forKey: .notificationTags)) ?? notificationTags
        self.friendIDs = (try? container.decodeIfPresent([ID].self, forKey: .friendIDs)) ?? friendIDs
        self.blockedIDs = (try? container.decodeIfPresent([ID].self, forKey: .blockedIDs)) ?? blockedIDs
        self.friendships = (try? container.decodeIfPresent([Friendship].self, forKey: .friendships)) ?? friendships
    }

    func setRandomCoverPhotoIfNecessary(pushChanges: Bool) async {
        if self.coverPhotoUrl == nil {
            self.coverPhotoUrl = S3.randomCoverPhotoURL()
            if pushChanges {
                await UserManager.shared.updateCurrentUser()
            }
        }
    }
}

enum ADUserCodingKeys: String, CodingKey, CaseIterable {
    case id
    case createdAt
    case appleSignInID
    case name
    case email
    case wantsToBeEmailed
    case distanceUnit
    case signupDate
    case lastCollectiblesRefreshDate
    case lastGoalRefreshDate
    case lastTotalDistanceRefreshDate
    case lastTotalTimeRefreshDate
    case goals
    case gear
    case collectibles
    case totalDistanceTrackedMeters
    case totalTimeTracked
    case subscriptionProductID
    case username
    case bio
    case phoneNumber
    case location
    case profilePhotoUrl
    case coverPhotoUrl
    case recentActivityTypes
    case allowsTags
    case notificationTags
    case friendIDs
    case blockedIDs
    case friendships

    // Old Keys
    case goalUnit
    case _achievements
    case lastAchievementRefreshDate

    var possibleKeyNames: [ADUserCodingKeys] {
        switch self {
        case .distanceUnit:
            return [self] + [.goalUnit]
        case .collectibles:
            return [self] + [._achievements]
        case .lastCollectiblesRefreshDate:
            return [self] + [.lastAchievementRefreshDate]
        default:
            return []
        }
    }
}

struct FailableDecodable<Base: Codable>: Codable {
    let base: Base?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.base = try? container.decode(Base.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(base)
    }
}

// MARK: - Misc Utility Functions

extension ADUser {
    static let teamAppleSignInIDs: [AppleSignInID] = []

    static let teamCanonicalIDs: [AppleSignInID] = []

    var hasRegistered: Bool {
        return (!id.contains("anon") && !id.isEmpty)
    }

    var hasFinishedOnboarding: Bool {
        get {
            let hasAccount = !id.isEmpty && !(username ?? "").isEmpty && !(phoneNumber ?? "").isEmpty
            return hasAccount || UserDefaults.standard.bool(forKey: "hasFinishedOnboarding")
        }

        set {
            UserDefaults.standard.set(newValue, forKey: "hasFinishedOnboarding")
        }
    }

    var isTeamADAC: Bool {
        return ADUser.teamAppleSignInIDs.contains(appleSignInID)
    }

    var isSelf: Bool {
        return ADUser.current.appleSignInID == self.appleSignInID
    }

    var isFriend: Bool {
        return ADUser.current.friendIDs.contains(id)
    }

    var isBlocked: Bool {
        return ADUser.current.blockedIDs.contains(id)
    }

    var hasRequestedYou: Bool {
        return ADUser.current.friendships.contains {
            $0.isPending &&
            $0.requestingUserID == self.id &&
            $0.targetUserID == ADUser.current.id
        }
    }

    var youRequestedThem: Bool {
        return ADUser.current.friendships.contains {
            $0.isPending &&
            $0.requestingUserID == ADUser.current.id &&
            $0.targetUserID == self.id
        }
    }

    var receivedRequests: [Friendship] {
        return friendships.filter { friendship in
            friendship.targetUserID == ADUser.current.id && friendship.isPending
        }
    }

    var sentRequests: [Friendship] {
        return friendships.filter { friendship in
            friendship.requestingUserID == ADUser.current.id && friendship.isPending
        }
    }

    var pendingFriendships: [Friendship] {
        return friendships.filter { $0.isPending }
    }

    var activeClubNotificationSettings: ActiveClubNotificationSettings {
        get {
            return ActiveClubNotificationSettings(notificationTags: notificationTags ?? [])
        }

        set {
            notificationTags = newValue.notificationTags()
        }
    }

    /// Returns the total distance tracked in Mi or Km since the user signed up for Any Distance.
    var totalDistanceTracked: Float {
        if let distanceMeters = totalDistanceTrackedMeters {
            return UnitConverter.meters(Float(distanceMeters), toUnit: distanceUnit)
        }

        let calculatedDistanceMeters = calculatedTotalDistanceTracked()
        return UnitConverter.meters(calculatedDistanceMeters, toUnit: distanceUnit)
    }

    var visibleCollectibles: [Collectible] {
        return collectibles.filter { collectible in
            switch collectible.type {
            case .remoteUnknown(_):
                return false
            case .remote(let remote):
                if remote.sectionName == "Collaborations" && !NSUbiquitousKeyValueStore.default.shouldShowCollaborationCollectibles {
                    return false
                }
                return true
            default:
                return true
            }
        }
    }

    var initials: String {
        return name
            .components(separatedBy: .whitespaces)
            .reduce("") { $0 + String($1.first ?? Character(" ")).uppercased() }
            .trimmingCharacters(in: .whitespaces)
    }

    var firstName: String {
        return name.components(separatedBy: .whitespaces).first ?? name
    }

    var massUnit: MassUnit {
        return distanceUnit == .kilometers ? .kilograms : .pounds
    }

    func medals(first n: Int? = nil, unique: Bool = false) -> [Collectible] {
        if unique {
            var collectibles: [Collectible] = []
            var idx: Int = 0
            while (collectibles.count < n ?? Int.max && idx < self.collectibles.count) {
                if !collectibles.contains(where: { $0.type.rawValue == self.collectibles[idx].type.rawValue }) &&
                   self.collectibles[idx].itemType == .medal {
                    collectibles.append(self.collectibles[idx])
                }
                idx += 1
            }
            return collectibles
        }

        return Array(collectibles
                .filter { $0.medalImageUrl != nil }
                .prefix(n ?? Int.max))
    }

    func collectibles(for activity: Activity) -> [Collectible] {
        return collectibles.filter { $0.dateEarned == activity.startDateLocal.addingTimeInterval(1) }
    }

    func updateTotalDistanceTracked(for activities: [Activity]) {
        if lastTotalDistanceRefreshDate == nil {
            lastTotalDistanceRefreshDate = activities.first?.startDateLocal.addingTimeInterval(1.0)
        }

        let lastRefresh = lastTotalDistanceRefreshDate ?? Date(timeIntervalSince1970: 0)
        if let currentDistance = totalDistanceTrackedMeters {
            let latestActivities = activities.filter { $0.startDateLocal > lastRefresh }
            let distanceToAdd = latestActivities.reduce(0, { $0 + $1.distance })
            totalDistanceTrackedMeters = currentDistance + Double(distanceToAdd)
        } else {
            totalDistanceTrackedMeters = Double(calculatedTotalDistanceTracked())
        }

        OneSignal.sendTag("total_distance", value: "\(totalDistanceTrackedMeters ?? 0.0)")
        lastTotalDistanceRefreshDate = activities.first?.startDateLocal.addingTimeInterval(1.0) ?? lastTotalDistanceRefreshDate
    }

    func updateTotalTimeTracked(for activities: [Activity]) {
        if lastTotalTimeRefreshDate == nil {
            lastTotalTimeRefreshDate = activities.first?.startDateLocal.addingTimeInterval(1.0)
        }

        let lastRefresh = lastTotalTimeRefreshDate ?? Date(timeIntervalSince1970: 0)
        let latestActivities = activities.filter { $0.startDateLocal > lastRefresh }
        let timeToAdd = latestActivities.reduce(0, { $0 + $1.movingTime })
        totalTimeTracked += timeToAdd

        OneSignal.sendTag("total_time", value: "\(totalTimeTracked)")
        lastTotalTimeRefreshDate = activities.first?.startDateLocal.addingTimeInterval(1.0) ?? lastTotalTimeRefreshDate
    }

    func updateGear(for activities: [Activity]) {
        if NSUbiquitousKeyValueStore.default.lastGearRefreshDate == nil {
            NSUbiquitousKeyValueStore.default.lastGearRefreshDate = activities.first?.startDateLocal.addingTimeInterval(1.0)
        }

        let selectedGear = NSUbiquitousKeyValueStore.default.selectedGearForTypes
        let selectedShoes = selectedGear[.shoes]
        guard let selectedShoes = selectedShoes else {
            return
        }

        let lastRefresh = NSUbiquitousKeyValueStore.default.lastGearRefreshDate ?? Date()
        var latestActivities = activities.filter { activity in
            return activity.startDateLocal > lastRefresh &&
                   activity.activityType.matches(gearType: .shoes) &&
                   activity.gearIDs.isEmpty
        }

        for i in 0..<latestActivities.count {
            latestActivities[i].gearIDs = [selectedShoes]
        }

        NSUbiquitousKeyValueStore.default.lastGearRefreshDate = activities.first?.startDateLocal.addingTimeInterval(1.0) ?? NSUbiquitousKeyValueStore.default.lastGearRefreshDate
    }

    func goalToDisplay(forActivity activity: Activity) -> Goal? {
        let activeGoals = goals.filter { goal in
            return goal.activityType == activity.activityType && !goal.isCompleted
        }

        let firstEndingActiveGoal = activeGoals.sorted(by: { $0.endDate < $1.endDate }).first

        let firstCompletedGoalWithinOneDay = goals.filter { goal in
            let oneDay: TimeInterval = 60 * 60 * 24
            return goal.activityType == activity.activityType &&
            goal.isCompleted &&
            Date().timeIntervalSince(goal.endDate) < oneDay
        }.first

        return firstCompletedGoalWithinOneDay ?? firstEndingActiveGoal
    }

    private func calculatedTotalDistanceTracked() -> Float {
        let activities = ActivitiesData.shared.activities
            .map { $0.activity }
            .filter { !($0 is DailyStepCount) }
            .filter { $0.startDateLocal > (signupDate ?? Date(timeIntervalSince1970: 0)) }
        return activities.reduce(0, { $0 + ($1.distance) })
    }

    func calculateTotalTimeTracked() -> TimeInterval {
        let activities = ActivitiesData.shared.activities
            .map { $0.activity }
            .filter { !($0 is DailyStepCount) }
            .filter { $0.startDateLocal > (signupDate ?? Date(timeIntervalSince1970: 0)) }
        return activities.reduce(0, { $0 + ($1.movingTime) })
    }

    func hasBetaMedal() -> Bool {
        return collectibles.contains(where: { $0.description == SpecialMedal.beta.description })
    }

    func setAnonID() {
        let uuidSuffix = "_" + (DeviceIdentifier.getUUID() ?? "")
        self.id = "anon" + uuidSuffix
    }

    func nextMilestone() -> Milestone? {
        if totalDistanceTrackedMeters == 0 {
            return Milestone.trackFirstActivity
        } else if goals.count == 0 {
            return Milestone.setGoal
        } else if (!collectibles.contains(where: { $0.type == .activity(.mi_1) }) && distanceUnit == .miles) ||
                  (!collectibles.contains(where: { $0.type == .activity(.km_1) }) && distanceUnit == .kilometers) {
            return Milestone.track1(unit: distanceUnit)
        } else if !collectibles.contains(where: { $0.type == .activity(.k_5) }) {
            return Milestone.track5k()
        } else if totalDistanceTracked < 100 {
            return Milestone.track100(unit: distanceUnit)
        }

        return nil
    }
}

extension Collection where Element: ADUser {
    var sortedByUsername: [ADUser] {
        return self.sorted(by: { ($0.username ?? "") < ($1.username ?? "") })
    }
}

// MARK: - CloudKit

extension ADUser {
    var ckRecord: CKRecord {
        let recordId = CKRecord.ID(recordName: appleSignInID)
        let record = CKRecord(recordType: "ADUser", recordID: recordId)
        record["name"] = name
        record["email"] = email
        record["wantsToBeEmailed"] = wantsToBeEmailed
        record["goalUnit"] = distanceUnit.rawValue
        record["lastAchievementRefreshDate"] = lastCollectiblesRefreshDate
        record["lastGoalRefreshDate"] = lastGoalRefreshDate
        record["lastTotalDistanceRefreshDate"] = lastTotalDistanceRefreshDate
        record.encode(goals, toKey: "goals")
        record.encode(collectibles, toKey: "achievements")
        record["totalDistanceTrackedMeters"] = totalDistanceTrackedMeters
        record["subscriptionProductID"] = subscriptionProductID
        record["username"] = username
        record["bio"] = bio
        record["phoneNumber"] = phoneNumber
        record["location"] = location
        record["profilePhotoUrl"] = profilePhotoUrl?.absoluteString
        record["coverPhotoUrl"] = coverPhotoUrl?.absoluteString
        record.encodeArray(recentActivityTypes, toKey: "recentActivityTypes")
        record["allowsTags"] = allowsTags

        return record
    }

    convenience init(ckRecord record: CKRecord) {
        self.init()
        id = ""
        appleSignInID = record.recordID.recordName
        name = record["name"] as? String ?? name
        email = record["email"] as? String ?? email
        wantsToBeEmailed = record["wantsToBeEmailed"] as? Bool ?? wantsToBeEmailed
        distanceUnit = DistanceUnit(rawValue: record["goalUnit"] as? Int ?? 0) ?? .miles
        lastCollectiblesRefreshDate = record["lastAchievementRefreshDate"] as? Date
        lastGoalRefreshDate = record["lastGoalRefreshDate"] as? Date
        lastTotalDistanceRefreshDate = record["lastTotalDistanceRefreshDate"] as? Date
        goals = record.decode(fromKey: "goals", asType: [Goal].self) ?? goals
        collectibles = record.decode(fromKey: "achievements",
                                     asType: [FailableDecodable<Collectible>].self)?.compactMap { $0.base } ?? []
        signupDate = record.creationDate
        totalDistanceTrackedMeters = record["totalDistanceTrackedMeters"] as? Double
        subscriptionProductID = record["subscriptionProductID"] as? String
        username = record["username"] as? String
        bio = record["bio"] as? String ?? bio
        phoneNumber = record["phoneNumber"] as? String
        location = record["location"] as? String ?? location
        profilePhotoUrl = URL(string: record["profilePhotoUrl"] as? String)
        coverPhotoUrl = URL(string: record["coverPhotoUrl"] as? String)
        recentActivityTypes = record.decodeArray(fromKey: "recentActivityTypes",
                                                 asType: ActivityType.self)
        allowsTags = record["allowsTags"] as? Bool ?? allowsTags
    }
}
