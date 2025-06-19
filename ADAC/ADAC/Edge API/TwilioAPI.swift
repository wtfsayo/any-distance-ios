// Licensed under the Any Distance Source-Available License
//
//  TwilioAPI.swift
//  ADAC
//
//  Created by Daniel Kuntz on 3/6/23.
//

import Foundation
import SwiftyJSON

class TwilioAPI {
    private static var baseUrl: URL {
        Edge.host
            .appendingPathComponent("phones")
            .appendingPathComponent("verify")
    }

    static func startVerification(for phone: String) async throws {
        let url = baseUrl.appendingPathComponent("start")
        let jsonData: [String: String] = [
            "phone": phone
        ]
        var request = try Edge.defaultRequest(with: url, method: .post)
        request.httpBody = try JSONEncoder().encode(jsonData)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            let stringData = String(data: data, encoding: .utf8)
            print(stringData)
            throw UserManagerError.requestError(stringData)
        }
    }

    static func checkVerification(for phone: String, code: String) async throws -> Bool {
        let url = baseUrl.appendingPathComponent("check")
        let jsonData: [String: String] = [
            "phone": phone,
            "code": code
        ]
        var request = try Edge.defaultRequest(with: url, method: .post)
        request.httpBody = try JSONEncoder().encode(jsonData)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            let stringData = String(data: data, encoding: .utf8)
            print(stringData)
            throw UserManagerError.requestError(stringData)
        }

        let json = try JSON(data: data)
        if let verified = json["verified"].bool {
            return verified
        }

        throw TwilioAPIError.responseDecodingError
    }
}

enum TwilioAPIError: Error {
    case requestError(_ errorString: String?)
    case responseDecodingError
}
