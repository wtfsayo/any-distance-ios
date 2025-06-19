// Licensed under the Any Distance Source-Available License
//
//  UserManager.swift
//  ADAC
//
//  Created by Daniel Kuntz on 3/3/23.
//

import Foundation
import Cache
import SwiftyJSON
import Mixpanel
import Sentry
import OneSignal
import StringMetric
import WatchConnectivity

class UserManager {

    static let shared = UserManager()
    private var hasInitializedMixpanel: Bool = false
    private let baseUrl = Edge.host.appendingPathComponent("users")

    func loadUserState() async {
        guard !ADUser.current.appleSignInID.isEmpty else {
            self.identifyInConnectedServices()
            return
        }

        if ADUser.current.id.isEmpty {
            // User needs to migrate
            print("Migrating cached user to Edge...")
            do {
                try await self.createUser(ADUser.current)
            } catch let error {
                if let error = error as? UserManagerError {
                    switch error {
                    case .requestError(_):
                        do {
                            try await self.updateUser(ADUser.current)
                        } catch {
                            print(error.localizedDescription)
                        }
                    default: break
                    }
                }
            }
        } else {
            // Get the current user
            print("Fetching current user from Edge...")
            await self.fetchCurrentUser()
            self.identifyInConnectedServices()
        }
    }

    // MARK: - Sign In

    func signIn(withId id: String, _ name: PersonNameComponents?, _ email: String?) async {
        do {
            // Try fetching by appleSignInID in Edge
            let user = try await getUsers(byAppleIDs: [id],
                                          hydrateAllCollectibles: true).first
            if let user = user {
                // Found a user in Edge
                ADUser.current = user
                NSUbiquitousKeyValueStore.default.currentUser = ADUser.current
                try await getMe()
                identifyInConnectedServices()
            } else {
                // Didn't find a user in Edge
                await tryCloudKitUserFetch(withId: id, name, email)
            }
        } catch {
            // Edge returned an error. Try fetching from CloudKit
            await tryCloudKitUserFetch(withId: id, name, email)
        }
    }

    func tryCloudKitUserFetch(withId id: String,
                              _ name: PersonNameComponents?,
                              _ email: String?) async {
        let cloudKitUser = await CloudKitUserManager.shared.fetchUser(withID: id)
        if let cloudKitUser = cloudKitUser {
            // Found user in CloudKit, create a user in Edge
            ADUser.current = cloudKitUser
            NSUbiquitousKeyValueStore.default.currentUser = ADUser.current
            CollectibleManager.grantBetaAndDay1CollectibleIfNecessary()
            do {
                try await createUser(ADUser.current)
            } catch {
                print(error.localizedDescription)
            }
            identifyInConnectedServices()
            return
        }

        // Didn't find user in CloudKit, create a new user in Edge
        ADUser.current.appleSignInID = id
        if let name = name, let email = email {
            let fullName = (name.givenName ?? "") + " " + (name.familyName ?? "")
            ADUser.current.name = fullName
            ADUser.current.email = email
        }
        ADUser.current.signupDate = ADUser.current.signupDate ?? Date()
        CollectibleManager.grantBetaAndDay1CollectibleIfNecessary()

        do {
            try await createUser(ADUser.current)
        } catch {
            print(error.localizedDescription)
            return
        }

        identifyInConnectedServices()
    }

    func identifyInConnectedServices() {
        let user = User()
        user.userId = ADUser.current.id
        user.username = ADUser.current.name
        user.email = ADUser.current.email
        SentrySDK.setUser(user)
        initializeConnectedServices()
        Mixpanel.mainInstance().identify(distinctId: ADUser.current.id)
        Mixpanel.mainInstance().people
            .set(properties: [
                "numFriends": ADUser.current.friendIDs.count,
                "numInvitesSent": NSUbiquitousKeyValueStore.default.invitedPhoneNumbers.count
        ])
    }

