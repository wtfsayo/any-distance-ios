// Licensed under the Any Distance Source-Available License
//
//  OnboardingFriendFinderView.swift
//  ADAC
//
//  Created by Daniel Kuntz on 2/28/23.
//

import SwiftUI
import Contacts

/// Slide that asks for contacts permission or allows the user to skip allowing contacts
struct FriendFinderPreResultsView: View {
    @ObservedObject var model: OnboardingViewModel
    @ObservedObject var friendFinderModel: FriendFinderViewModel

    let screenName = "AC Onboarding - Contacts Permission"

    var body: some View {
        VStack(spacing: 16) {
            OnboardingTitleAndSubtitle(model: model)

            ZStack {
                if model.state == .searchingForFriends {
                    ProgressView()
                        .scaleEffect(x: 1.5, y: 1.5)
                } else {
                    Button {
                        Analytics.logEvent("Allow contacts permission", screenName, .buttonTap)
                        friendFinderModel.requestPermissionsAndLoad()
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .foregroundColor(.white)
                            Text(model.state.buttonText)
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(.black)
                        }
                    }
                }
            }
            .frame(height: 50)
            .id(model.state.rawValue)
            .modifier(BlurOpacityTransition())

            Button {
                Analytics.logEvent("Find friends manually", screenName, .buttonTap)
                friendFinderModel.loadForFindingFriendsManually()
            } label: {
                ZStack {
                    Rectangle()
                        .fill(Color.black.opacity(0.001))
                    Text(model.state.bottomButtonText)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .opacity(0.6)
                }
            }
            .frame(height: 40)
            .id(model.state.rawValue)
            .modifier(BlurOpacityTransition())
        }
        .padding([.leading, .trailing], 30)
        .onAppear {
            Analytics.logEvent(screenName, screenName, .otherEvent)
        }
    }
}

/// OnboardingFriendFinderView subview that instructs the user to invite 3 contacts before being
/// able to continue
fileprivate struct Invite3FriendsView: View {
    @ObservedObject var model: OnboardingViewModel
    @ObservedObject var friendFinderModel: FriendFinderViewModel
    @Binding var friendsInvitedOrAdded: Int
    @ObservedObject var currentUser: ADUser = ADUser.current
    @StateObject var friendFinderAPI: FriendFinderAPI = FriendFinderAPI.shared
    @State var scrollViewOffset: CGFloat = 0.0
    let skipButtonSplit = NSUbiquitousKeyValueStore.default.split(for: Invite3FriendsSkipButtonVisibility.self)

    var modelHasLoaded: Bool {
        return !friendFinderAPI.contactsOnAnyDistance.isEmpty ||
        !friendFinderAPI.friendsOfContacts.isEmpty ||
        !friendFinderAPI.contactsNotOnAnyDistance.isEmpty
    }

    func updateFriendsInvitedOrAdded() {
        friendsInvitedOrAdded = NSUbiquitousKeyValueStore.default.invitedPhoneNumbers.count + ADUser.current.sentRequests.count + ADUser.current.friendIDs.count
    }

    var progressBar: some View {
        ZStack {
            DarkBlurView()
                .brightness(0.15)
                .cornerRadius(13.0, style: .continuous)

            ZStack {
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 20.0, style: .continuous)
                        .fill(LinearGradient(colors: [
                            Color(hexadecimal: "027307"),
                            Color(hexadecimal: "36C603"),
                            Color(hexadecimal: "B7FB69")
                        ], startPoint: UnitPoint(x: -0.2, y: 0.5), endPoint: UnitPoint(x: 1.2, y: 0.5)))
                        .frame(width: (190.0 * (CGFloat(friendsInvitedOrAdded) / 3.0).clamped(to: 0...1)).clamped(to: 22.0...190.0))
                        .animation(.easeInOut(duration: 0.4), value: friendsInvitedOrAdded)
                        .shadow(color: Color(hexadecimal: "30D158"), radius: 4.0)
                        .frame(height: 22.0)
                    Spacer()
                        .minWidth(0.0)
                }

                HStack {
                    Spacer()

                    if friendsInvitedOrAdded < 3 {
                        Text("\(friendsInvitedOrAdded)/3")
                            .font(.system(size: 14.0, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.trailing, 8.0)
                            .modifier(BlurOpacityTransition(speed: 2.0))
                    } else {
                        Image(systemName: .checkmarkCircleFill)
                            .resizable()
                            .frame(width: 16.0, height: 16.0)
                            .foregroundColor(.black)
                            .opacity(0.4)
                            .padding(.trailing, 4.0)
                            .modifier(BlurOpacityTransition(speed: 2.0))
                    }
                }
            }
            .padding([.leading, .trailing], 2.0)
        }
        .frame(width: 190.0, height: 26.0)
    }

    var body: some View {
        ZStack {
            let contactsNotOnAnyDistance = friendFinderAPI.contactsNotOnAnyDistance.enumerated().map { $0 }
            let friendsOfContacts = friendFinderAPI.friendsOfContacts.enumerated().map { $0 }
            let contactsOnAnyDistance = friendFinderAPI.contactsOnAnyDistance.enumerated().map { $0 }

            ReadableScrollView(offset: $scrollViewOffset) {
                VStack(spacing: 0.0) {
                    VStack(alignment: .center) {
                        ClubTitleAndProfilePhoto(model: model, curveTextProfilePadding: -240.0)
                            .padding(.top, 20.0)
                            .offset(y: -0.8 * scrollViewOffset)
                            .opacity(1.0 - ((-1 * scrollViewOffset) / 400.0))
                            .blur(radius: ((-5.0 * scrollViewOffset) / 400.0))
                        OnboardingTitleAndSubtitle(model: model)
                            .padding(.bottom, 30.0)
                            .offset(y: -0.7 * scrollViewOffset)
                            .opacity(1.0 - ((-1 * scrollViewOffset) / 400.0))
                            .blur(radius: ((-5.0 * scrollViewOffset) / 400.0))
                        progressBar
                            .padding(.bottom, 30.0)
                            .offset(y: (scrollViewOffset <= -500.0) ? ((-1 * scrollViewOffset) - 500.0) : 0.0)
                            .shadow(color: .black.opacity(0.5), radius: 18.0)
                    }
                    .zIndex(1000)

                    LazyVStack(spacing: 0.0) {
                        if !contactsOnAnyDistance.isEmpty {
                            ForEach(contactsOnAnyDistance,
                                    id: \.element.id) { idx, friend in
                                SuggestedTableViewCell(model: friendFinderModel,
                                                       friend: friend,
                                                       idx: idx,
                                                       arrayCount: contactsOnAnyDistance.count + friendsOfContacts.count)
                                .padding([.leading, .trailing], 15.0)
                                .drawingGroup()
                            }
                        }

                        if !friendsOfContacts.isEmpty {
                            ForEach(friendsOfContacts,
                                    id: \.element.id) { idx, friend in
                                SuggestedTableViewCell(model: friendFinderModel,
                                                       friend: friend,
                                                       idx: contactsOnAnyDistance.count + idx,
                                                       arrayCount: contactsOnAnyDistance.count + friendsOfContacts.count)
                                .padding([.leading, .trailing], 15.0)
                                .drawingGroup()
                            }
                        }

                        Spacer()
                            .frame(height: 16.0)

                        ForEach(contactsNotOnAnyDistance,
                                id: \.element.id) { idx, friend in
                            SuggestedTableViewCell(model: friendFinderModel,
                                                   friend: friend,
                                                   idx: idx,
                                                   arrayCount: contactsNotOnAnyDistance.count)
                            .padding([.leading, .trailing], 15.0)
                            .drawingGroup()
                        }

                        Spacer()
                            .frame(height: 60)
                    }
                }
            }
            .opacity(modelHasLoaded ? 1 : 0)
            .animation(.easeInOut(duration: 0.3), value: modelHasLoaded)
            .mask {
                VStack(spacing: 0.0) {
                    LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                        .frame(height: 30.0)
                    Color.black
                }
                .ignoresSafeArea()
            }

            if friendsInvitedOrAdded < 3 && skipButtonSplit == .visible {
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            UIApplication.shared.transitionToTabBar()
                        } label: {
                            Text("Skip")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .padding()
                                .contentShape(Rectangle())
                        }
                        .offset(y: -20.0)
                    }
                    Spacer()
                }
            }
        }
        .onAppear {
            updateFriendsInvitedOrAdded()
            skipButtonSplit.sendAnalytics()
        }
        .onReceive(ReloadPublishers.friendInvited) { _ in
            updateFriendsInvitedOrAdded()
        }
        .onChange(of: currentUser.friendships) { _ in
            updateFriendsInvitedOrAdded()
        }
    }
}

