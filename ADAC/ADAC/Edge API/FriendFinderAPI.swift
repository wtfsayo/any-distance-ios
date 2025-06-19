// Licensed under the Any Distance Source-Available License
//
//  FriendFinderAPI.swift
//  ADAC
//
//  Created by Daniel Kuntz on 2/23/23.
//

import Foundation
import Contacts
import SwiftyJSON
import CommonCrypto
import UIKit
import Mixpanel

class FriendFinderAPI: NSObject, ObservableObject {

    static let shared = FriendFinderAPI()

    /// Sorted, filtered data
    @Published var contactsOnAnyDistance: [FriendFinderUser] = []
    @Published var friendsOfContacts: [FriendFinderUser] = []
    @Published var contactsNotOnAnyDistance: [FriendFinderUser] = []
    @Published var teamAnyDistance: [FriendFinderUser] = []

    /// Unsorted, unfiltered data
    private var contacts: [CNContact] = []
    private var usersOnAD: [ADUser] = NSUbiquitousKeyValueStore.default.usersOnAD
    private var friendsOfFriends: [FriendsOfFriendsResponsePayload] = NSUbiquitousKeyValueStore.default.friendsOfFriends
    private var leaderboard: [FriendFinderAPI.LeaderboardItem] = NSUbiquitousKeyValueStore.default.leaderboard
    private var teamAD: [ADUser] = ADUser.teamCanonicalIDs
        .compactMap { UserCache.shared.user(forID: $0) }
        .sortedByUsername

    private var contactStore = CNContactStore()

    private actor AsyncLoadData {
        var usersOnAD: [ADUser] = []
        var teamAD: [ADUser] = []
        var friendsOfFriends: [FriendsOfFriendsResponsePayload] = []
        var leaderboard: [FriendFinderAPI.LeaderboardItem] = []

        func setUsersOnAD(_ users: [ADUser]) {
            self.usersOnAD = users
        }

        func setFriendsOfFriends(_ fof: [FriendsOfFriendsResponsePayload]) {
            self.friendsOfFriends = fof
        }

        func setLeaderboard(_ leaderboard: [FriendFinderAPI.LeaderboardItem]) {
            self.leaderboard = leaderboard
        }

        func setTeamAD(_ users: [ADUser]) {
            self.teamAD = users
        }
    }

    func authorizationStatus() -> CNAuthorizationStatus {
        return CNContactStore.authorizationStatus(for: .contacts)
    }

    func load(with onboardingModel: OnboardingViewModel? = nil,
              loadCurrentUser: Bool = true) async throws {
        if authorizationStatus() != .authorized {
            await MainActor.run {
                onboardingModel?.state = .viewingContacts
            }
        } else {
            await MainActor.run {
                onboardingModel?.state = .searchingForFriends
            }
        }

        contacts = (try? fetchContacts()) ?? []
        reloadCached()
        guard let currentUserPhone = ADUser.current.phoneNumber else {
            throw FriendFinderAPIError.couldntGetCurrentUserPhone
        }

        fetchContactPhotoForCurrentUser(from: contacts,
                                        userPhone: currentUserPhone,
                                        with: onboardingModel)
        let asyncLoadData = AsyncLoadData()

        await withThrowingTaskGroup(of: Bool.self) { group in
            if loadCurrentUser {
                group.addTask {
                    try await UserManager.shared.getMe()
                    return true
                }
            }

//            group.addTask {
//                let friendsOfFriends = try await UserManager.shared.getFriendsOfFriends()
//                await asyncLoadData.setFriendsOfFriends(friendsOfFriends)
//                return true
//            }

            group.addTask {
                let contactUpsertResponse = try await FriendFinderAPI.upsert(self.contacts,
                                                                             currentUserPhone: currentUserPhone)
                let filteredLeaderboard = contactUpsertResponse.leaderboard.filter { item in
                    return !item.unhashedPhone.hasPrefix("+1800") &&
                           !item.unhashedPhone.isEmpty
                }
                await asyncLoadData.setLeaderboard(filteredLeaderboard)
                await asyncLoadData.setUsersOnAD(contactUpsertResponse.contactsOnAD)
                return true
            }

            group.addTask {
                var users: [ADUser] = []
                var idsToQuery: [ADUser.ID] = []

                for id in ADUser.teamCanonicalIDs {
                    if let user = UserCache.shared.user(forID: id) {
                        users.append(user)
                    } else {
                        idsToQuery.append(id)
                    }
                }

                if !idsToQuery.isEmpty,
                   let queriedUsers = try? await UserManager.shared.getUsers(byCanonicalIDs: idsToQuery) {
                    users.append(contentsOf: queriedUsers)
                }

                await asyncLoadData.setTeamAD(users.sortedByUsername)
                return true
            }
        }

        self.usersOnAD = await asyncLoadData.usersOnAD
        self.friendsOfFriends = await asyncLoadData.friendsOfFriends
        self.leaderboard = await asyncLoadData.leaderboard
        self.teamAD = await asyncLoadData.teamAD

        NSUbiquitousKeyValueStore.default.usersOnAD = self.usersOnAD
        NSUbiquitousKeyValueStore.default.friendsOfFriends = self.friendsOfFriends
        NSUbiquitousKeyValueStore.default.leaderboard = self.leaderboard

        reloadCached(onboardingModel: onboardingModel)

        if onboardingModel != nil {
            // Send notification to existing users in contacts notifying them that a friend
            // just joined.
            let userIDs = self.usersOnAD.map { $0.id }
            NotificationsManager.sendNotification(to: userIDs,
                                                  withCategory: "FRIEND_JOINED",
                                                  message: "📣 \(ADUser.current.name) (@\(ADUser.current.username ?? "")) is now on Any Distance! Tap to add them to your Active Club.",
                                                  appUrl: "anydistance://profile?username=\(ADUser.current.username ?? "")",
                                                  type: .friendJoin)
        }

        await MainActor.run {
            if let model = onboardingModel, model.state != .viewingContacts {
                model.state = .viewingContacts
            }
        }
    }

