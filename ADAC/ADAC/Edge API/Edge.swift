// Licensed under the Any Distance Source-Available License
//
//  Edge.swift
//  ADAC
//
//  Created by Daniel Kuntz on 3/3/23.
//

import Foundation
import Alamofire

class Edge {
    static let host = URL(string: "http://google.com/")!
    static let devHost = URL(string: "http://google.com/")!
    static let imgixHost: String = ""
    static let mediaUploadsHost: String = ""
    static let coverPhotoURLPrefix: String = ""
    private static let bearerToken: String = ""

    static func defaultRequest(with url: URL, method: HTTPMethod) throws -> URLRequest {
        let timestamp = Int(Date().timeIntervalSince1970)
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        if components?.queryItems == nil {
            components?.queryItems = []
        }
        components?.queryItems?.append(
            URLQueryItem(name: "ts", value: String(timestamp))
        )
        guard let urlWithComponents = components?.url else {
            throw EdgeError.urlEncodingError
        }

        var request = try URLRequest(url: urlWithComponents, method: method)
        return request
    }

    static func loadInitialAppState(loadFriendFinderState: Bool = true) async {
        await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                await CollectibleLoader.shared.loadCollectibles()
                Task(priority: .userInitiated) {
                    await CollectibleLoader.shared.deleteOneSignalTags(for: Array(NSUbiquitousKeyValueStore.default.remoteCollectibles.values))
                }
                return true
            }

            if ADUser.current.hasFinishedOnboarding {
                if ADUser.current.hasRegistered {
                    group.addTask {
                        _ = await UserManager.shared.loadUserState()
                        return true
                    }
                }

                group.addTask {
                    await ActivitiesData.shared.load(updateUserAndCollectibles: false)
                    return true
                }

                if loadFriendFinderState && ADUser.current.hasRegistered {
                    group.addTask {
                        try? await FriendFinderAPI.shared.load(loadCurrentUser: false)
                        return true
                    }
                }
            }
        }

        await ActivitiesData.shared.updateUserForNewActivities()
    }
}

enum EdgeError: Error {
    case urlEncodingError
}

extension URL {
    var imgixURL: URL {
        if absoluteString.contains(Edge.mediaUploadsHost) {
            let newAbsoluteString = absoluteString
                .replacingOccurrences(of: Edge.mediaUploadsHost,
                                      with: Edge.imgixHost)
                .appending("?auto=compress")
            return URL(string: newAbsoluteString) ?? self
        }

        return self
    }

    var unImgixdURL: URL {
        if absoluteString.contains(Edge.imgixHost) {
            let newAbsoluteString = absoluteString
                .replacingOccurrences(of: Edge.imgixHost,
                                      with: Edge.mediaUploadsHost)
                .replacingOccurrences(of: "?auto=compress", with: "")
            return URL(string: newAbsoluteString) ?? self
        }

        return self
    }

    func imgixURL(with width: CGFloat) -> URL {
        if isImgixURL {
            let stringWithParams = absoluteString + "?w=\(Int(width))&fit=clip"
            return URL(string: stringWithParams) ?? self
        }

        return self
    }

    var isImgixURL: Bool {
        return absoluteString.contains(Edge.imgixHost)
    }
}
