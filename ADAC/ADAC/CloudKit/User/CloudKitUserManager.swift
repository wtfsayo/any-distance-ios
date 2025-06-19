// Licensed under the Any Distance Source-Available License
//
//  CloudKitUserManager.swift
//  ADAC
//
//  Created by Daniel Kuntz on 12/21/20.
//

import CloudKit
import Sentry

final class CloudKitUserManager {

    // MARK: - Singleton

    static let shared = CloudKitUserManager()

    private var isUpdatingUser: Bool = false
    private let container = CKContainer(identifier: "iCloud.com.anydistance.anydistance.cloudkit")

    // MARK: - ADUser
    
    func user(with id: String) async -> ADUser? {
        let user: ADUser? = await withCheckedContinuation { continuation in
            fetchAndUpdateCurrentUser(withId: id) { success in
                if success {
                    continuation.resume(returning: ADUser.current)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
        
        return user
    }

    func fetchAndUpdateCurrentUser(withId id: String, completion: @escaping ((_ success: Bool) -> Void)) {
        if id.contains("anon") || isUpdatingUser {
            completion(false)
            return
        }

        Task {
            guard let user = await fetchUser(withID: id) else {
                completion(false)
                return
            }

            DispatchQueue.main.async {
                ADUser.current = user
                let betaDay1Granted = CollectibleManager.grantBetaAndDay1CollectibleIfNecessary()
                let preseedGranted = CollectibleManager.grantPreseedCollectibleIfNecessary()
                if betaDay1Granted || preseedGranted {
                    CloudKitUserManager.shared.saveCurrentUser {
                        completion(true)
                    }
                } else {
                    print("Fetched current user successfully.")
                    completion(true)
                }
            }
        }
    }

    func fetchUser(withID id: String) async -> ADUser? {
        if id.isEmpty {
            return nil
        }

        print("Fetching user \(id) from CloudKit...")
        let recordID = CKRecord.ID(recordName: id)
        return await withCheckedContinuation { continuation in
            container.publicCloudDatabase.fetch(withRecordID: recordID) { (record, error) in
                guard let record = record, error == nil else {
                    print(error?.localizedDescription ?? "")
                    continuation.resume(returning: nil)
                    return
                }

                continuation.resume(returning: ADUser(ckRecord: record))
            }
        }
    }

    func saveCurrentUser(completion: (() -> Void)? = nil) {
        guard ADUser.current.hasRegistered else {
            completion?()
            return
        }

        isUpdatingUser = true
        print("Attempting to update the current user in CloudKit...")

        Task {
            do {
                try await saveUsers([ADUser.current])
                print("Current user updated successfully.")
                self.isUpdatingUser = false
                completion?()
            } catch {
                print(error)
                print("No current user. Creating new user in CloudKit.")
                self.createUser(completion: completion)
                self.isUpdatingUser = false
            }
        }
    }

    func saveCurrentUserAsync() async {
        await withCheckedContinuation { continuation in
            saveCurrentUser {
                continuation.resume()
            }
        }
    }

    func saveUsers(_ users: [ADUser]) async throws {
        let records = users.map { $0.ckRecord }
        let operation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
        operation.savePolicy = .allKeys
        let operationConfiguration = CKOperation.Configuration()
        operationConfiguration.allowsCellularAccess = true
        operationConfiguration.qualityOfService = .userInitiated
        operation.configuration = operationConfiguration

        let _: Bool = try await withCheckedThrowingContinuation { continuation in
            operation.modifyRecordsResultBlock = { result in
                do {
                    try result.get()
                    continuation.resume(returning: true)
                } catch {
                    print(error)
                    continuation.resume(throwing: error)
                }
            }

            container.publicCloudDatabase.add(operation)
        }
    }

    func deleteCurrentUser(_ completion: @escaping (Bool) -> Void) {
        guard !ADUser.current.id.isEmpty else {
            return
        }

        let record = ADUser.current.ckRecord
        let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: [record.recordID])
        let operationConfiguration = CKOperation.Configuration()
        operationConfiguration.allowsCellularAccess = true
        operationConfiguration.qualityOfService = .userInitiated
        operation.configuration = operationConfiguration

        operation.modifyRecordsCompletionBlock = { (saved, deleted, error) in
            DispatchQueue.main.async {
                if let error = error {
                    print("CloudKitManager.deleteCurrentUser error: \(error)")
                    completion(false)
                    return
                }

                ADUser.current = ADUser()
                LegacyActivityCache.deleteAppleHealthCache()
                completion(true)
            }
        }

        container.publicCloudDatabase.add(operation)
    }

    private func createUser(completion: (() -> Void)? = nil) {
        let record = ADUser.current.ckRecord

        container.publicCloudDatabase.save(record) { (record, error) in
            if let error = error {
                print("Could not create new user " + error.localizedDescription)
            }

            if let record = record {
                print("Created new user successfully.")
                ADUser.current = ADUser(ckRecord: record)
//                print(ADUser.current)
            }

            completion?()
        }
    }
}
