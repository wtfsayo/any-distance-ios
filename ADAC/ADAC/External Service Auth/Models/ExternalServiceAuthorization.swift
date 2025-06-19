// Licensed under the Any Distance Source-Available License
//
//  ExternalServiceAuthorization.swift
//  ADAC
//
//  Created by Jarod Luebbert on 4/13/22.
//

import Foundation

struct ExternalServiceAuthorization: Codable, Equatable {
    let token: String
    let refreshToken: String
    let secret: String
    let service: ExternalService
    
    var expired = false
}
