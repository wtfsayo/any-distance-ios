// Licensed under the Any Distance Source-Available License
//
//  NotificationsManager.swift
//  ADAC
//
//  Created by Daniel Kuntz on 2/9/23.
//

import Foundation

class NotificationsManager {
    #if DEBUG
    static let DEBUG: Bool = true // change this one to test
    #else
    static let DEBUG: Bool = false
    #endif

    static func sendNotification(to userID: String,
                                 withCategory category: String,
                                 message: String,
                                 appUrl: String = "",
                                 type: ActiveClubNotificationType) {
        sendNotification(to: [userID],
                         withCategory: category,
                         message: message,
                         appUrl: appUrl,
                         type: type)
    }

    static func sendNotification(to userIDs: [String],
                                 withCategory category: String,
                                 message: String,
                                 appUrl: String = "",
                                 type: ActiveClubNotificationType) {
        guard !DEBUG else {
            return
        }
        
        Task(priority: .userInitiated) {
            do {
                let url = Edge.host
                    .appendingPathComponent("send")
                    .appendingPathComponent("notification")
                let parameters = [
                    "message": message,
                    "category": category,
                    "userIDs": userIDs,
                    "appURL": appUrl,
                    "requiredTags": [type.rawValue]
                ] as [String: Any]

                guard let postData = try? JSONSerialization.data(withJSONObject: parameters, options: []) else {
                    return
                }

                var request = try Edge.defaultRequest(with: url, method: .post)
                request.httpBody = postData
                let (data, response) = try await URLSession.shared.data(for: request)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                    let stringData = String(data: data, encoding: .utf8)
                    throw NotificationsManagerError.requestError(stringData)
                }
            } catch {
                print("Error sending notification: \(error)")
            }
        }
    }
}

enum NotificationsManagerError: Error {
    case requestError(_ errorString: String?)
}
