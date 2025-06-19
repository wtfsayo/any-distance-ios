// Licensed under the Any Distance Source-Available License
//
//  OneSignal+Extensions.swift
//  ADAC
//
//  Created by Jarod Luebbert on 10/7/22.
//

import Foundation
import OneSignal

extension OneSignal {
    
    class func sendTagsForTeamADAC() {
        let teamMemberTag = "adac_team_member"
        if ADUser.current.isTeamADAC {
            OneSignal.sendTag(teamMemberTag, value: "1")
        } else {
            OneSignal.deleteTag(teamMemberTag)
        }
    }
    
}
