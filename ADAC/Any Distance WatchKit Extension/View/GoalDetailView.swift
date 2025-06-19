// Licensed under the Any Distance Source-Available License
//
//  GoalDetailView.swift
//  Any Distance WatchKit Extension
//
//  Created by Daniel Kuntz on 8/16/22.
//

import SwiftUI

struct GoalDetailView: View {
    let activityType: ActivityType
    let unit: DistanceUnit
    @ObservedObject var goal: RecordingGoal
    @State private var crownValue: Double = 0.0
    @State private var originalGoalTarget: Float = 0.0
    @State private var showingRecordingView: Bool = false
    @State private var hasShownRecordingView: Bool = false
    @State private var recordingViewModel: WatchRecordingViewModel?
    @FocusState private var recordingViewFocused: Bool

    var body: some View {
        ZStack {
            ZStack {
                ZStack {
                    ZStack {
                        Image("dot_bg")
                            .resizable(resizingMode: .tile)
                            .scaleEffect(0.6)
                            .opacity(0.1)
                    }
                    .padding(-1000)

                    VStack {
                        Rectangle()
                            .foregroundColor(Color(uiColor: goal.type.color.lighter(by: 10) ?? .white))
                            .frame(height: 2)
                            .mask {
                                LinearGradient(colors: [.clear, .black, .clear], startPoint: .leading, endPoint: .trailing)
                            }
                            .background(Color.black)
                            .overlay {
                                Ellipse()
                                    .fill(Color(goal.type.color))
                                    .frame(width: 160, height: 120)
                                    .blur(radius: 50)
                                    .opacity(0.6)
                            }
                        Spacer()
                    }
                }
                .mask {
                    Rectangle()
                        .cornerRadius(20, corners: [.topLeft, .topRight])
                        .ignoresSafeArea(.all, edges: [.bottom])
                }

                VStack {
                    HStack {
                        Image(uiImage: goal.type.glyph?.withRenderingMode(.alwaysTemplate) ?? UIImage())
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 16, height: 16)
                            .foregroundColor(Color(uiColor: goal.type.color.lighter(by: 10) ?? .white))
                        Spacer()
                    }
                    .padding(.leading, 12)
                    .padding(.top, 12)

                    Text(goal.formattedTarget)
                        .font(.custom("Digital-7", size: 55))
                        .minimumScaleFactor(0.8)
                        .scaleEffect(x: 1.1, y: 1.1)
                        .foregroundColor(Color(uiColor: goal.type.color.lighter(by: 10) ?? .white))
                        .shadow(color: Color(uiColor: goal.type.color), radius: 8, x: 0, y: 0)
                        .shadow(color: .black.opacity(0.6), radius: 3, x: 0, y: 0)
                        .frame(maxWidth: .infinity)
                        .overlay {
                            HStack(spacing: 0) {
                                Button {
                                    goal.setTarget(goal.target - goal.type.buttonIncrement)
                                    originalGoalTarget = goal.target
                                    WKInterfaceDevice.current().play(.click)
                                } label: {
                                    ZStack {
                                        Color.black.opacity(0.01)
                                        Image("glyph_digital_minus")
                                            .foregroundColor(Color(white: 0.9))
                                            .frame(width: 70, height: 90)
                                            .offset(x: -25, y: 0)
                                    }
                                }
                                .buttonStyle(TransparentButtonStyle())

                                Spacer()

                                Button {
                                    goal.setTarget(goal.target + goal.type.buttonIncrement)
                                    originalGoalTarget = goal.target
                                    WKInterfaceDevice.current().play(.click)
                                } label: {
                                    ZStack {
                                        Color.black.opacity(0.01)
                                        Image("glyph_digital_plus")
                                            .foregroundColor(Color(white: 0.9))
                                            .contentShape(Rectangle())
                                            .frame(width: 70, height: 90)
                                            .offset(x: 25, y: 0)
                                    }
                                }
                                .buttonStyle(TransparentButtonStyle())
                            }
                        }
                        .offset(x: 0, y: -8)

                    Text(goal.formattedShortUnitString)
                        .foregroundColor(Color(uiColor: goal.type.color.lighter(by: 10) ?? .white))
                        .font(.system(size: 13, weight: .medium, design: .default))
                        .offset(x: 0, y: -8)

                    Spacer()

                    Button {
                        withAnimation {
                            showingRecordingView = true
                            recordingViewFocused = true
                        }
                    } label: {
                        Text("Start")
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .frame(maxHeight: .infinity)
                    }
                    .buttonStyle(ADWatchButtonStyle(foregroundColor: .black, backgroundColor: .adOrangeLighter))
                    .frame(height: 45)
                    .padding([.leading, .trailing], 12)
                }
            }
            .focusable()
            .digitalCrownRotation($crownValue,
                                  from: -1 * Double.greatestFiniteMagnitude,
                                  through: Double.greatestFiniteMagnitude,
                                  isContinuous: true,
                                  isHapticFeedbackEnabled: true)
            .onAppear {
                originalGoalTarget = goal.target
            }
            .onChange(of: crownValue) { newValue in
                if !showingRecordingView {
                    goal.setTarget(originalGoalTarget + Float(newValue) * goal.type.crownIncrement)
                }
            }
            .opacity(showingRecordingView ? 0 : 1)
            .scaleEffect(showingRecordingView ? 0.95 : 1)

            if showingRecordingView {
                if let model = recordingViewModel {
                    WatchRecordingView(model: model)
                        .navigationBarHidden(true)
                        .transition(AnyTransition.opacity.combined(with: .scale(scale: 0.95)))
                        .focusable()
                        .focused($recordingViewFocused)
                } else {
                    let recorder = WatchActivityRecorder(activityType: activityType,
                                                         goal: goal,
                                                         unit: unit)
                    let model = WatchRecordingViewModel(recorder: recorder)
                    WatchRecordingView(model: model)
                        .navigationBarHidden(true)
                        .transition(AnyTransition.opacity.combined(with: .scale(scale: 0.95)))
                        .focusable()
                        .focused($recordingViewFocused)
                        .onAppear {
                            recordingViewModel = model
                        }
                }
            }
        }
    }
}

struct GoalDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            GoalDetailView(activityType: .bikeRide,
                           unit: .miles,
                           goal: RecordingGoal(type: .calories, unit: .miles, target: 1000))
        }
    }
}