    func initializeConnectedServices() {
        guard !hasInitializedMixpanel else {
            return
        }

        // Mixpanel
        Mixpanel.initialize(token: "", trackAutomaticEvents: true)
        if ADUser.current.hasRegistered {
            Mixpanel.mainInstance().identify(distinctId: ADUser.current.id)
            Mixpanel.mainInstance().people.set(properties: ["subscription": ADUser.current.subscriptionProductID])
        }

        Mixpanel.mainInstance().people
            .set(properties: [
                "userID": ADUser.current.id,
                "email": ADUser.current.email,
                "username": ADUser.current.username,
                "phone": ADUser.current.phoneNumber,
                "signupDate": ADUser.current.signupDate,
                "friendCount": ADUser.current.friendIDs.count,
                "totalTimeTracked": ADUser.current.totalTimeTracked,
                "totalDistanceTrackedMeters": ADUser.current.totalDistanceTrackedMeters,
                "hasRegistered": ADUser.current.hasRegistered,
                "collectibleCount": ADUser.current.collectibles.count,
                "goalCount": ADUser.current.goals.count,
                "gearCount": ADUser.current.gear.count,
                "hasAppleWatch": WCSession.isSupported() && WCSession.default.isPaired
            ])

        SilentDeeplinkReporter.report()

        if ADUser.current.hasFinishedOnboarding && NSUbiquitousKeyValueStore.default.activityShareReminderNotificationsOn {
            OneSignal.promptForPushNotifications(userResponse: { accepted in
                if !accepted {
                    NSUbiquitousKeyValueStore.default.disableAllNotifications()
                }
            }, fallbackToSettings: false)
        }

        hasInitializedMixpanel = true
    }

    // MARK: - Create

    func createUser(_ user: ADUser) async throws {
        await user.setRandomCoverPhotoIfNecessary(pushChanges: false)
        let url = baseUrl.appendingPathComponent("create")
        let payload = UserPayload(user: user)
        var request = try Edge.defaultRequest(with: url, method: .post)
        request.httpBody = try JSONEncoder().encode(payload)
//        print(String(data: request.httpBody!, encoding: .utf8))
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 201 else {
            let stringData = String(data: data, encoding: .utf8)
//            print(stringData)
            throw UserManagerError.requestError(stringData)
        }

        let responsePayload = try JSONDecoder().decode(UserPayload.self, from: data)
        await user.merge(with: responsePayload.user)
//        UserCache.shared.cache(user: user)
    }

    // MARK: - Update

    func updateCurrentUser() {
        Task {
            await updateCurrentUser()
        }
    }

    func updateCurrentUser() async {
        do {
            try await self.updateUser(ADUser.current)
        } catch {
            print(error.localizedDescription)
        }
    }

    func updateUser(_ user: ADUser) async throws {
        guard user.hasRegistered else {
            return
        }
        
        let url = baseUrl.appendingPathComponent("update")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        components?.queryItems = [
            URLQueryItem(name: "id", value: user.id)
        ]
        guard let urlWithComponents = components?.url else {
            throw UserManagerError.urlEncodingError
        }

        let payload = UserPayload(user: user)
        var request = try Edge.defaultRequest(with: urlWithComponents, method: .put)
        request.httpBody = try JSONEncoder().encode(payload)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            let stringData = String(data: data, encoding: .utf8)
            throw UserManagerError.requestError(stringData)
        }

