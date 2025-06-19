// Licensed under the Any Distance Source-Available License
//
//  OnboardingViewModel.swift
//  ADAC
//
//  Created by Daniel Kuntz on 2/24/23.
//

import Foundation
import AuthenticationServices
import Sentry

/// Model for onboarding sequence (including what you see when you first launch the app and active clubs)
class OnboardingViewModel: NSObject, ObservableObject, SignInViewControllerDelegate {
    #if DEBUG
    let DEBUG_APPLE_USER_ID: String? = nil
    let DEBUG_EMAIL: String? = nil
    #else
    let DEBUG_APPLE_USER_ID: String? = nil
    let DEBUG_EMAIL: String? = nil
    #endif

    let screenName = "AC Onboarding"
    @Published var pageIdx: Int = 2
    @Published var state: OnboardingState = .start
    @Published var userProfileImage: UIImage?
    var pageTimer: Timer?

    // Enter phone number
    @Published var phoneNumber: String = ""
    @Published var selectedCountryCode: String = Locale.current.regionCode ?? ""

    // Verify phone number
    @Published var phoneVerificationCode: String = ""

    // Username
    @Published var username: String = ""

    func phoneNumberString() -> String {
        return "+" + (CountryCode.prefixCodes[selectedCountryCode] ?? "") + " " + phoneNumber
    }

    var isPhoneValid: Bool {
        return phoneNumberString().e164FormattedPhoneNumber().count >= CountryCode.minCount(for: selectedCountryCode)
    }

    override init() {
        super.init()

        if !ADUser.current.hasRegistered {
            //
        } else if (ADUser.current.phoneNumber ?? "").isEmpty {
            self.state = .enterPhone
        } else if (ADUser.current.username ?? "").isEmpty {
            self.state = .pickUsername
        }
    }

    func advanceState() {
        DispatchQueue.main.async {
            self.state = OnboardingState(rawValue: self.state.rawValue + 1) ?? self.state
            self.pageIdx = (self.pageIdx + 1) % 3
        }
    }

    func advancePastWelcome() {
        HealthKitActivitiesStore.shared.requestAuthorization(with: screenName) {
            Task(priority: .userInitiated) {
                await ADUser.current.setRandomCoverPhotoIfNecessary(pushChanges: false)
                await MainActor.run {
                    CollectibleManager.grantBetaAndDay1CollectibleIfNecessary()
                    ADUser.current.hasFinishedOnboarding = true
                    ADUser.current.signupDate = Date()
                    UIApplication.shared.transitionToTabBar()
                }
            }
        }
    }

    func signInTopLeftButton() {
        if let signInVC = UIStoryboard(name: "Onboarding", bundle: nil).instantiateViewController(withIdentifier: "signIn") as? SignInViewController {
            signInVC.delegate = self
            signInVC.function = .signIn
            UIApplication.shared.topViewController?.present(signInVC, animated: true)
        }
    }

    func resetPageTimer() {
        pageTimer?.invalidate()
        pageTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { _ in
            self.pageIdx = (self.pageIdx + 1) % 3
        }
    }

    func stopPageTimer() {
        pageTimer?.invalidate()
    }

    func verifyPhone() {
        if DEBUG_APPLE_USER_ID != nil || DEBUG_EMAIL != nil {
            self.state = .enterPhoneVerification
            return
        }

        Task {
            do {
                let formattedPhone = phoneNumberString().e164FormattedPhoneNumber()
                try await TwilioAPI.startVerification(for: formattedPhone)
                DispatchQueue.main.async {
                    self.state = .enterPhoneVerification
                }
            } catch {
                DispatchQueue.main.async {
                    UIApplication.shared.topViewController?.showFailureToast(with: error)
                }
            }
        }
    }

    func checkVerification() async throws -> Bool {
        if DEBUG_APPLE_USER_ID != nil || DEBUG_EMAIL != nil {
            return true
        }

        return try await TwilioAPI.checkVerification(for: phoneNumberString().e164FormattedPhoneNumber(),
                                                     code: phoneVerificationCode)
    }

    func setUserPhone() {
        ADUser.current.phoneNumber = phoneNumberString().e164FormattedPhoneNumber()
        updateUser()
    }

    func checkUsername() async throws -> Bool {
        return try await UserManager.shared.checkAvailable(username: username)
    }

    func setUsername() {
        ADUser.current.username = username
        updateUser()
    }

    private func updateUser() {
        Task {
            do {
                try await UserManager.shared.updateUser(ADUser.current)
            } catch {
                DispatchQueue.main.async {
                    UIApplication.shared.topViewController?.showFailureToast(with: error)
                }
            }
        }
    }

    func authorizationController(didCompleteWithAuthorization authorization: ASAuthorization) {
        switch authorization.credential {
        case let appleIDCredential as ASAuthorizationAppleIDCredential:
            let userIdentifier = DEBUG_APPLE_USER_ID ?? appleIDCredential.user
            let fullName = appleIDCredential.fullName
            let email = DEBUG_EMAIL ?? appleIDCredential.email
            stopPageTimer()
            Task {
                await UserManager.shared.signIn(withId: userIdentifier, fullName, email)
                DispatchQueue.main.async {
                    self.transitionToNextSignupStep()
                    self.username = (fullName?.givenName ?? "").lowercased() + (fullName?.familyName ?? "").lowercased()
                    Analytics.logEvent("Sign In Successful", self.screenName, .otherEvent)
                }
            }
        default:
            break
        }
    }