    func reloadCached(onboardingModel: OnboardingViewModel? = nil) {
        let invitedPhoneNumbers = NSUbiquitousKeyValueStore.default.invitedPhoneNumbers
        var contactsOnAnyDistance: [FriendFinderUser] = []
        var contactsNotOnAnyDistance: [FriendFinderUser] = []

        for contact in contacts {
            // Check if contact is on AD
            if let userOnAD = usersOnAD.first(where: { $0.phoneNumber != nil && $0.phoneNumber == contact.e164FormattedPhoneNumber }) {
                var friendState: FriendState {
                    if ADUser.current.pendingFriendships.contains(where: { $0.targetUserID == userOnAD.id }) {
                        return .added
                    }
                    return .notAdded
                }

                let user = FriendFinderUser(adUser: userOnAD,
                                            name: userOnAD.name,
                                            phoneNumber: userOnAD.phoneNumber ?? "",
                                            contactProfilePhoto: nil,
                                            isInContacts: true,
                                            friendState: friendState,
                                            contactCount: 0)
                let userIsFriend = ADUser.current.friendIDs.contains(userOnAD.id)
                let alreadyContains = contactsOnAnyDistance.contains(where: { $0.adUser === userOnAD })
                let userSentSelfFriendRequest = ADUser.current.pendingFriendships.contains(where: { $0.requestingUserID == userOnAD.id })
                if !userOnAD.isBlocked && !userIsFriend && !alreadyContains && !userOnAD.isSelf && !userSentSelfFriendRequest {
                    contactsOnAnyDistance.append(user)
                }
                continue
            }

            // User is not AD - match them to the leaderboard
            var profilePhoto: UIImage? {
                if let data = contact.thumbnailImageData {
                    return UIImage(data: data)?.resized(withNewWidth: 35.0)
                } else {
                    return nil
                }
            }

            let name = contact.givenName + " " + contact.familyName
            guard let phoneNumber = contact.e164FormattedPhoneNumber,
                  !phoneNumber.hasPrefix("+1800"),
                  !phoneNumber.hasPrefix("+1866"),
                  phoneNumber != ADUser.current.phoneNumber,
                  phoneNumber != "+14244880920", // Digit
                  phoneNumber != "+18556934911", // simpli safe
                  phoneNumber != "+18006332677", // simpli safe
                  phoneNumber != "+14048942500", // Georgia Tech police
                  phoneNumber != "+18056377243", // Voicemail
                  phoneNumber.count > 8 else {
                continue
            }

            let friendState: FriendState = invitedPhoneNumbers.contains(phoneNumber) ? .invited : .notInvited
            let contactCount = leaderboard.first(where: { $0.unhashedPhone == phoneNumber })?.count ?? 1

            let user = FriendFinderUser(adUser: nil,
                                        name: name,
                                        phoneNumber: phoneNumber,
                                        contactProfilePhoto: profilePhoto,
                                        isInContacts: true,
                                        friendState: friendState,
                                        contactCount: contactCount)
            contactsNotOnAnyDistance.append(user)
        }

        contactsOnAnyDistance.sort(by: { ($0.adUser?.name ?? "") < ($1.adUser?.name ?? "") })

        let notOnADGreaterThan1Contact = contactsNotOnAnyDistance
            .filter { $0.contactCount > 1 }
            .sorted(by: { $0.contactCount > $1.contactCount })
        let notOnADLessThanOrEqual1Contact = contactsNotOnAnyDistance
            .filter { $0.contactCount <= 1 }
            .sorted(by: { $0.name < $1.name })
        contactsNotOnAnyDistance = notOnADGreaterThan1Contact + notOnADLessThanOrEqual1Contact

        let friendsOfContacts: [FriendFinderUser] = friendsOfFriends.compactMap { payload -> FriendFinderUser? in
            guard let user = UserCache.shared.user(forID: payload.friend.id) else {
                return nil
            }

            let userIsFriend = ADUser.current.friendIDs.contains(user.id)
            let userSentSelfFriendRequest = ADUser.current.pendingFriendships.contains(where: { $0.requestingUserID == user.id })
            let contactsOnAnyDistanceContains = contactsOnAnyDistance.contains(where: { $0.adUser?.id == user.id })
            guard !user.isBlocked && !userIsFriend && !userSentSelfFriendRequest && !contactsOnAnyDistanceContains else {
                return nil
            }

            var friendState: FriendState {
                if ADUser.current.pendingFriendships.contains(where: { $0.targetUserID == user.id }) {
                    return .added
                }
                return .notAdded
            }

            return FriendFinderUser(adUser: user,
                                    name: user.name,
                                    phoneNumber: user.phoneNumber ?? "",
                                    contactProfilePhoto: nil,
                                    isInContacts: false,
                                    friendState: friendState,
                                    contactCount: payload.totalMutuals)
        }
        .sorted(by: { $0.contactCount > $1.contactCount })

        let teamAnyDistance: [FriendFinderUser] = teamAD.compactMap { user -> FriendFinderUser? in
            let userIsFriend = ADUser.current.friendIDs.contains(user.id)
            let userSentSelfFriendRequest = ADUser.current.pendingFriendships.contains(where: { $0.requestingUserID == user.id })
            let contactsOnAnyDistanceContains = contactsOnAnyDistance.contains(where: { $0.adUser?.id == user.id })
            guard !user.isBlocked && !userIsFriend && !userSentSelfFriendRequest && !contactsOnAnyDistanceContains else {
                return nil
            }

            var friendState: FriendState {
                if ADUser.current.pendingFriendships.contains(where: { $0.targetUserID == user.id }) {
                    return .added
                }
                return .notAdded
            }

            return FriendFinderUser(adUser: user,
                                    name: user.name,
                                    phoneNumber: user.phoneNumber ?? "",
                                    contactProfilePhoto: nil,
                                    isInContacts: true,
                                    friendState: friendState,
                                    contactCount: 0)
        }

        DispatchQueue.main.async {
            self.contactsOnAnyDistance = contactsOnAnyDistance
            self.contactsNotOnAnyDistance = contactsNotOnAnyDistance
            self.friendsOfContacts = friendsOfContacts
            self.teamAnyDistance = teamAnyDistance

            if onboardingModel != nil {
                UserManager.shared.initializeConnectedServices()
                Mixpanel.mainInstance().people
                    .set(properties: [
                        "onboarding_contactsOnAnyDistance": self.contactsOnAnyDistance.count,
                        "onboarding_contactsNotOnAnyDistance": self.contactsNotOnAnyDistance.count
                    ])
            }
        }
    }

