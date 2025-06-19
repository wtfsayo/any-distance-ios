// Licensed under the Any Distance Source-Available License
//
//  PickUsername.swift
//  ADAC
//
//  Created by Daniel Kuntz on 2/28/23.
//

import SwiftUI

/// Onboarding slide that shows a custom field to pick an Active Clubs username. Validates the username
/// is available before allowing the user to continue.
struct PickUsername: View {
    enum PickUsernameState: Int {
        case enteringUsername
        case loading
        case usernameAvailable
        case usernameTaken

        var color: Color {
            switch self {
            case .enteringUsername, .loading:
                return .white
            case .usernameAvailable:
                return .green
            case .usernameTaken:
                return .adRed
            }
        }
    }

    @ObservedObject var model: OnboardingViewModel
    @FocusState var focusedField: OnboardingFocusedField?
    @State var state: PickUsernameState = .enteringUsername
    @State var checkTimer: Timer?

    let screenName = "AC Onboarding - Pick Username"

    private func checkUsername() {
        guard !model.username.isEmpty else {
            return
        }

        let usernameBeforeRequest = model.username
        Task {
            do {
                let available = try await model.checkUsername()
                DispatchQueue.main.async {
                    if model.username == usernameBeforeRequest {
                        state = available ? .usernameAvailable : .usernameTaken
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    if model.username == usernameBeforeRequest {
                        state = .usernameTaken
                        UIApplication.shared.topViewController?.showFailureToast(with: error)
                    }
                }
            }
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            OnboardingTitleAndSubtitle(model: model)

            ZStack {
                Rectangle()
                    .fill(state != .usernameTaken ? state.color.opacity(0.2) : .white.opacity(0.2))
                    .cornerRadius(10, style: .continuous)
                    .animation(.easeInOut(duration: 0.1), value: state)
                HStack(spacing: 2) {
                    Text("@")
                        .font(.system(size: 23, design: .monospaced))
                        .foregroundColor(state.color)

                    TextField("username", text: $model.username)
                    .focused($focusedField, equals: .username)
                    .textContentType(.username)
                    .keyboardType(.default)
                    .submitLabel(.next)
                    .textInputAutocapitalization(.never)
                    .font(.system(size: 23, design: .monospaced))
                    .tint(Color.adOrangeLighter)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(state.color)
                }
                .padding(.leading, 20)

                HStack {
                    Spacer()
                    ZStack {
                        switch state {
                        case .enteringUsername:
                            EmptyView()
                        case .loading:
                            ProgressView()
                                .frame(width: 24, height: 24)
                        case .usernameAvailable:
                            Circle()
                                .fill(Color.green)
                                .frame(width: 24, height: 24)
                            Image(systemName: .checkmark)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Color.black)
                        case .usernameTaken:
                            Circle()
                                .fill(Color.adRed)
                                .frame(width: 24, height: 24)
                            Image(systemName: .xmark)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Color.black)
                        }
                    }
                    .id(state.rawValue)
                    .modifier(BlurOpacityTransition(speed: 2.0))
                    .padding(.trailing, 20)
                }
            }
            .frame(height: 50)

            ADWhiteButton(title: model.state.buttonText) {
                model.setUsername()
                model.state = .findFriendsAllowPermission
                Analytics.logEvent("Username set", screenName, .otherEvent)
            }
            .opacity(state == .usernameAvailable ? 1.0 : 0.5)
            .allowsHitTesting(state == .usernameAvailable)
            .animation(.easeInOut(duration: 0.25), value: state)
        }
        .padding([.leading, .trailing], 30)
        .padding(.bottom, 20)
        .onChange(of: model.username) { newValue in
            if newValue.isEmpty {
                state = .enteringUsername
            } else {
                state = .loading
                checkUsername()
            }
        }
        .onAppear {
            focusedField = .username
            Analytics.logEvent(screenName, screenName, .screenViewed)
            checkUsername()
        }
    }
}