/// Onboarding slide that shows a list of contacts and users who are on AD if the user granted contacts permission,
/// or a user search bar if contacts permission was not granted
struct OnboardingFriendFinderView: View {
    @ObservedObject var model: OnboardingViewModel
    @ObservedObject var friendFinderModel: FriendFinderViewModel
    @State var hasAppeared: Bool = false
    @State var friendsInvitedOrAdded: Int = 0
    @State var split: OnboardingInvite3Friends?

    var body: some View {
        ZStack {
            if hasAppeared {
                ZStack {
                    if split == .dontRequireInvites || split == nil {
                        SuggestedView(friendFinderModel: friendFinderModel)
                            .ignoresSafeArea()
                    } else {
                        Invite3FriendsView(model: model,
                                           friendFinderModel: friendFinderModel,
                                           friendsInvitedOrAdded: $friendsInvitedOrAdded)
                    }

                    if split == .dontRequireInvites || split == nil || friendsInvitedOrAdded >= 3 {
                        LinearGradient(colors: [.clear, .black],
                                       startPoint: UnitPoint(x: 0.5, y: 0.75), endPoint: UnitPoint(x: 0.5, y: 0.92))
                        .allowsHitTesting(false)
                        .ignoresSafeArea()
                        .transition(.opacity.animation(.easeInOut(duration: 0.4).delay(0.6)))

                        VStack {
                            Spacer()
                            ADWhiteButton(title: "Next") {
                                UIApplication.shared.transitionToTabBar()
                            }
                        }
                        .padding([.leading, .trailing], 20)
                        .padding(.bottom, 20)
                        .transition(.opacity.animation(.easeInOut(duration: 0.4).delay(0.6)))
                    }
                }
                .modifier(BlurOpacityTransition(speed: 1.5))
            }
        }
        .onAppear {
            if CNContactStore.authorizationStatus(for: .contacts) == .authorized {
                split = NSUbiquitousKeyValueStore.default.split(for: OnboardingInvite3Friends.self)
                split?.sendAnalytics()
            }
            hasAppeared = true
        }
    }
}