    func searchUsers(by term: String) async throws -> [FriendFinderUser] {
        let users = try await UserManager.shared.searchUsers(by: term)
        return users.compactMap { user in
            let userIsSelf = ADUser.current.id == user.id
            let userIsFriend = ADUser.current.friendIDs.contains(user.id)
            let userIsBlocked = ADUser.current.blockedIDs.contains(user.id)
            let userSentSelfFriendRequest = ADUser.current.pendingFriendships.contains(where: { $0.requestingUserID == user.id })
            guard !userIsSelf && !userIsFriend && !userIsBlocked && !userSentSelfFriendRequest else {
                return nil
            }

            var friendState: FriendState {
                if ADUser.current.pendingFriendships.contains(where: { $0.targetUserID == user.id }) {
                    return .added
                }
                return .notAdded
            }

            return FriendFinderUser(adUser: user,
                                    name: user.name,
                                    phoneNumber: user.phoneNumber ?? "",
                                    contactProfilePhoto: nil,
                                    isInContacts: false,
                                    friendState: friendState,
                                    contactCount: 0,
                                    wasSearched: true)
        }
    }

    func requestContactsPermission() async throws {
        try await contactStore.requestAccess(for: .contacts)
    }

    private func fetchContacts() throws -> [CNContact] {
        var contacts = [CNContact]()
        let keys = [CNContactGivenNameKey,
                    CNContactFamilyNameKey,
                    CNContactPhoneNumbersKey,
                    CNContactThumbnailImageDataKey,
                    CNContactImageDataKey] as [NSString]
        guard CNContactStore.authorizationStatus(for: .contacts) == .authorized else {
            throw FriendFinderAPIError.contactsNotAuthorized
        }

        let request = CNContactFetchRequest(keysToFetch: keys)
        try contactStore.enumerateContacts(with: request) { (contact, stop) in
            contacts.append(contact)
        }
        return contacts
    }

