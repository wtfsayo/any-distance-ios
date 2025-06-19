// Licensed under the Any Distance Source-Available License
//
//  OnboardingView.swift
//  ADAC
//
//  Created by Daniel Kuntz on 11/8/22.
//

import SwiftUI
import AuthenticationServices

/// Horizontal stack of privacy policy / terms & conditions buttons
struct PrivacyAndTerms: View {
    var topText: String?

    var body: some View {
        VStack(spacing: 4.0) {
            if let topText = topText {
                Text(topText)
                    .font(.system(size: 14.0))
            }
            HStack(spacing: 4.0) {
                Button {
                    UIApplication.shared.topViewController?
                        .openUrl(withString: Links.privacyPolicy.absoluteString)
                } label: {
                    Text("Privacy Policy")
                        .font(.system(size: 14.0, weight: .semibold))
                        .foregroundColor(.white)
                }

                Text("|")
                    .font(.system(size: 14.0))
                    .opacity(0.3)

                Button {
                    UIApplication.shared.topViewController?
                        .openUrl(withString: Links.termsAndConditions.absoluteString)
                } label: {
                    Text("Terms & Conditions")
                        .font(.system(size: 14.0, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
        }
    }
}

/// View that displays the curved "YOUR ACTIVE CLUB" text and profile image view for the current
/// onboarding slide
struct ClubTitleAndProfilePhoto: View {
    enum State {
        case smile
        case frown
        case profilePhoto
    }

    func activeClubName() -> String {
        if let firstName = ADUser.current.name
                                    .components(separatedBy: .whitespaces)
                                    .first?
                                    .uppercased(),
           !firstName.isEmpty {
            return "\(firstName)'S ACTIVE CLUB"
        } else {
            return "YOUR ACTIVE CLUB"
        }
    }

    @ObservedObject var model: OnboardingViewModel
    var curveTextProfilePadding: CGFloat = -190.0

    var body: some View {
        VStack {
            CurvedTextAnimationView(text: activeClubName(), radius: 100)
                .frame(height: 300)
                .padding(.bottom, curveTextProfilePadding)
                .id(activeClubName())
                .modifier(BlurOpacityTransition(speed: 2.0))

            ZStack {
                RoundedRectangle(cornerRadius: 78)
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 156, height: 245)
                    .overlay {
                        Image(model.state != .searchingError ? "profile_smile" : "profile_frown")
                    }

                if let profilePhoto = model.userProfileImage {
                    Image(uiImage: profilePhoto)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 156, height: 245)
                        .cornerRadius(78, style: .continuous)
                        .id(0)
                        .modifier(BlurOpacityTransition())
                }

                Image("boys")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: UIScreen.main.bounds.width - 50)
                    .offset(y: 50.0)
            }
        }
        .frame(width: UIScreen.main.bounds.width)
    }
}

/// View that displays the title and subtitle for the current onboarding slide
struct OnboardingTitleAndSubtitle: View {
    @ObservedObject var model: OnboardingViewModel

