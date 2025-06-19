// Licensed under the Any Distance Source-Available License
//
//  RecordingQuickLaunchView.swift
//  ADAC
//
//  Created by Daniel Kuntz on 7/27/22.
//

import SwiftUI

struct RecordingQuickLaunchView: View {
    @Environment(\.presentationMode) var presentationMode

    var tabBarHeight: CGFloat
    var middleItemTopOffset: CGFloat
    private let activities = ActivityListProvider.recentlyUsedActivities()
    private let screenName = "Tracking Quick Launch"
    
    @State private var selectedActivityType: ActivityType = .unknown
    @State private var showingGoalSelection: Bool = false
    @State private var presentingActivityPicker: Bool = false
    @State private var animateIn: Bool = false
    @State private var showingEarlyAccessInvites: Bool = false
    @State private var showingRedeemCode: Bool = false

    func tapHandler(_ type: ActivityType) {
        selectedActivityType = type
        showingGoalSelection = true
        Analytics.logEvent("Tap Activity Type", screenName, .buttonTap, withParameters: ["activityType" : type.displayName])
    }

    private var bindingForPresentationMode: Binding<PresentationMode?> {
        return Binding<PresentationMode?>.init(get: {
            return presentationMode.wrappedValue
        }, set: { newValue in
            presentationMode.wrappedValue = newValue ?? presentationMode.wrappedValue
        })
    }

    private func springAnimation() -> Animation {
        return .spring(response: 0.4, dampingFraction: 0.85, blendDuration: 0)
    }

    private func dismissAnimation() -> Animation {
        return .easeIn(duration: 0.1)
    }

    private func dismiss() {
        withAnimation(dismissAnimation()) {
            animateIn = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            UIApplication.shared.topmostViewController?.dismiss(animated: false)
            Analytics.logEvent("Dismiss", screenName, .buttonTap)
        }
    }
    
    var body: some View {
        VStack {
            Spacer()
            ActivitiesList(activityTypesByCategory: ["Recently Used": activities],
                           searchText: .constant(""),
                           tapHandler: tapHandler(_:))
            .opacity(animateIn ? 1 : 0)
            .offset(y: animateIn ? -25 : 0)
            .padding(.bottom, -25)

            Button {
                presentingActivityPicker = true
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(UIColor.adOrangeLighter))
                    Text("View All Activities")
                        .foregroundColor(.black)
                        .semibold()
                }
                .frame(height: 56)
                .maxWidth(.infinity)
            }
            .padding([.leading, .trailing], 20)
            .padding(.bottom, 40)
            .opacity(animateIn ? 1 : 0)
            .offset(y: animateIn ? -25 : 0)
            .animation(springAnimation().delay(animateIn ? 0.075 : 0),
                       value: animateIn)

            Spacer()
                .height(tabBarHeight)
                .overlay {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: .plusCircleFill)
                            .resizable()
                            .frame(width: 60.0, height: 60.0)
                            .rotationEffect(.degrees(animateIn ? 45 : 0))
                            .foregroundColor(animateIn ? .white : .init(white: 0.5))
                    }
                    .offset(x: -1,
                            y: animateIn ? middleItemTopOffset - 90 : middleItemTopOffset)
                    .scaleEffect(x: animateIn ? 0.6 : 0.39,
                                 y: animateIn ? 0.6 : 0.39)
                }
                .padding(.top, 20)
        }
        .background {
            Color.black
                .mask {
                    LinearGradient(colors: [.black.opacity(0.5), .black.opacity(0.98)],
                                   startPoint: .top,
                                   endPoint: UnitPoint(x: 0.5, y: 0.5))
                }
                .ignoresSafeArea()
                .opacity(animateIn ? 1 : 0)
                .onTapGesture {
                    dismiss()
                }
        }
        .fullScreenCover(isPresented: $showingGoalSelection) {
            RecordingGoalSelectionView(rootViewPresentationMode: bindingForPresentationMode,
                                       activityType: $selectedActivityType)
            .background(BackgroundClearView())
        }
        .sheet(isPresented: $presentingActivityPicker) {
            RecordingActivityPickerView(presentationMode: _presentationMode)
        }
        .sheet(isPresented: $showingEarlyAccessInvites) {
            RecordingInviteCodesView()
        }
        .onAppear {
            withAnimation(springAnimation()) {
                animateIn = true
            }
        }
    }
}

struct RecordingQuickLaunchView_Previews: PreviewProvider {
    static var previews: some View {
        RecordingQuickLaunchView(tabBarHeight: 83, middleItemTopOffset: -20)
            .previewDevice("iPhone 13 Pro")
    }
}
