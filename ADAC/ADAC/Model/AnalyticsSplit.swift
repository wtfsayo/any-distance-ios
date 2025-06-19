// Licensed under the Any Distance Source-Available License
//
//  AnalyticsSplit.swift
//  ADAC
//
//  Created by Daniel Kuntz on 5/16/23.
//

import Foundation
import Mixpanel

// MARK: - Protocol

protocol AnalyticsSplit: Codable, RawRepresentable<String>, CaseIterable {
    static var identifier: String { get }
    var likelihood: Double { get }
}

extension AnalyticsSplit {
    static var analyticsID: String {
        return "split_" + Self.identifier
    }

    static func calculateSplit() -> Self {
        return Self.allCases.map { type in
            [Self](repeating: type,
                   count: Int(type.likelihood * 100))
        }.joined().randomElement()!
    }

    func sendAnalytics() {
        UserManager.shared.initializeConnectedServices()
        Mixpanel.mainInstance().people
            .set(properties: [
                Self.analyticsID: self.rawValue
            ])
        Mixpanel.mainInstance().flush(performFullFlush: true)
    }
}

// MARK: - Split Types

enum AndiHealthAuth: String, AnalyticsSplit {
    static var identifier: String {
        return "andiHealthAuth"
    }

    case showAndi /// show new Andi health auth
    case showOldHealthAuth /// show old Health auth (fake UIAlertController with video)

    var likelihood: Double {
        switch self {
        case .showAndi:
            return 0.5
        case .showOldHealthAuth:
            return 0.5
        }
    }
}

enum OnboardingFirstPageHealth: String, AnalyticsSplit {
    static var identifier: String {
        return "onboardingFirstPageHealth"
    }

    /// Tapping "Start" on the first onboarding screen will show Health auth immediately
    case showHealthAuthOnFirstScreen

    /// Tapping "Start" takes you to a separate screen for authing Health
    case showSeparateHealthAuthScreen

    var likelihood: Double {
        switch self {
        case .showHealthAuthOnFirstScreen:
            return 0.5
        case .showSeparateHealthAuthScreen:
            return 0.5
        }
    }
}

enum OnboardingInvite3Friends: String, AnalyticsSplit {
    static var identifier: String {
        return "onboardingInvite3Friends"
    }

    case requireInvites /// Require inviting 3 friends to proceed through onboarding
    case dontRequireInvites /// Don't require inviting 3 friends

    var likelihood: Double {
        switch self {
        case .requireInvites:
            return 0.5
        case .dontRequireInvites:
            return 0.5
        }
    }
}

enum Invite3FriendsSkipButtonVisibility: String, AnalyticsSplit {
    static var identifier: String {
        return "invite3FriendsSkipButtonVisibility"
    }

    case visible /// Skip button is visible on Invite 3 Friends screen
    case invisible /// Skip button is invisible on Invite 3 Friends screen

    var likelihood: Double {
        switch self {
        case .visible:
            return 0.5
        case .invisible:
            return 0.5
        }
    }
}

enum AddToStoryButtonVisibility: String, AnalyticsSplit {
    static var identifier: String {
        return "addToStoryButtonVisibility"
    }

    case `default`
    case addToStory /// Button in recording that says "Add to Story" instead of "Share"

    var likelihood: Double {
        return 0.5
    }
}

// MARK: - UserDefaults getter

extension NSUbiquitousKeyValueStore {
    func split<T: AnalyticsSplit>(for type: T.Type) -> T {
        if let data = data(forKey: T.identifier),
           let decodedData = try? JSONDecoder().decode(T.self, from: data) {
            return decodedData
        }

        let calculatedSplit = T.calculateSplit()
        let encoded = try! JSONEncoder().encode(calculatedSplit)
        set(encoded, forKey: T.identifier)

        return calculatedSplit
    }
}
