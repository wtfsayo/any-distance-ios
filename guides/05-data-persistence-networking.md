# Data Persistence & Networking in iOS: A Web Developer's Guide

This guide covers data persistence and networking patterns in iOS development, comparing them to web development approaches and showcasing real implementations from the Any Distance codebase.

## Table of Contents
1. [Data Persistence Options](#data-persistence-options)
2. [Networking Patterns](#networking-patterns)
3. [API Integration Patterns](#api-integration-patterns)
4. [Offline-First Development](#offline-first-development)
5. [Data Models and Codable](#data-models-and-codable)
6. [Real-World Examples](#real-world-examples)

## Data Persistence Options

### UserDefaults vs localStorage

**Web (localStorage):**
```javascript
// Simple key-value storage
localStorage.setItem('user_preference', 'dark_mode');
const preference = localStorage.getItem('user_preference');
localStorage.removeItem('user_preference');
```

**iOS (UserDefaults):**
```swift
// From Any Distance: UserDefaults+Recording.swift
extension NSUbiquitousKeyValueStore {
    var defaultRecordingSettings: RecordingSettings {
        get {
            if let encoded = data(forKey: "recordingSettings"),
               let decoded = try? JSONDecoder().decode(RecordingSettings.self, from: encoded) {
                return decoded
            }
            return RecordingSettings()
        }
        
        set {
            if let encoded = try? JSONEncoder().encode(newValue) {
                set(encoded, forKey: "recordingSettings")
                WatchPreferences.shared.sendPreferencesToWatch()
            }
        }
    }
}
```

**Key Differences:**
- iOS uses `NSUbiquitousKeyValueStore` for iCloud-synced preferences
- UserDefaults has type-specific methods (`bool(forKey:)`, `integer(forKey:)`)
- Complex objects need encoding/decoding in iOS
- iOS has app group UserDefaults for sharing between app extensions

### Core Data vs SQL Databases

**Web (SQL/IndexedDB):**
```javascript
// Using IndexedDB
const request = indexedDB.open('MyDatabase', 1);
request.onsuccess = (event) => {
    const db = event.target.result;
    const transaction = db.transaction(['activities'], 'readwrite');
    const store = transaction.objectStore('activities');
    store.add({ id: 1, name: 'Morning Run', distance: 5000 });
};
```

**iOS (Core Data alternative - Cache library):**
```swift
// From Any Distance: ActivitiesData.swift
class ActivitiesData: ObservableObject {
    private let activitiesCache: Storage<String, [CachedActivity]>?
    
    private init() {
        let diskConfig = DiskConfig(name: "com.anydistance.ActivitiesCache")
        let memoryConfig = MemoryConfig(expiry: .never, countLimit: 500, totalCostLimit: 10)

        activitiesCache = try? Storage<String, [CachedActivity]>(
            diskConfig: diskConfig,
            memoryConfig: memoryConfig,
            transformer: TransformerFactory.forCodable(ofType: [CachedActivity].self)
        )
    }
    
    func cacheActivities(activities: [Activity]) {
        try? activitiesCache?.setObject(activities.map { CachedActivity(from: $0) },
                                        forKey: "activities")
    }
}
```

### CloudKit vs Cloud Databases

**Web (Firebase/MongoDB):**
```javascript
// Firebase example
firebase.firestore().collection('users').doc(userId).set({
    name: 'John Doe',
    email: 'john@example.com'
});
```

**iOS (CloudKit):**
```swift
// From Any Distance: CloudKitUserManager.swift
class CloudKitUserManager {
    func fetchUser(withID id: String) async -> ADUser? {
        // CloudKit operations
        // Note: Actual implementation would use CKDatabase operations
    }
}
```

### Keychain for Secure Storage

**iOS-specific secure storage:**
```swift
// From Any Distance: KeychainStore.swift
class KeychainStore {
    private let keychain = Keychain(service: "com.anydistance.AnyDistance")
    
    func authorization(for service: ExternalService) -> ExternalServiceAuthorization? {
        guard let data = keychain[data: service.keychainAuthorizationKey] else { return nil }
        let decoder = JSONDecoder()
        return try? decoder.decode(ExternalServiceAuthorization.self, from: data)
    }
    
    func save(authorization: ExternalServiceAuthorization) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(authorization)
        keychain[data: authorization.service.keychainAuthorizationKey] = data
    }
}
```

## Networking Patterns

### URLSession vs fetch API

**Web (fetch):**
```javascript
const response = await fetch('https://api.example.com/users', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ name: 'John' })
});
const data = await response.json();
```

**iOS (URLSession with async/await):**
```swift
// From Any Distance: UserManager.swift
func createUser(_ user: ADUser) async throws {
    let url = baseUrl.appendingPathComponent("create")
    let payload = UserPayload(user: user)
    var request = try Edge.defaultRequest(with: url, method: .post)
    request.httpBody = try JSONEncoder().encode(payload)
    
    let (data, response) = try await URLSession.shared.data(for: request)
    guard (response as? HTTPURLResponse)?.statusCode == 201 else {
        let stringData = String(data: data, encoding: .utf8)
        throw UserManagerError.requestError(stringData)
    }
    
    let responsePayload = try JSONDecoder().decode(UserPayload.self, from: data)
    await user.merge(with: responsePayload.user)
}
```

### Alamofire vs axios

**Web (axios):**
```javascript
const response = await axios.post('/api/users', {
    firstName: 'John',
    lastName: 'Doe'
});
```

**iOS (Alamofire):**
```swift
// From Any Distance: Edge.swift
import Alamofire

class Edge {
    static func defaultRequest(with url: URL, method: HTTPMethod) throws -> URLRequest {
        let timestamp = Int(Date().timeIntervalSince1970)
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        if components?.queryItems == nil {
            components?.queryItems = []
        }
        components?.queryItems?.append(
            URLQueryItem(name: "ts", value: String(timestamp))
        )
        guard let urlWithComponents = components?.url else {
            throw EdgeError.urlEncodingError
        }

        var request = try URLRequest(url: urlWithComponents, method: method)
        return request
    }
}
```

### Combine for Reactive Programming vs RxJS

**Web (RxJS):**
```javascript
import { fromEvent } from 'rxjs';
import { debounceTime, map } from 'rxjs/operators';

const searchBox = document.getElementById('search');
fromEvent(searchBox, 'input').pipe(
    debounceTime(300),
    map(event => event.target.value)
).subscribe(value => {
    searchAPI(value);
});
```

**iOS (Combine):**
```swift
// From Any Distance: KeychainStore.swift
import Combine

class KeychainStore {
    let expiredService: AnyPublisher<ExternalService, Never>
    private let expiredServiceValue = PassthroughSubject<ExternalService, Never>()
    
    fileprivate init() {
        expiredService = expiredServiceValue.eraseToAnyPublisher()
    }
    
    func save(authorization: ExternalServiceAuthorization) throws {
        // ... save logic ...
        if authorization.expired {
            expiredServiceValue.send(authorization.service)
        }
    }
}
```

## API Integration Patterns

### OAuth Implementation (Garmin, Wahoo)

```swift
// From Any Distance: ExternalServiceAuthorization.swift
struct ExternalServiceAuthorization: Codable, Equatable {
    let token: String
    let refreshToken: String
    let secret: String
    let service: ExternalService
    var expired = false
}

// Usage in ActivitiesData.swift
func isAuthorized(for provider: ActivitiesProvider) async throws -> Bool {
    switch provider {
    case .appleHealth:
        return hkActivitiesStore.hasRequestedAuthorization()
    case .wahoo:
        return try await wahooActivitiesStore.isAuthorizedForAllTypes()
    case .garmin:
        return try await garminActivitiesStore.isAuthorizedForAllTypes()
    }
}
```

### REST API Client Implementation

```swift
// From Any Distance: UserManager.swift
class UserManager {
    static let shared = UserManager()
    private let baseUrl = Edge.host.appendingPathComponent("users")
    
    // GET Request
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
        return responsePayload
    }
    
    // POST Request with Query Parameters
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
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            let stringData = String(data: data, encoding: .utf8)
            throw UserManagerError.requestError(stringData)
        }
    }
}
```

### Error Handling and Retry Logic

```swift
// From Any Distance: UserManager.swift
enum UserManagerError: Error {
    case requestError(_ errorString: String?)
    case urlEncodingError
    case responseDecodingError
}

func loadUserState() async {
    if ADUser.current.id.isEmpty {
        // User needs to migrate
        print("Migrating cached user to Edge...")
        do {
            try await self.createUser(ADUser.current)
        } catch let error {
            if let error = error as? UserManagerError {
                switch error {
                case .requestError(_):
                    // Retry with update instead of create
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
    }
}
```

## Offline-First Development

### Caching Strategy

```swift
// From Any Distance: ActivitiesData.swift
class ActivitiesData: ObservableObject {
    private let activitiesCache: Storage<String, [CachedActivity]>?
    @Published private(set) var activities: [ActivityIdentifiable] = []
    
    private init() {
        // Load from cache immediately
        if let cachedActivities = try? activitiesCache?.object(forKey: "activities") {
            activities = cachedActivities
                .filter { /* filtering logic */ }
                .sorted(by: { /* sorting logic */ })
                .map { ActivityIdentifiable(activity: $0) }
        }
    }
    
    func load(updateUserAndCollectibles: Bool = true) async {
        do {
            // Fetch fresh data
            let loadedActivities = try await allActivities
            activities = loadedActivities
                .sorted(by: { /* sorting logic */ })
                .map { ActivityIdentifiable(activity: $0) }
            
            // Update cache
            cacheActivities(activities: loadedActivities)
        } catch {
            // Fall back to cached data
            SentrySDK.capture(error: error)
        }
    }
}
```

### Sync Strategy with Multiple Data Sources

```swift
// From Any Distance: ActivitiesData.swift
private var allActivities: [Activity] {
    get async throws {
        let activities = await withTaskGroup(of: [Activity].self) { group in
            // Load from HealthKit
            group.addTask {
                do {
                    let hasGarminConnected = try await self.isAuthorized(for: .garmin)
                    let filteredHKActivities = (try await self.hkActivitiesStore.load()).filter { activity in
                        // Filter out duplicates from other sources
                        guard let healthKitSource = activity.workoutSource else {
                            return true
                        }
                        if healthKitSource == .garminConnect && hasGarminConnected {
                            return false
                        }
                        return true
                    }
                    return filteredHKActivities
                } catch {
                    SentrySDK.capture(error: error)
                    return []
                }
            }
            
            // Load from Wahoo
            group.addTask {
                do {
                    return try await self.wahooActivitiesStore.load()
                } catch {
                    SentrySDK.capture(error: error)
                    return []
                }
            }
            
            // Load from Garmin
            group.addTask {
                do {
                    return try await self.garminActivitiesStore.load()
                } catch {
                    SentrySDK.capture(error: error)
                    return []
                }
            }
            
            var allActivities: [Activity] = []
            for await result in group {
                allActivities.append(contentsOf: result)
            }
            
            return allActivities
        }
        
        return activities.activitiesByRemovingDuplicates()
    }
}
```

## Data Models and Codable

### Defining Data Models (like TypeScript interfaces)

**TypeScript:**
```typescript
interface User {
    id: string;
    name: string;
    email: string;
    profilePhotoUrl?: string;
    friendIDs: string[];
}
```

**Swift (Codable):**
```swift
// From Any Distance: UserPayload.swift (inferred structure)
struct UserPayload: Codable {
    let user: ADUser
}

class ADUser: Codable {
    var id: String = ""
    var name: String = ""
    var email: String = ""
    var profilePhotoUrl: URL?
    var friendIDs: [String] = []
    
    // Custom coding keys if needed
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case email
        case profilePhotoUrl = "profile_photo_url"
        case friendIDs = "friend_ids"
    }
}
```

### Nested Data Models

```swift
// From Any Distance: ExternalServiceAuthorization.swift
struct ExternalServiceAuthorization: Codable, Equatable {
    let token: String
    let refreshToken: String
    let secret: String
    let service: ExternalService
    var expired = false
}

enum ExternalService: String, Codable {
    case garmin
    case wahoo
    
    var keychainAuthorizationKey: String {
        "\(rawValue)-authorization"
    }
}
```

## Real-World Examples

### Complete API Client Example

```swift
// From Any Distance: S3.swift - File Upload Implementation
class S3 {
    static func uploadImage(_ image: UIImage, resizeToWidth: CGFloat = 1000.0) async throws -> URL {
        // Prepare image
        let resizedImage: UIImage = {
            if image.size.width <= resizeToWidth {
                return image
            }
            return image.resized(withNewWidth: resizeToWidth, imageScale: 1.0)
        }()
        guard let imageData = resizedImage.jpegData(compressionQuality: 0.9) else {
            throw S3Error.cantEncodeImage
        }

        // Build URL
        let url = Edge.host
            .appendingPathComponent("media")
            .appendingPathComponent("upload")
        let fileName = UUID().uuidString + ".jpg"
        let filePath = ADUser.current.id + "/" + fileName
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        components?.queryItems = [
            URLQueryItem(name: "path", value: filePath)
        ]
        guard let urlWithComponents = components?.url else {
            throw S3Error.urlEncodingError
        }

        // Create multipart request
        var request = try Edge.defaultRequest(with: urlWithComponents, method: .post)
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        // Generate multipart form data
        var formData = Data()
        formData.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
        formData.append("Content-Disposition: form-data; name=\"media\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        formData.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        formData.append(imageData)
        formData.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        // Upload
        let (data, response) = try await URLSession.shared.upload(for: request, from: formData)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            let stringData = String(data: data, encoding: .utf8)
            throw S3Error.requestError(stringData)
        }

        // Parse response
        let json = try JSON(data: data)
        let mediaJSON = try json["media"].rawData()
        let responsePayload = try JSONDecoder().decode(S3UploadResponsePayload.self, from: mediaJSON)
        if let url = URL(string: responsePayload.assetURL) {
            return url
        } else {
            throw S3Error.uploadedURLDecodingError
        }
    }
}
```

### Async Data Fetching Pattern

```swift
// From Any Distance: UserManager.swift
func searchUsers(by term: String) async throws -> [ADUser] {
    return try await getUsers(by: "search",
                              value: term, isSearch: true,
                              hydrateAllCollectibles: false)
}

private func getUsers(by field: String,
                      value: String,
                      isSearch: Bool = false,
                      hydrateAllCollectibles: Bool) async throws -> [ADUser] {
    // Build request body
    var body: String = ""
    body.append("\(field)=\(value)")
    if isSearch {
        body.append("&field=all")
    }
    body = body.replacingOccurrences(of: "+", with: "%2b")

    // Create request
    var request = try Edge.defaultRequest(with: baseUrl, method: .post)
    request.httpBody = body.data(using: .utf8, allowLossyConversion: true)

    // Execute request
    let (data, response) = try await URLSession.shared.data(for: request)
    guard (response as? HTTPURLResponse)?.statusCode == 200 else {
        let stringData = String(data: data, encoding: .utf8)
        throw UserManagerError.requestError(stringData)
    }

    // Parse and cache response
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
```

### Push Notification Integration

```swift
// From Any Distance: UserManager.swift
func sendFriendRequest(to targetUserID: ADUser.ID) async throws {
    // ... API request code ...
    
    // Send push notification
    NotificationsManager.sendNotification(to: targetUserID,
                                          withCategory: "FRIEND_REQUEST",
                                          message: "@\(ADUser.current.username ?? "") sent you a friend request.",
                                          appUrl: "anydistance://friends?selectedSegment=2",
                                          type: .friendRequest)
}
```

## Key Takeaways

1. **Persistence**: iOS offers multiple storage options - UserDefaults for simple preferences, Keychain for secure data, Core Data/Cache libraries for complex data, and CloudKit for cloud sync.

2. **Networking**: URLSession is the foundation, with Alamofire providing convenience. Async/await makes code cleaner than callbacks.

3. **Codable**: Swift's Codable protocol is like TypeScript interfaces but with built-in serialization.

4. **Offline-First**: Cache data locally and sync when network is available. Handle multiple data sources by merging and deduplicating.

5. **Error Handling**: Use typed errors and handle network failures gracefully with retry logic.

6. **Security**: Use Keychain for sensitive data like OAuth tokens. Never store credentials in UserDefaults.

7. **Performance**: Use concurrent loading with TaskGroup, cache aggressively, and debounce user input with Combine.