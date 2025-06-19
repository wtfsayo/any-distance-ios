// Licensed under the Any Distance Source-Available License
//
//  InvitePayload.swift
//  ADAC
//
//  Created by Daniel Kuntz on 5/22/23.
//

import Foundation
import BetterCodable

struct InviteResponsePayload: Codable {
    var invitedAt: UInt64?
    var invitedBy: String?
    var wasInvited: Bool
}