    private func fetchContactPhotoForCurrentUser(from contacts: [CNContact],
                                                 userPhone: String,
                                                 with onboardingModel: OnboardingViewModel?) {
        guard onboardingModel != nil else {
            return
        }

        let contact = contacts.filter { contact in
            let phoneNumberMatches = contact.phoneNumbers.contains { labeledValue in
                let formattedValue = labeledValue.value.stringValue.e164FormattedPhoneNumber()
                return formattedValue.contains(userPhone) || userPhone.contains(formattedValue)
            }
            return phoneNumberMatches && (contact.imageData != nil || contact.thumbnailImageData != nil)
        }.first

        guard let contact = contact else {
            return
        }

        var profilePhoto: UIImage? {
            if let data = contact.imageData ?? contact.thumbnailImageData {
                return UIImage(data: data)
            } else {
                return nil
            }
        }

        DispatchQueue.main.async {
            onboardingModel?.userProfileImage = profilePhoto
        }

        guard let profilePhoto = profilePhoto else {
            return
        }

        Task(priority: .userInitiated) {
            do {
                let objectURL = try await S3.uploadImage(profilePhoto)
                await MainActor.run {
                    ADUser.current.profilePhotoUrl = objectURL
                }
                await UserManager.shared.updateCurrentUser()
            } catch {}
        }
    }

    // MARK: - Edge API Calls

    static func upsert(_ contacts: [CNContact],
                       currentUserPhone: String) async throws -> ContactUpsertResponse {
        let phoneNumbers: [String] = contacts.compactMap { $0.e164FormattedPhoneNumber }
        let hashedPhoneNumbers: [String] = phoneNumbers.map { $0.sha256() }
        let previouslyUpsertedHashes = Set(NSUbiquitousKeyValueStore.default.previouslyUpsertedHashes)
        let filteredHashedPhoneNumbers = Array(Set(hashedPhoneNumbers).subtracting(previouslyUpsertedHashes))

        let url = Edge.host.appendingPathComponent("contacts").appendingPathComponent("upsert")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        components?.queryItems = [URLQueryItem(name: "phone", value: currentUserPhone.sha256())]
        guard let urlWithComponents = components?.url else {
            throw FriendFinderAPIError.urlEncodingError
        }

        var request = try Edge.defaultRequest(with: urlWithComponents, method: .post)
        let body: [String: Any] = [
            "contacts": filteredHashedPhoneNumbers
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            let stringData = String(data: data, encoding: .utf8)
            throw FriendFinderAPIError.upsertError(stringData)
        }

        return try await decodeLeaderboard(from: data,
                                           phoneNumbers: phoneNumbers,
                                           hashedPhoneNumbers: hashedPhoneNumbers)
    }

