// Licensed under the Any Distance Source-Available License
//
//  KeychainStore.swift
//  ADAC
//
//  Created by Jarod Luebbert on 4/14/22.
//

import Foundation
import KeychainAccess
import Combine

fileprivate extension ExternalService {
    
    var keychainAuthorizationKey: String {
        "\(rawValue)-authorization"
    }
    
}

class KeychainStore {
    
    static let shared = KeychainStore()
    
    let expiredService: AnyPublisher<ExternalService, Never>
    
    func authorization(for service: ExternalService) -> ExternalServiceAuthorization? {
        guard let data = keychain[data: service.keychainAuthorizationKey] else { return nil }
        let decoder = JSONDecoder()
        return try? decoder.decode(ExternalServiceAuthorization.self, from: data)
    }
    
    fileprivate init() {
        expiredService = expiredServiceValue.eraseToAnyPublisher()
    }
    
    // MARK: Private
    
    private let keychain = Keychain(service: "com.anydistance.AnyDistance")
    private let expiredServiceValue = PassthroughSubject<ExternalService, Never>()
    
    // MARK: Actions
        
    func save(authorization: ExternalServiceAuthorization) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(authorization)
        keychain[data: authorization.service.keychainAuthorizationKey] = data
        
        if authorization.expired {
            expiredServiceValue.send(authorization.service)
        }
    }
    
    func deleteAuthorization(for service: ExternalService) {
        keychain[service.keychainAuthorizationKey] = nil
    }
        
}