    private func transitionToNextSignupStep() {
        DispatchQueue.main.async {
            if (ADUser.current.phoneNumber == nil || (ADUser.current.phoneNumber?.isEmpty ?? true)) {
                self.state = .enterPhone
            } else if (ADUser.current.username == nil || (ADUser.current.username?.isEmpty ?? true)) {
                self.state = .pickUsername
            } else {
                UIApplication.shared.transitionToTabBar()
            }
        }
    }
}

extension UIApplication {
    func transitionToTabBar() {
        let mainTabBar = UIStoryboard(name: "TabBar", bundle: nil).instantiateViewController(withIdentifier: "mainTabBar") as? ADTabBarController
        mainTabBar?.modalPresentationStyle = .overFullScreen
        mainTabBar?.setSelectedTab(.track)
        UIView.animate(withDuration: 0.2) {
            UIApplication.shared.topWindow?.alpha = 0.0
        } completion: { _ in
            UIApplication.shared.topWindow?.rootViewController = mainTabBar
            UIView.animate(withDuration: 0.2) {
                UIApplication.shared.topWindow?.alpha = 1.0
            }
        }
    }
}

/// State enum for different onboarding screens
enum OnboardingState: Int {
    case start
    case welcome1
    case welcome2
    case welcome3
    case welcome4
    case connectHealth
    case signIn
    case enterPhone
    case enterPhoneVerification
    case pickUsername
    case findFriendsAllowPermission
    case searchingForFriends
    case searchingError
    case viewingContacts
}

extension OnboardingState {
    var titleText: String {
        switch self {
        case .start:
            return ""
        case .welcome3:
            return "Assemble your Active Club"
        case .welcome4:
            return "A fresh start every week"
        case .welcome1:
            return "Peace of mind activity tracking"
        case .welcome2:
            return "Collect'em all Collectibles"
        case .connectHealth:
            return "Got it? Great! Let's get started"
        case .signIn:
            return "Setup your profile"
        case .enterPhone:
            return "Your Phone Number"
        case .enterPhoneVerification:
            return "Your Phone Number"
        case .pickUsername:
            return "Pick your username"
        case .findFriendsAllowPermission:
            return "Let's find your friends"
        case .searchingForFriends:
            return "Searching your contacts"
        case .searchingError:
            return "Oops, that didn't work"
        case .viewingContacts:
            return "Let's build your\nActive Club"
        }
    }

    func subtitleText(for phone: String?) -> String {
        switch self {
        case .start:
            return "A new home for your active lifestyle."
        case .welcome3:
            return "A private feed to celebrate your active lifestyle with your closest friends."
        case .welcome4:
            return "Post an activity to see your friends' posts for the week. Every week is a fresh start."
        case .welcome1:
            return "Private and safe tracking for over 90+ inclusive activity types."
        case .welcome2:
            return "Earn achievements, rewards and digital collectibles."
        case .connectHealth:
            return "We securely read your activity data from Apple Health."
        case .signIn:
            return "Sign in with Apple to build your Active Club."
        case .enterPhone:
            return "We use your phone number to find your friends."
        case .enterPhoneVerification:
            if let phone = phone {
                return "Enter the code we just texted to \(phone)"
            } else {
                return "Enter the code we just texted to your phone number."
            }
        case .pickUsername:
            return "Your unique username across the world of Any Distance"
        case .findFriendsAllowPermission, .searchingForFriends:
            return "Find your friends already using Any Distance. Your contacts will be securely encrypted and uploaded to our servers. This step is optional."
        case .searchingError:
            return "Looks like we had a problem searching your contacts. Let’s give that another try."
        case .viewingContacts:
            return "Your Active Club works best with 3 or\nmore friends. Let's invite them!"
        }
    }

    var buttonText: String {
        switch self {
        case .start, .welcome1, .welcome2, .welcome3, .welcome4:
            return ""
        case .connectHealth:
            return "Connect Apple Health"
        case .signIn:
            return ""
        case .enterPhone:
            return "Send Verification"
        case .enterPhoneVerification:
            return "Next"
        case .pickUsername:
            return "Next"
        case .findFriendsAllowPermission, .searchingForFriends:
            return "Next"
        case .searchingError:
            return "Try Again"
        case .viewingContacts:
            return ""
        }
    }

    var bottomButtonText: String {
        switch self {
        case .enterPhone, .connectHealth, .signIn:
            return "Our Privacy Commitment →"
        case .findFriendsAllowPermission:
            return "Skip and find friends manually"
        case .searchingForFriends:
            return ""
        case .searchingError:
            return "Contact support"
        case .viewingContacts:
            return ""
        default:
            return ""
        }
    }
}