    static func getLeaderboard(for contacts: [CNContact],
                               currentUserPhone: String) async throws -> ContactUpsertResponse {
        let url = Edge.host.appendingPathComponent("contacts").appendingPathComponent("upsert")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        components?.queryItems = [
            URLQueryItem(name: "phone", value: currentUserPhone.e164FormattedPhoneNumber().sha256())
        ]
        guard let urlWithComponents = components?.url else {
            throw FriendFinderAPIError.urlEncodingError
        }

        let request = try Edge.defaultRequest(with: urlWithComponents, method: .get)
        let (data, response) = try await URLSession.shared.data(for: request)
        let stringData = String(data: data, encoding: .utf8)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw FriendFinderAPIError.leaderboardRequestError(stringData)
        }

        return try await decodeLeaderboard(from: data, contacts: contacts)
    }

    static func decodeLeaderboard(from data: Data, contacts: [CNContact]) async throws -> ContactUpsertResponse {
        let phoneNumbers: [String] = contacts.compactMap { $0.e164FormattedPhoneNumber }
        let hashedPhoneNumbers: [String] = phoneNumbers.map { $0.sha256() }
        return try await decodeLeaderboard(from: data,
                                           phoneNumbers: phoneNumbers,
                                           hashedPhoneNumbers: hashedPhoneNumbers)
    }

    static func decodeLeaderboard(from data: Data,
                                  phoneNumbers: [String],
                                  hashedPhoneNumbers: [String]) async throws -> ContactUpsertResponse {
        let json = try JSON(data: data)

        if let allContacts = json["all_contacts"].arrayObject as? [String] {
            NSUbiquitousKeyValueStore.default.previouslyUpsertedHashes = allContacts
        }

        guard let jsonResultsArray = json["leaderboard"].array else {
            throw FriendFinderAPIError.leaderboardDecodingError
        }

        let leaderboard: [LeaderboardItem] = jsonResultsArray.compactMap { jsonItem in
            guard let hashedPhone = jsonItem["hashedPhone"].string,
                  let hashedNumbersIdx = hashedPhoneNumbers.firstIndex(of: hashedPhone),
                  let count = jsonItem["count"].int else {
                return nil
            }

            let unhashedPhone = phoneNumbers[hashedNumbersIdx]
            return LeaderboardItem(hashedPhone: hashedPhone,
                                   unhashedPhone: unhashedPhone,
                                   count: count)
        }

        let existingUsersPayload = try JSONDecoder().decode(ExistingUsersPayload.self, from: data)
        var returnedUsers: [ADUser] = []
        for userPayloadData in existingUsersPayload.existing_users {
            if let cachedUser = UserCache.shared.user(forID: userPayloadData.id) {
                await cachedUser.merge(with: userPayloadData)
                returnedUsers.append(cachedUser)
                UserCache.shared.cache(user: cachedUser)
            } else {
                let newUser = ADUser()
                await newUser.merge(with: userPayloadData)
                returnedUsers.append(newUser)
                UserCache.shared.cache(user: newUser)
            }
        }

        return ContactUpsertResponse(leaderboard: leaderboard,
                                     contactsOnAD: returnedUsers)
    }
}

struct ExistingUsersPayload: Codable {
    var existing_users: [UserPayload.PayloadData]
}

extension FriendFinderAPI {
    struct LeaderboardItem: Codable {
        var hashedPhone: String
        var unhashedPhone: String
        var count: Int
    }

    struct ContactUpsertResponse {
        var leaderboard: [LeaderboardItem]
        var contactsOnAD: [ADUser]
    }
}

enum FriendFinderAPIError: Error {
    case urlEncodingError
    case upsertError(_ responseString: String?)
    case leaderboardRequestError(_ responseString: String?)
    case leaderboardDecodingError
    case couldntGetCurrentUserPhone
    case contactsNotAuthorized
}

class FriendFinderUser: NSObject, ObservableObject, Identifiable {
    var adUser: ADUser?
    @Published var name: String
    @Published var phoneNumber: String
    @Published var contactProfilePhoto: UIImage?
    @Published var isInContacts: Bool
    @Published var friendState: FriendState
    @Published var contactCount: Int
    @Published var wasSearched: Bool

    init(adUser: ADUser?,
         name: String,
         phoneNumber: String,
         contactProfilePhoto: UIImage?,
         isInContacts: Bool,
         friendState: FriendState,
         contactCount: Int,
         wasSearched: Bool = false) {
        self.adUser = adUser
        self.name = name
        self.phoneNumber = phoneNumber
        self.contactProfilePhoto = contactProfilePhoto
        self.isInContacts = isInContacts
        self.friendState = friendState
        self.contactCount = contactCount
        self.wasSearched = wasSearched
    }

