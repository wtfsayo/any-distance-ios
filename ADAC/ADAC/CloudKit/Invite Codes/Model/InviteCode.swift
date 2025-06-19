// Licensed under the Any Distance Source-Available License
//
//  InviteCode.swift
//  ADAC
//
//  Created by Daniel Kuntz on 9/1/22.
//

import Foundation
import CloudKit

struct InviteCode: Codable, Hashable {
    var code: String
    var used: Bool = false
    var usedByUserID: String?
    var generatedByUserID: String?
    var creationDate: Date = Date()

    var recordID: CKRecord.ID {
        return CKRecord.ID(recordName: code)
    }

    var ckRecord: CKRecord {
        let record = CKRecord(recordType: "InviteCode", recordID: recordID)
        record["used"] = used
        record["usedByUserID"] = usedByUserID
        record["generatedByUserID"] = generatedByUserID
        return record
    }

    init(ckRecord record: CKRecord) {
        code = record.recordID.recordName
        used = record["used"] as? Bool ?? false
        usedByUserID = record["usedByUserID"] as? String
        generatedByUserID = record["generatedByUserID"] as? String
        creationDate = record.creationDate ?? creationDate
    }

    init() {
        let characterSet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        code = (1...6)
            .map { _ in String(characterSet.randomElement() ?? Character("A")) }
            .joined()
        generatedByUserID = ADUser.current.id
    }

    var shareMessage: String {
        return "Hey! I thought you might like early access to the new @anydistance activity tracking experience 👀 Your invite code is \(code) if you want in. Install it from the app store here: https://anyd.ist/early-access"
    }
}

