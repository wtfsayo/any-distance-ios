// Licensed under the Any Distance Source-Available License
//
//  InviteManager.swift
//  ADAC
//
//  Created by Daniel Kuntz on 5/22/23.
//

import Foundation
import Mixpanel

class InviteManager {

    static let shared = InviteManager()
    private let baseUrl = Edge.host.appendingPathComponent("invites")

    // MARK: - Invite Tracking

    func trackInvite(with targetPhone: String) async throws {
        let url = baseUrl
            .appendingPathComponent("track")
            .appendingPathComponent("start")

        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        let encodedTargetPhone = targetPhone.replacingOccurrences(of: "+", with: "%2B")
        guard let encodedFromPhone = ADUser.current.phoneNumber?.replacingOccurrences(of: "+", with: "%2B") else {
            return
        }

        components?.queryItems = [
            URLQueryItem(name: "targetPhone", value: encodedTargetPhone),
            URLQueryItem(name: "fromPhone", value: encodedFromPhone)
        ]
        guard let urlWithComponenets = components?.url else {
            throw InviteManagerError.urlEncodingError
        }

        let request = try Edge.defaultRequest(with: urlWithComponenets, method: .post)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            let stringData = String(data: data, encoding: .utf8)
            throw InviteManagerError.requestError(stringData)
        }
    }

    func checkInvite(with targetPhone: String?) async throws {
        guard let targetPhone = targetPhone else {
            return
        }

        let url = baseUrl
            .appendingPathComponent("track")
            .appendingPathComponent("check")

        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        let encodedTargetPhone = targetPhone.replacingOccurrences(of: "+", with: "%2B")
        components?.queryItems = [
            URLQueryItem(name: "targetPhone", value: encodedTargetPhone)
        ]
        guard let urlWithComponenets = components?.url else {
            throw InviteManagerError.urlEncodingError
        }

        let request = try Edge.defaultRequest(with: urlWithComponenets, method: .post)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            let stringData = String(data: data, encoding: .utf8)
            throw InviteManagerError.requestError(stringData)
        }

        let payload = try JSONDecoder().decode(InviteResponsePayload.self, from: data)
        sendMixpanelEvents(for: payload)
    }

    private func sendMixpanelEvents(for response: InviteResponsePayload) {
        if response.wasInvited,
           let invitedBy = response.invitedBy,
           let invitedAt = Date(timeIntervalSince1970: response.invitedAt) {
            UserManager.shared.initializeConnectedServices()
            let invitedByPhone = invitedBy.replacingOccurrences(of: "%2B", with: "+")
            Mixpanel.mainInstance().people.set(properties: [
                "invitedBy": invitedByPhone,
                "invitedAt": invitedAt,
                "timeToAcceptInvite": (Date().timeIntervalSince(invitedAt))
            ])
            Analytics.logEvent("Invite Redeemed", "AC Onboarding", .otherEvent,
                               withParameters: ["invitedBy": invitedByPhone,
                                                "invitedAt": invitedAt,
                                                "timeToAcceptInvite": (Date().timeIntervalSince(invitedAt))])
            Mixpanel.mainInstance().flush(performFullFlush: true)
        }
    }
}

enum InviteManagerError: Error {
    case requestError(_ errorString: String?)
    case urlEncodingError
}