        let responsePayload = try JSONDecoder().decode(UserPayload.self, from: data)
        await user.merge(with: responsePayload.user)
        UserCache.shared.cache(user: user)
    }

    func fixImgixURLs(for user: ADUser) async -> Bool {
        var fixed: Bool = false
        if user.profilePhotoUrl?.isImgixURL ?? false {
            await MainActor.run {
                user.profilePhotoUrl = user.profilePhotoUrl?.unImgixdURL
            }
            fixed = true
        }

        if user.coverPhotoUrl?.isImgixURL ?? false {
            await MainActor.run {
                user.coverPhotoUrl = user.coverPhotoUrl?.unImgixdURL
            }
            fixed = true
        }

        return fixed
    }

    func setDefaultNotificationTags(for user: ADUser) async -> Bool {
        if user.notificationTags == nil {
            await MainActor.run {
                user.notificationTags = ActiveClubNotificationSettings().notificationTags()
            }
            print("Setting default notification tags")
            return true
        }
        return false
    }

    // MARK: - Delete

    func deleteUser(_ user: ADUser) async throws {
        let url = baseUrl.appendingPathComponent("delete")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        components?.queryItems = [
            URLQueryItem(name: "id", value: user.id)
        ]
        guard let urlWithComponents = components?.url else {
            throw UserManagerError.urlEncodingError
        }

        let request = try Edge.defaultRequest(with: urlWithComponents, method: .delete)
//        print(String(data: request.httpBody!, encoding: .utf8))
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            let stringData = String(data: data, encoding: .utf8)
            throw UserManagerError.requestError(stringData)
        }
    }

    // MARK: - Get

    @discardableResult
    func fetchCurrentUser() async -> ADUser? {
        do {
            // Fetch current user from Edge
            try await getMe()
            var shouldUpdate = await fixImgixURLs(for: ADUser.current)
            shouldUpdate = await setDefaultNotificationTags(for: ADUser.current)
            if shouldUpdate {
                try await self.updateUser(ADUser.current)
            }
            return .current
        } catch {
            // Error fetching user in Edge. Try creating.
            do {
                try await createUser(.current)
                return .current
            } catch {
                return nil
            }
        }
    }

    @discardableResult
    func getMe() async throws -> CurrentUserResponsePayload {
        let url = Edge.host.appendingPathComponent("me")
        let request = try Edge.defaultRequest(with: url, method: .get)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            let stringData = String(data: data, encoding: .utf8)
            throw UserManagerError.requestError(stringData)
        }

        let responsePayload = try JSONDecoder().decode(CurrentUserResponsePayload.self, from: data)
        await ADUser.current.merge(with: responsePayload.user)
        await MainActor.run {
            ADUser.current.friendIDs = responsePayload.friends.compactMap { $0.id }
            ADUser.current.blockedIDs = responsePayload.blocks
            ADUser.current.friendships = responsePayload.friendships
        }
        await ADUser.current.setRandomCoverPhotoIfNecessary(pushChanges: true)

        for userPayloadData in responsePayload.friends {
            if let cachedUser = UserCache.shared.user(forID: userPayloadData.id) {
                await cachedUser.merge(with: userPayloadData)
                UserCache.shared.cache(user: cachedUser)
            } else {
                let newUser = ADUser()
                await newUser.merge(with: userPayloadData)
                UserCache.shared.cache(user: newUser)
            }
        }

        return responsePayload
    }

    @discardableResult
    func getUsers(byAppleIDs appleIDs: [ADUser.AppleSignInID],
                  hydrateAllCollectibles: Bool = true) async throws -> [ADUser] {
        return try await getUsers(by: "appleIDs",
                                  value: appleIDs.joined(separator: ","),
                                  hydrateAllCollectibles: hydrateAllCollectibles)
    }

    @discardableResult
    func getUsers(byCanonicalIDs canonicalIDs: [ADUser.ID]) async throws -> [ADUser] {
        return try await getUsers(by: "ids",
                                  value: canonicalIDs.joined(separator: ","),
                                  hydrateAllCollectibles: false)
    }

    @discardableResult
    func getUsers(byPhones phones: [String]) async throws -> [ADUser] {
        return try await getUsers(by: "phones",
                                  value: phones.joined(separator: ","),
                                  hydrateAllCollectibles: false)
    }

    @discardableResult
    func getUsers(byHashedPhones hashedPhones: [String]) async throws -> [ADUser] {
        return try await getUsers(by: "hashedPhones",
                                  value: hashedPhones.joined(separator: ","),
                                  hydrateAllCollectibles: false)
    }

    func searchUsers(by term: String) async throws -> [ADUser] {
        return try await getUsers(by: "search",
                                  value: term, isSearch: true,
                                  hydrateAllCollectibles: false)
    }

    private func getUsers(by field: String,
                          value: String,
                          isSearch: Bool = false,
                          hydrateAllCollectibles: Bool) async throws -> [ADUser] {
        var body: String = ""
        body.append("\(field)=\(value)")
        if isSearch {
            body.append("&field=all")
        }
        body = body.replacingOccurrences(of: "+", with: "%2b")

        var request = try Edge.defaultRequest(with: baseUrl, method: .post)
        request.httpBody = body.data(using: .utf8, allowLossyConversion: true)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            let stringData = String(data: data, encoding: .utf8)
            throw UserManagerError.requestError(stringData)
        }

        let responsePayload = try JSONDecoder().decode(MultiUserPayload.self, from: data)
        var returnedUsers: [ADUser] = []
        for userPayloadData in responsePayload.users {
            if userPayloadData.appleSignInID == ADUser.current.appleSignInID {
                await ADUser.current.merge(with: userPayloadData, hydrateAllCollectibles: hydrateAllCollectibles)
                returnedUsers.append(ADUser.current)
            } else if let cachedUser = UserCache.shared.user(forID: userPayloadData.id) {
                await cachedUser.merge(with: userPayloadData, hydrateAllCollectibles: hydrateAllCollectibles)
                returnedUsers.append(cachedUser)
                UserCache.shared.cache(user: cachedUser)
            } else {
                let newUser = ADUser()
                await newUser.merge(with: userPayloadData, hydrateAllCollectibles: hydrateAllCollectibles)
                returnedUsers.append(newUser)
                UserCache.shared.cache(user: newUser)
            }
        }

        return returnedUsers
    }

    // MARK: - Friends

    func getFriendsOfFriends() async throws -> [FriendsOfFriendsResponsePayload] {
        let url = Edge.host
            .appendingPathComponent("friends")
            .appendingPathComponent("fof")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        components?.queryItems = [
            URLQueryItem(name: "id", value: ADUser.current.id)
        ]
        guard let urlWithComponents = components?.url else {
            throw UserManagerError.urlEncodingError
        }

        let request = try Edge.defaultRequest(with: urlWithComponents, method: .get)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            let stringData = String(data: data, encoding: .utf8)
//            print(stringData)
            throw UserManagerError.requestError(stringData)
        }

        let json = try JSON(data: data)
        let result = try json["result"].rawData()
        var responses = try JSONDecoder().decode([FriendsOfFriendsResponsePayload].self, from: result)
        // Make sure there's at least one mutual
        responses = responses.filter { $0.totalMutuals >= 1 }

        // If there exist responses with 2 or more mutuals, only include those responses to avoid
        // having a huge list.
        let twoOrMoreMutuals = responses.filter { $0.totalMutuals >= 2 }
        if !twoOrMoreMutuals.isEmpty {
            responses = twoOrMoreMutuals
        }

        for response in responses {
            if let cachedUser = UserCache.shared.user(forID: response.friend.id) {
                await cachedUser.merge(with: response.friend)
                UserCache.shared.cache(user: cachedUser)
            } else {
                let newUser = ADUser()
                await newUser.merge(with: response.friend)
                UserCache.shared.cache(user: newUser)
            }
        }

        return responses
    }

    func sendFriendRequest(to targetUserID: ADUser.ID) async throws {
        let url = Edge.host
            .appendingPathComponent("friendships")
            .appendingPathComponent("requests")
            .appendingPathComponent("create")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        components?.queryItems = [
            URLQueryItem(name: "id", value: ADUser.current.id)
        ]
        guard let urlWithComponents = components?.url else {
            throw UserManagerError.urlEncodingError
        }

        var request = try Edge.defaultRequest(with: urlWithComponents, method: .post)
        let body: [String: String] = ["targetID": targetUserID]
        request.httpBody = try JSONEncoder().encode(body)
        print(urlWithComponents.absoluteString)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            let stringData = String(data: data, encoding: .utf8)
//            print(stringData)
            throw UserManagerError.requestError(stringData)
        }

        NotificationsManager.sendNotification(to: targetUserID,
                                              withCategory: "FRIEND_REQUEST",
                                              message: "@\(ADUser.current.username ?? "") sent you a friend request.",
                                              appUrl: "anydistance://friends?selectedSegment=2",
                                              type: .friendRequest)
        let json = try JSON(data: data)
        let result = try json["request"].rawData()
        let friendship = try JSONDecoder().decode(Friendship.self, from: result)

        await MainActor.run {
            ADUser.current.friendships.append(friendship)
        }
    }

    func approveFriendRequest(_ friendship: Friendship) async throws {
        do {
            await MainActor.run {
                ADUser.current.friendships.removeAll(where: { $0.id == friendship.id })
                ADUser.current.friendIDs.append(friendship.requestingUserID)
                ADUser.current.friendIDs = ADUser.current.friendIDs.uniqued()
            }

            let url = Edge.host
                .appendingPathComponent("friendships")
                .appendingPathComponent("approve")
            var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
            components?.queryItems = [
                URLQueryItem(name: "id", value: friendship.id)
            ]
            guard let urlWithComponents = components?.url else {
                throw UserManagerError.urlEncodingError
            }

            let request = try Edge.defaultRequest(with: urlWithComponents, method: .post)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                let stringData = String(data: data, encoding: .utf8)
                print(stringData)
                throw UserManagerError.requestError(stringData)
            }

            NotificationsManager.sendNotification(to: friendship.requestingUserID,
                                                  withCategory: "FRIEND_REQUEST",
                                                  message: "@\(ADUser.current.username ?? "") approved your friend request.",
                                                  appUrl: "anydistance://profile?username=\(ADUser.current.username ?? "")",
                                                  type: .friendApproval)
        } catch {
            ADUser.current.friendships.append(friendship)
            ADUser.current.friendIDs.removeAll(where: { $0 == friendship.requestingUserID })
            throw error
        }
    }

    func deleteFriendRequest(with id: Friendship.ID) async throws {
        do {
            let friendship = ADUser.current.friendships.first(where: { $0.id == id })
            await MainActor.run {
                ADUser.current.friendships.removeAll(where: { $0.id == id })
            }

            let url = Edge.host
                .appendingPathComponent("friendships")
                .appendingPathComponent("delete")
            var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
            components?.queryItems = [
                URLQueryItem(name: "id", value: id)
            ]
            guard let urlWithComponents = components?.url else {
                throw UserManagerError.urlEncodingError
            }

            let request = try Edge.defaultRequest(with: urlWithComponents, method: .delete)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                let stringData = String(data: data, encoding: .utf8)
                print(stringData)
                throw UserManagerError.requestError(stringData)
            }

            if let friendship = friendship {
                ADUser.current.friendships.append(friendship)
            }
        } catch {
            throw error
        }
    }

    func unfriendUser(with id: ADUser.ID) async throws {
        guard let friendship = ADUser.current.friendships
            .first(where: { $0.requestingUserID == id || $0.targetUserID == id }) else {
            try await getMe()
            return
        }

        try await deleteFriendRequest(with: friendship.id)

        await MainActor.run {
            ADUser.current.friendIDs.removeAll(where: { $0 == id })
        }
    }

    // MARK: - Blocks

    func blockUser(with id: ADUser.ID) async throws {
        let url = Edge.host
            .appendingPathComponent("blocks")
            .appendingPathComponent("create")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        components?.queryItems = [
            URLQueryItem(name: "userID", value: ADUser.current.id),
            URLQueryItem(name: "blockedID", value: id)
        ]
        guard let urlWithComponents = components?.url else {
            throw UserManagerError.urlEncodingError
        }

        let request = try Edge.defaultRequest(with: urlWithComponents, method: .post)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            let stringData = String(data: data, encoding: .utf8)
            throw UserManagerError.requestError(stringData)
        }

        await MainActor.run {
            ADUser.current.blockedIDs.append(id)
            ADUser.current.friendIDs.removeAll(where: { $0 == id})
            ADUser.current.friendships.removeAll(where: { $0.requestingUserID == id  || $0.targetUserID == id })
            PostCache.shared.postCachedPublisher.send()
        }
    }

    func unblockUser(with id: ADUser.ID) async throws {
        let url = Edge.host
            .appendingPathComponent("blocks")
            .appendingPathComponent("delete")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        components?.queryItems = [
            URLQueryItem(name: "userID", value: ADUser.current.id),
            URLQueryItem(name: "blockedID", value: id)
        ]
        guard let urlWithComponents = components?.url else {
            throw UserManagerError.urlEncodingError
        }

        let request = try Edge.defaultRequest(with: urlWithComponents, method: .delete)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            let stringData = String(data: data, encoding: .utf8)
            throw UserManagerError.requestError(stringData)
        }

        await MainActor.run {
            ADUser.current.blockedIDs.removeAll(where: { $0 == id })
        }
    }

    // MARK: - Check Availability

    func checkAvailable(email: String) async throws -> Bool {
        return try await checkAvailable(field: "email", value: email)
    }

    func checkAvailable(username: String) async throws -> Bool {
        return try await checkAvailable(field: "username", value: username)
    }

    func checkAvailable(phone: String) async throws -> Bool {
        return try await checkAvailable(field: "phone", value: phone)
    }

    private func checkAvailable(field: String, value: String) async throws -> Bool {
        let url = baseUrl.appendingPathComponent("check-available")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        components?.queryItems = [
            URLQueryItem(name: "field", value: field),
            URLQueryItem(name: "value", value: value)
        ]
        guard let urlWithComponents = components?.url else {
            throw UserManagerError.urlEncodingError
        }
        let request = try Edge.defaultRequest(with: urlWithComponents, method: .get)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            let stringData = String(data: data, encoding: .utf8)
            throw UserManagerError.requestError(stringData)
        }

        let json = try JSON(data: data)
        if let available = json["available"].bool {
            return available
        }

        throw UserManagerError.responseDecodingError
    }
}

