// Licensed under the Any Distance Source-Available License
//
//  MultiUseInviteCode.swift
//  Collectible Manager
//
//  Created by Daniel Kuntz on 11/18/22.
//

import Foundation
import CloudKit

struct MultiUseInviteCode: Codable, Hashable {
    var code: String
    var generatedByUserID: String?
    var redeemedByUserIDs: [String]
    var tieredRewardID: String
    var creationDate: Date = Date()

    var recordID: CKRecord.ID {
        return CKRecord.ID(recordName: code)
    }

    var ckRecord: CKRecord {
        let record = CKRecord(recordType: "MultiUseInviteCode", recordID: recordID)
        record["code"] = code
        record["generatedByUserID"] = generatedByUserID
        record["redeemedByUserIDs"] = redeemedByUserIDs
        record["tieredRewardID"] = tieredRewardID
        return record
    }

    init(ckRecord record: CKRecord) {
        code = record.recordID.recordName
        generatedByUserID = record["generatedByUserID"] as? String
        redeemedByUserIDs = record["redeemedByUserIDs"] as? [String] ?? []
        tieredRewardID = record["tieredRewardID"] as? String ?? ""
        creationDate = record.creationDate ?? creationDate
    }

    init(tieredRewardID: String) {
        let characterSet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        code = (1...6)
            .map { _ in String(characterSet.randomElement() ?? Character("A")) }
            .joined()
        generatedByUserID = ADUser.current.id
        self.tieredRewardID = tieredRewardID
        redeemedByUserIDs = []
    }
}
