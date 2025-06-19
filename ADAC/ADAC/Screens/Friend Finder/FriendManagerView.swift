// Licensed under the Any Distance Source-Available License
//
//  FriendManagerView.swift
//  ADAC
//
//  Created by Daniel Kuntz on 3/12/23.
//

import SwiftUI
import Combine
import Contacts

/// Screen that contains a segmented control at the top and shows Suggestions, Friends, Requests, and Blocked
struct FriendManagerView: View {
    @StateObject var friendFinderModel: FriendFinderViewModel = FriendFinderViewModel()
    @State var selectedSegment: Int = 0
    @Environment(\.dismiss) var dismiss

    let screenName = "Friend Manager"

    var segments: [String] {
        return ["Suggestions", "Friends", "Requests", "Blocked"]
    }

    var body: some View {
        ZStack {
            VStack {
                HStack {
                    Button {
                        dismiss.callAsFunction()
                    } label: {
                        Image(systemName: .xmarkCircleFill)
                            .font(.system(size: 26, weight: .medium))
                            .foregroundColor(.white)
                    }

                    ADSegmentedControl(segments: segments,
                                       fontSize: UIScreen.main.bounds.width * 0.03,
                                       selectedSegmentIdx: $selectedSegment)
                }
                .padding(.top, 20)
                .padding([.leading, .trailing], 15)

                ZStack {
                    switch selectedSegment {
                    case 0:
                        SuggestedView(friendFinderModel: friendFinderModel)
                            .ignoresSafeArea()
                    case 1:
                        FriendsTable()
                            .ignoresSafeArea()
                    case 2:
                        RequestsTable()
                            .ignoresSafeArea()
                    default:
                        BlockedTable()
                            .ignoresSafeArea()
                    }
                }
                .ignoresSafeArea()
                .background(Color.black)
                .id(selectedSegment)
                .modifier(BlurOpacityTransition(speed: 2.0))

                Spacer()
            }

            VStack {
                Spacer()
                    .layoutPriority(1)

                ZStack {
                    DarkBlurView()
                        .cornerRadius([.topLeading, .topTrailing], 14)
                    Button {
                        Analytics.logEvent("Share Invite Link Tapped", screenName, .buttonTap)
                        friendFinderModel.shareActiveClubsInviteLink()
                    } label: {
                        ZStack {
                            HStack(spacing: 6) {
                                Image(systemName: .squareAndArrowUp)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 16, height: 16)
                                    .fontWeight(.semibold)
                                Text("Share Invite Link")
                                    .font(.system(size: 15, weight: .medium))
                            }
                            .foregroundColor(.black)
                            .padding([.leading, .trailing], 14)
                            .padding([.top, .bottom], 10)
                            .background {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .padding()
                    .padding(.bottom, UIScreen.main.safeAreaInsets.bottom * 0.5)
                }
            }
        }
        .ignoresSafeArea()
        .background(Color.black)
        .onAppear {
            Analytics.logEvent(screenName, screenName, .screenViewed)
            if CNContactStore.authorizationStatus(for: .contacts) == .authorized {
                friendFinderModel.requestPermissionsAndLoad()
            } else {
                friendFinderModel.loadForFindingFriendsManually()
            }

            if !ADUser.current.pendingFriendships.isEmpty {
                selectedSegment = 2
            }
        }
        .onChange(of: selectedSegment) { newValue in
            let segmentName = segments[newValue]
            Analytics.logEvent(segmentName + " tapped", screenName, .buttonTap)
        }
    }
}

struct FriendManagerView_Previews: PreviewProvider {
    static var previews: some View {
        FriendManagerView()
            .padding([.top, .bottom])
            .previewDevice(.init(stringLiteral: "iPhone SE (3rd generation)"))
    }
}