enum UserManagerError: Error {
    case requestError(_ errorString: String?)
    case urlEncodingError
    case responseDecodingError
}

class UserCache: NSObject, ObservableObject {
    static let shared = UserCache()

    private var internalCache: Storage<String, ADUser>? // Canonical ID, User
    private var usernameToUserIDMap: Storage<String, String>? // username, Canonical ID
    private let queue = DispatchQueue(label: "com.anydistance.anydistance.UserCache.\(UUID().uuidString)",
                                      qos: .userInitiated)

    override init() {
        let memoryConfig = MemoryConfig(expiry: .never,
                                        countLimit: 10000,
                                        totalCostLimit: 1000)

        internalCache = try? Storage<String, ADUser>(
            diskConfig: DiskConfig(name: "com.anydistance.UserCache"),
            memoryConfig: memoryConfig,
            transformer: TransformerFactory.forCodable(ofType: ADUser.self)
        )

        usernameToUserIDMap = try? Storage<String, String>(
            diskConfig: DiskConfig(name: "com.anydistance.UsernametoUserIDMap"),
            memoryConfig: memoryConfig,
            transformer: TransformerFactory.forCodable(ofType: String.self)
        )
    }

    func cache(user: ADUser) {
        queue.sync {
            try? internalCache?.setObject(user, forKey: user.id)
            if let username = user.username {
                try? usernameToUserIDMap?.setObject(user.id, forKey: username)
            }
        }
    }

