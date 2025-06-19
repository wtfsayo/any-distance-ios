// Licensed under the Any Distance Source-Available License
//
//  InviteCodeManager.swift
//  ADAC
//
//  Created by Daniel Kuntz on 9/6/22.
//

import Foundation
import CloudKit
import Sentry

class InviteCodeManager {

    static let shared = InviteCodeManager()
    private let container = CKContainer(identifier: "iCloud.com.anydistance.anydistance.cloudkit")

    // MARK: - Single Use Codes

    func activityTrackingInviteCodesForUser() async -> [InviteCode] {
        let codeStrings: [String] = []
        if !codeStrings.isEmpty {
            let recordIDs = codeStrings.map { CKRecord.ID(recordName: $0) }
            do {
                let fetchedResults = try await container.publicCloudDatabase.records(for: recordIDs)
                let fetchedRecords: [CKRecord] = fetchedResults.compactMap { _, result in
                    if let record = try? result.get() {
                        return record
                    } else {
                        return nil
                    }
                }
                return fetchedRecords.map { InviteCode(ckRecord: $0) }
            } catch {
                print(error.localizedDescription)
                SentrySDK.capture(error: error)
                return []
            }
        } else {
            do {
                let codes = try await generateSingleUseCodes()
//                ADUser.current.activityTrackingInviteCodes = codes.map { $0.code }
                CloudKitUserManager.shared.saveCurrentUser()
                return codes
            } catch {
                print(error.localizedDescription)
                SentrySDK.capture(error: error)
            }

            return []
        }
    }

    func generateSingleUseCodes(count: Int = 5) async throws -> [InviteCode] {
        guard count >= 1 else {
            return []
        }

        // Generate new codes.
        let codes = (1...count).map { _ in InviteCode() }

        let fetchedRecords = try await container.publicCloudDatabase.records(for: codes.map { $0.recordID })
        for key in fetchedRecords.keys {
            if (try? fetchedRecords[key]?.get()) != nil {
                // One of these codes already exists. Generate new ones.
                return try await self.generateSingleUseCodes()
            }
        }

        // These are all new and unique codes. Save them to the database.
        return try await withCheckedThrowingContinuation { continuation in
            let records = codes.map { $0.ckRecord }
            let operation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
            operation.savePolicy = .allKeys
            let operationConfiguration = CKOperation.Configuration()
            operationConfiguration.allowsCellularAccess = true
            operationConfiguration.qualityOfService = .userInitiated
            operation.configuration = operationConfiguration

            operation.modifyRecordsResultBlock = { result in
                do {
                    try result.get()
                    continuation.resume(returning: codes)
                } catch {
                    // Error saving
                    SentrySDK.capture(error: error)
                    continuation.resume(throwing: error)
                }
            }

            self.container.publicCloudDatabase.add(operation)
        }
    }

    func useSingleUseCode(_ code: String) async throws -> InviteCode {
        // Grab the code from the database.
        var record: CKRecord
        do {
            let recordID = CKRecord.ID(recordName: code)
            record = try await container.publicCloudDatabase.record(for: recordID)
        } catch {
            // Couldn't find this code. Probably invalid.
            print(error)
            throw InviteCodeError.invalidCode
        }

        // Found the code. Check if it's been used.
        var remoteCode = InviteCode(ckRecord: record)
        guard !remoteCode.used else {
            // Code has already been used.
            throw InviteCodeError.alreadyUsed
        }

        // Code has not been used. Use the code.
        remoteCode.used = true
        remoteCode.usedByUserID = ADUser.current.id

        do {
            _ = try await container.publicCloudDatabase.modifyRecords(saving: [remoteCode.ckRecord],
                                                                      deleting: [],
                                                                      savePolicy: .allKeys,
                                                                      atomically: true)
        } catch {
            // Error using the code.
            SentrySDK.capture(error: error)
            throw InviteCodeError.errorUsingCode
        }

        // Code used successfully.
        return remoteCode
    }
}

enum InviteCodeError: Error {
    case alreadyUsed
    case invalidCode
    case errorUsingCode
    case couldNotGenerateCodes(error: Error)

    var description: String {
        switch self {
        case .alreadyUsed:
            return "Invite Code Already Used"
        case .invalidCode:
            return "Invite Code Invalid"
        case .errorUsingCode:
            return "Error Using Invite Code"
        case .couldNotGenerateCodes(let error):
            return error.localizedDescription
        }
    }

    var blurb: String {
        switch self {
        case .alreadyUsed:
            return "Follow @anydistanceclub on Twitter for more"
        case .invalidCode:
            return "Did you type it correctly?"
        case .errorUsingCode:
            return "Contact us at support@anydistance.club"
        case .couldNotGenerateCodes(let error):
            return error.localizedDescription
        }
    }
}

fileprivate extension NSUbiquitousKeyValueStore {
    var fetchedMultiUseCodes: [MultiUseInviteCode] {
        get {
            if let object = data(forKey: "fetchedMultiUseCodes"),
               let array = try? JSONDecoder().decode([MultiUseInviteCode].self, from: object) {
                return array
            }

            return []
        }

        set {
            let data = try? JSONEncoder().encode(newValue)
            set(data, forKey: "fetchedMultiUseCodes")
        }
    }
}
