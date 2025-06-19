// Licensed under the Any Distance Source-Available License
//
//  GoalSelectView.swift
//  Any Distance WatchKit Extension
//
//  Created by Daniel Kuntz on 8/16/22.
//

import SwiftUI

fileprivate struct GoalSettings: View {
    var activityType: ActivityType
    @State var autoPauseOn: Bool = NSUbiquitousKeyValueStore.default.autoPauseOn
    @State var clipRoute: Bool = iPhonePreferences.shared.shouldClipRoute
    @State var distanceUnit: DistanceUnit = iPhonePreferences.shared.distanceUnit

    var body: some View {
        VStack {
            TitleLabel(title: "Settings")
            ScrollView {
                VStack(alignment: .leading) {
                    VStack() {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .foregroundColor(.init(white: 0.15))

                            HStack(spacing: 0) {
                                Button {
                                    distanceUnit = .miles
                                } label: {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                                            .foregroundColor(distanceUnit == .miles ? .init(white: 0.3) : .black.opacity(0.01))
                                        Text("Mi")
                                    }
                                }
                                .buttonStyle(TransparentButtonStyle())
                                .padding(2)

                                Button {
                                    distanceUnit = .kilometers
                                } label: {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                                            .foregroundColor(distanceUnit == .kilometers ? .init(white: 0.3) : .black.opacity(0.01))
                                        Text("Km")
                                    }
                                }
                                .buttonStyle(TransparentButtonStyle())
                                .padding(2)
                            }
                            .frame(height: 36)
                        }
                        .padding(.bottom, 6)
                    }

                    if activityType.supportsAutoPause {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .foregroundColor(.init(white: 0.15))
                            HStack {
                                Text("Auto-Pause")
                                Spacer()
                                Toggle("", isOn: $autoPauseOn)
                                    .frame(width: 25)
                                    .offset(x: -12)
                            }
                            .padding(10)
                        }
                        HStack {
                            Text("Automatically pause and resume your activity when you stop and start moving.")
                                .font(.system(size: 13))
                                .padding(4)
                            Spacer()
                        }
                    }

                    if activityType.supportsRouteClip {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .foregroundColor(.init(white: 0.15))
                            HStack {
                                Text("Clip Route")
                                Spacer()
                                Toggle("", isOn: $clipRoute)
                                    .frame(width: 25)
                                    .offset(x: -12)
                            }
                            .padding(10)
                        }
                        
                        Text(iPhonePreferences.shared.routeClipDescriptionString)
                            .font(.system(size: 13))
                            .padding(4)
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.leading)
                    }
                }
            }
        }
        .onChange(of: autoPauseOn) { newValue in
            NSUbiquitousKeyValueStore.default.autoPauseOn = newValue
        }
        .onChange(of: clipRoute) { newValue in
            iPhonePreferences.shared.setClipRoute(newValue)
        }
        .onChange(of: distanceUnit) { newValue in
            iPhonePreferences.shared.setDistanceUnit(newValue)
        }
    }
}

fileprivate struct GoalTypeCell: View {
    var activityType: ActivityType
    var unit: DistanceUnit
    var goal: RecordingGoal
    @Binding var showingRecordingView: Bool
    @FocusState var recordingViewFocused: Bool

    var buttonLabel: some View {
        HStack {
            Text(goal.type.displayName)
                .foregroundColor(goal.type == .open ? .black : .white)
            Spacer()
            Image(uiImage: goal.type.glyph ?? UIImage())
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)
        }
        .frame(height: 25)
    }

    var body: some View {
        if goal.type == .open {
            Button {
                withAnimation {
                    showingRecordingView = true
                    recordingViewFocused = true
                }
            } label: {
                buttonLabel
            }
        } else {
            NavigationLink {
                GoalDetailView(activityType: activityType,
                               unit: unit,
                               goal: goal)
            } label: {
                buttonLabel
            }
            .buttonStyle(
                ADWatchButtonStyle(foregroundColor: goal.type == .open ? .black : .white,
                                   backgroundColor: .clear)
            )
        }
    }
}

struct GoalSelectView: View {
    var activityType: ActivityType
    @State var defaultGoalTypes: [RecordingGoal] = []
    @State var showingRecordingView: Bool = false
    @State var showingSettingsView: Bool = false
    @FocusState private var recordingViewFocused: Bool

    var body: some View {
        ZStack {
            VStack {
                HStack {
                    TitleLabel(title: activityType.displayName)
                    NavigationLink {
                        GoalSettings(activityType: activityType)
                    } label: {
                        Text("Settings")
                            .foregroundColor(.white)
                    }
                    .buttonStyle(TransparentButtonStyle())
                }
                .frame(minHeight: 25)

                List {
                    ForEach(defaultGoalTypes, id: \.type.rawValue) { goal in
                        GoalTypeCell(activityType: activityType,
                                     unit: iPhonePreferences.shared.distanceUnit,
                                     goal: goal,
                                     showingRecordingView: $showingRecordingView,
                                     recordingViewFocused: _recordingViewFocused)
                        .frame(height: 60)
                        .listRowBackground(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(uiColor: goal.type.color))
                                .padding(1)
                        )
                    }
                }
                .listStyle(CarouselListStyle())
            }
            .onAppear {
                if activityType.showsRoute {
                    defaultGoalTypes = RecordingGoal.defaultsForAllTypes(withUnit: iPhonePreferences.shared.distanceUnit)
                } else {
                    defaultGoalTypes = RecordingGoal.defaults(for: [.open, .time, .calories], unit: iPhonePreferences.shared.distanceUnit)
                }
            }
            .onChange(of: showingRecordingView) { newValue in
                if newValue == true {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        recordingViewFocused = true
                    }
                }
            }
            .opacity(showingRecordingView ? 0 : 1)
            .scaleEffect(showingRecordingView ? 0.95 : 1)

            if showingRecordingView {
                let recorder = WatchActivityRecorder(activityType: activityType,
                                                     goal: RecordingGoal(type: .open,
                                                                         unit: iPhonePreferences.shared.distanceUnit,
                                                                         target: 0),
                                                     unit: iPhonePreferences.shared.distanceUnit)
                let model = WatchRecordingViewModel(recorder: recorder)
                WatchRecordingView(model: model)
                    .navigationBarHidden(true)
                    .transition(AnyTransition.opacity.combined(with: .scale(scale: 0.95)))
                    .focusable()
                    .focused($recordingViewFocused)
            }
        }
    }
}

struct GoalSelectView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            GoalSelectView(activityType: .bikeRide)
        }
        .previewDevice("Apple Watch Series 6 - 40mm")
    }
}