    func user(forID id: ADUser.ID?) -> ADUser? {
        queue.sync {
            guard let id = id else {
                return nil
            }
            return try? internalCache?.object(forKey: id)
        }
    }

    func user(for username: String) -> ADUser? {
        queue.sync {
            guard let userID = try? usernameToUserIDMap?.object(forKey: username) else {
                return nil
            }
            return try? internalCache?.object(forKey: userID)
        }
    }

    func searchFriends(by term: String) -> [ADUser] {
        let term = term.lowercased()
        let friends = ADUser.current.friendIDs.compactMap { user(forID: $0) }
        return friends.filter { friend in
            (friend.username ?? "").contains(term) ||
            friend.name.lowercased().contains(term)
        }
        .sorted { user1, user2 in
            let user1Username = user1.username ?? ""
            let user2Username = user2.username ?? ""

            // Exact match
            if user1Username == term {
                return true
            } else if user2Username == term {
                return false
            }

            // Prefix matching
            if user1Username.hasPrefix(term) && !user2Username.hasPrefix(term) {
                return true
            } else if !user1Username.hasPrefix(term) && user2Username.hasPrefix(term) {
                return false
            }

            // Similarity comparison
            let user1usernameDistance = user1Username.distance(between: term)
            let user2usernameDistance = user2Username.distance(between: term)
            return user1usernameDistance < user2usernameDistance
        }
    }
}