    var body: some View {
        VStack(spacing: 16) {
            Text(model.state.titleText)
                .font(.system(size: 38, weight: .semibold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(0.0)
                .id(model.state.titleText)
                .modifier(BlurOpacityTransition(speed: 1.5, delay: 0.1))
                .fixedSize(horizontal: false, vertical: true)

            Text(model.state.subtitleText(for: model.phoneNumberString()))
                .font(.system(size: 17, weight: .regular))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .id(model.state.subtitleText(for: model.phoneNumberString()))
                .modifier(BlurOpacityTransition(speed: 1.5, delay: 0.2))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

enum OnboardingFocusedField {
    case phoneNumber
    case phoneVerification
    case username
}

/// Main container view for onboarding sequence
struct OnboardingView: View {
    @ObservedObject var model: OnboardingViewModel
    @StateObject private var friendFinderModel = FriendFinderViewModel()
    @FocusState var focusedField: OnboardingFocusedField?

    let screenName = "AC Onboarding"

    func idForClubTitleAndProfilePhoto() -> Int {
        switch model.state {
        case .start, .welcome1, .welcome2, .welcome3, .welcome4, .connectHealth:
            return 0
        case .signIn, .enterPhone, .enterPhoneVerification, .pickUsername, .findFriendsAllowPermission, .searchingForFriends, .searchingError:
            return 2
        case .viewingContacts:
            return 3
        }
    }

    func idForBottomSection() -> Int {
        switch model.state {
        case .start, .welcome1, .welcome2, .welcome3, .welcome4:
            return 0
        default:
            return model.state.rawValue
        }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Button {
                focusedField = nil
            } label: {
                Color.black.opacity(0.01)
            }

            ZStack {
                switch model.state {
                case .start, .welcome1, .welcome2, .welcome3, .welcome4:
                    Color.black.opacity(0.01)
                    OnboardingHeroVideo(model: model)
                default:
                    EmptyView()
                }
            }
            .id(idForClubTitleAndProfilePhoto())
            .modifier(BlurOpacityTransition(speed: 1.3))
            .maxWidth(.infinity)

            GradientAnimationView(pageIdx: model.pageIdx)
                .ignoresSafeArea()
                .mask {
                    LinearGradient(colors: [.black, .clear],
                                   startPoint: .top,
                                   endPoint: UnitPoint(x: 0.5, y: 0.5))
                }
                .blendMode(.lighten)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack {
                ZStack {
                    switch model.state {
                    case .start, .welcome1, .welcome2, .welcome3, .welcome4, .connectHealth:
                        EmptyView()
                    case .signIn, .enterPhone, .enterPhoneVerification, .pickUsername, .findFriendsAllowPermission, .searchingForFriends, .searchingError:
                        VStack {
                            Spacer()
                            ClubTitleAndProfilePhoto(model: model)
                            Spacer()
                        }
                        .animation(.linear(duration: 0.3), value: model.state)
                    case .viewingContacts:
                        EmptyView()
                    }
                }
                .id(idForClubTitleAndProfilePhoto())
                .modifier(BlurOpacityTransition(speed: 1.3))
                .maxWidth(.infinity)
                .drawingGroup()

                Spacer()

                ZStack {
                    switch model.state {
                    case .start, .welcome1, .welcome2, .welcome3, .welcome4:
                        OnboardingWelcomeView(model: model)
                    case .connectHealth:
                        ConnectHealth(model: model)
                    case .signIn:
                        SignIn(model: model)
                    case .enterPhone:
                        EnterPhone(model: model, focusedField: _focusedField)
                    case .enterPhoneVerification:
                        VerifyPhone(model: model, focusedField: _focusedField)
                    case .pickUsername:
                        PickUsername(model: model, focusedField: _focusedField)
                    case .findFriendsAllowPermission, .searchingForFriends, .searchingError:
                        FriendFinderPreResultsView(model: model, friendFinderModel: friendFinderModel)
                    case .viewingContacts:
                        OnboardingFriendFinderView(model: model, friendFinderModel: friendFinderModel)
                    }
                }
                .id(idForBottomSection())
                .modifier(BlurOpacityTransition(speed: 1.5))
            }
            .if(model.state != .viewingContacts) { view in
                view
                    .frame(height: UIScreen.main.heightMinusSafeArea())
                    .offset(y: (focusedField != nil) ? -150 : 0)
                    .animation(.easeInOut(duration: 0.3), value: focusedField)
            }

            VStack {
                HStack {
                    switch model.state {
                    case .start, .welcome1, .welcome2, .welcome3, .welcome4, .connectHealth:
                        Button {
                            model.signInTopLeftButton()
                            Analytics.logEvent("Sign in top left", screenName, .buttonTap)
                        } label: {
                            Text("Sign In")
                                .font(.system(size: 16, weight: .medium))
                                .padding()
                                .contentShape(Rectangle())
                        }
                        .modifier(BlurOpacityTransition(speed: 2.0))
                    default:
                        EmptyView()
                    }

                    Spacer()
                }
                .foregroundColor(.white)
                Spacer()
            }
            .padding([.leading, .trailing], 10)
        }
        .onAppear {
            friendFinderModel.onboardingModel = model
            Analytics.logEvent(screenName, screenName, .screenViewed)
        }
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(model: OnboardingViewModel())
    }
}