    func markAsInvited() {
        friendState = .invited
        NSUbiquitousKeyValueStore.default.invitedPhoneNumbers.append(phoneNumber)
        Task(priority: .userInitiated) {
            try? await InviteManager.shared.trackInvite(with: phoneNumber)
        }
    }
}

enum FriendState: Int {
    // on AD
    case notAdded
    case added

    // not on AD
    case notInvited
    case invited
}

extension NSUbiquitousKeyValueStore {
    var invitedPhoneNumbers: [String] {
        get {
            if let data = data(forKey: "invitedPhoneNumbers") {
                return (try? JSONDecoder().decode([String].self, from: data)) ?? []
            }

            return []
        }

        set {
            if let encoded = try? JSONEncoder().encode(newValue) {
                set(encoded, forKey: "invitedPhoneNumbers")
                ReloadPublishers.friendInvited.send()
                Mixpanel.mainInstance().people
                    .set(properties: [
                        "numInvitesSent": NSUbiquitousKeyValueStore.default.invitedPhoneNumbers.count
                    ])
            }
        }
    }
}

fileprivate extension NSUbiquitousKeyValueStore {
    var usersOnAD: [ADUser] {
        get {
            if let data = data(forKey: "usersOnAD") {
                return (try? JSONDecoder().decode([ADUser].self, from: data)) ?? []
            }
            return []
        }

        set {
            let encoded = try? JSONEncoder().encode(newValue)
            set(encoded, forKey: "usersOnAD")
        }
    }

    var friendsOfFriends: [FriendsOfFriendsResponsePayload] {
        get {
            if let data = data(forKey: "friendsOfFriends") {
                return (try? JSONDecoder().decode([FriendsOfFriendsResponsePayload].self, from: data)) ?? []
            }
            return []
        }

        set {
            let encoded = try? JSONEncoder().encode(newValue)
            set(encoded, forKey: "friendsOfFriends")
        }
    }

    var leaderboard: [FriendFinderAPI.LeaderboardItem] {
        get {
            if let data = data(forKey: "leaderboard") {
                return (try? JSONDecoder().decode([FriendFinderAPI.LeaderboardItem].self, from: data)) ?? []
            }
            return []
        }

        set {
            let encoded = try? JSONEncoder().encode(newValue)
            set(encoded, forKey: "leaderboard")
        }
    }

    var previouslyUpsertedHashes: [String] {
        get {
            return array(forKey: "previouslyUpsertedHashes") as? [String] ?? []
        }

        set {
            set(newValue, forKey: "previouslyUpsertedHashes")
        }
    }
}


fileprivate extension Data {
    func sha256() -> String {
        return hexStringFromData(input: digest(input: self as NSData))
    }

    private func digest(input : NSData) -> NSData {
        let digestLength = Int(CC_SHA256_DIGEST_LENGTH)
        var hash = [UInt8](repeating: 0, count: digestLength)
        CC_SHA256(input.bytes, UInt32(input.length), &hash)
        return NSData(bytes: hash, length: digestLength)
    }

    private  func hexStringFromData(input: NSData) -> String {
        var bytes = [UInt8](repeating: 0, count: input.length)
        input.getBytes(&bytes, length: input.length)

        var hexString = ""
        for byte in bytes {
            hexString += String(format:"%02x", UInt8(byte))
        }

        return hexString
    }
}

extension String {
    func sha256() -> String {
        if let stringData = self.data(using: String.Encoding.utf8) {
            return stringData.sha256()
        }
        return ""
    }
}

extension String {
    func e164FormattedPhoneNumber() -> String {
        let charSet = CharacterSet(charactersIn: "() -;.")
        var cleaned = components(separatedBy: charSet).joined(separator: "")
        if cleaned.count == 10 && cleaned.first != "1" && cleaned.first != "+" {
            cleaned = "1" + cleaned
        }
        if cleaned.first != "+" {
            cleaned = "+" + cleaned
        }
        return cleaned
    }
}

extension CNContact {
    var e164FormattedPhoneNumber: String? {
        return self.phoneNumbers.first?.value.stringValue.e164FormattedPhoneNumber()
    }
}
