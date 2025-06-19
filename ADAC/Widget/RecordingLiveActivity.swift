// Licensed under the Any Distance Source-Available License
//
//  RecordingLiveActivity.swift
//  ADAC
//
//  Created by Daniel Kuntz on 9/15/22.
//

import ActivityKit
import SwiftUI
import WidgetKit

@available(iOS 16.1, *)
struct RecordingActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RecordingLiveActivityAttributes.self) { context in
            // Create the view that appears on the Lock Screen and as a
            // banner on the Home Screen of devices that don't support the
            // Dynamic Island.
            // ...
            LockScreenLiveActivityView(attributes: context.attributes, state: context.state)
        } dynamicIsland: { context in
            // Create the views that appear in the Dynamic Island.
            // ...
            DynamicIsland {
                // expanded
                DynamicIslandExpandedRegion(.center) {
                    VStack {
                        Spacer()

                        var durationLabelString: String = {
                            switch context.state.duration {
                            case 0..<60:
                                return "SECONDS"
                            case 60..<3600:
                                return "MINUTES"
                            default:
                                return "HOURS"
                            }
                        }()

                        if context.attributes.activityType.isDistanceBased {
                            HStack(spacing: 0) {
                                StatText(label: "DISTANCE",
                                         value: context.state.distance,
                                         formatting: .decimal,
                                         unit: context.attributes.unit.abbreviation.uppercased())
                                .offset(x: context.state.distance >= 10 ? -60 : -65)
                                Spacer()
                                StatText(label: "PACE",
                                         value: context.state.pace,
                                         formatting: .timestamp,
                                         unit: "/\(context.attributes.unit.abbreviation.uppercased())")
                                Spacer()
                                StatText(label: durationLabelString,
                                         value: context.state.duration,
                                         formatting: .timestamp)
                                .offset(x: context.state.duration >= 600 ? 60 : 65)
                            }
                        } else {
                            HStack(spacing: 0) {
                                StatText(label: "CAL",
                                         value: context.state.totalCalories,
                                         formatting: .integer)
                                Spacer()
                                StatText(label: durationLabelString,
                                         value: context.state.duration,
                                         formatting: .timestamp)
                            }
                        }
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .center, spacing: 0) {
                        HStack(spacing: 4) {
                            switch context.state.state {
                            case .recording:
                                Circle()
                                    .foregroundColor(.green)
                                    .frame(width: 12, height: 12)
                                    .overlay {
                                        Circle()
                                            .foregroundColor(.black)
                                            .frame(width: 4.5, height: 4.5)

                                    }
                                    .offset(y: -0.5)
                            case .paused:
                                Circle()
                                    .foregroundColor(Color(UIColor.adOrangeLighter))
                                    .frame(width: 12, height: 12)
                                    .overlay {
                                        Image(systemName: "pause.fill")
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .foregroundColor(.black)
                                            .frame(width: 5.25)
                                    }
                                    .offset(y: -0.5)
                            case .waitingForGps:
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .tint(Color.yellow)
                                    .frame(width: 8, height: 8)
                            default:
                                EmptyView()
                            }

                            Text(context.state.state.liveActivityDisplayName)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                                .fixedSize()
                        }
                    }
                    .frame(height: 20)
                    .padding(.trailing, 6)
                }

                DynamicIslandExpandedRegion(.leading) {
                    MovingLabelLeadingView(attributes: context.attributes,
                                           state: context.state)
                    .padding(.leading, 6)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    if context.attributes.goal.type != .open {
                        GoalProgressBar(attributes: context.attributes,
                                        state: context.state)
                        .padding([.leading, .trailing], 10)
                    } else {
                        EmptyView()
                    }
                }
            } compactLeading: {
                Text("")
            } compactTrailing: {
                Text("")
            } minimal: {
                // minimal
                LeadingMinimalView(attributes: context.attributes,
                                   state: context.state)
            }
        }
    }
}

struct LeadingMinimalView: View {
    var attributes: RecordingLiveActivityAttributes
    var state: RecordingLiveActivityAttributes.ActivityState

    var body: some View {
        if attributes.goal.type == .open {
            Image(attributes.activityType.glyphName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 25, height: 25)
        } else {
            ZStack {
                TinyCircularGoalProgressBar(attributes: attributes, state: state)
                    .frame(width: 29, height: 29)

                Image(attributes.activityType.glyphName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16)
            }
            .offset(x: -11)
        }
    }
}

struct MovingLabelLeadingView: View {
    var attributes: RecordingLiveActivityAttributes
    var state: RecordingLiveActivityAttributes.ActivityState

    @State var move: Bool = false

    func offsetIdx(withWordCount wordCount: Int) -> CGFloat {
        let mod = Int(state.uptime) % (wordCount + 2)
        return CGFloat(mod.clamped(to: 0...wordCount-1))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                Image(attributes.activityType.glyphName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16)

                let words = attributes.activityType.displayName.components(separatedBy: .whitespaces)
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(words, id: \.self) { word in
                        Text(word)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .frame(height: 20)
                    }
                }
                .frame(height: 20)
                .offset(y: CGFloat(10 * (words.count - 1)) + (-20 * offsetIdx(withWordCount: words.count)))
                .overlay {
                    ZStack {
                        Color.black
                            .offset(y: -20)
                        LinearGradient(colors: [.black, .clear, .clear, .clear, .clear, .clear, .clear, .black],
                                       startPoint: .top,
                                       endPoint: .bottom)
                        Color.black
                            .offset(y: 20)
                        Color.black
                            .offset(y: 40)
                        Color.black
                            .offset(y: 60)
                    }
                }
            }
            Spacer()
        }
        .zIndex(-1000)
    }
}

@available(iOS 16.1, *)
struct LockScreenLiveActivityView: View {
    var attributes: RecordingLiveActivityAttributes
    var state: RecordingLiveActivityAttributes.ActivityState

    var durationLabelString: String {
        switch state.duration {
        case 0..<60:
            return "SECONDS"
        case 60..<3600:
            return "MINUTES"
        default:
            return "HOURS"
        }
    }

    var body: some View {
        ZStack {
            HStack {
                Spacer()
                let width: CGFloat = attributes.goal.type == .open ? 160 : 204
                Image(attributes.activityType.glyphName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: width, height: width)
                    .foregroundColor(.white)
                    .opacity(0.1)
                    .padding(.trailing, 20)
            }
            .frame(height: 10)

            VStack(spacing: 8) {
                ZStack {
                    HStack {
                        Image("logo_a")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 19, height: 19)
                            .opacity(0.5)
                        Text(attributes.activityType.displayName)
                            .font(.system(size: 21, weight: .semibold, design: .default))
                            .foregroundColor(.white)
                            .lineLimit(2)
                        Spacer()
                            .frame(minWidth: 50)
                    }

                    HStack {
                        Spacer()
                        HStack(spacing: 4) {
                            switch state.state {
                            case .recording:
                                Circle()
                                    .foregroundColor(.green)
                                    .frame(width: 12, height: 12)
                                    .overlay {
                                        Circle()
                                            .foregroundColor(.black)
                                            .frame(width: 4.5, height: 4.5)

                                    }
                                    .offset(y: -0.5)
                            case .paused:
                                Circle()
                                    .foregroundColor(Color(UIColor.adOrangeLighter))
                                    .frame(width: 12, height: 12)
                                    .overlay {
                                        Image(systemName: "pause.fill")
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .foregroundColor(.black)
                                            .frame(width: 5.25)
                                    }
                                    .offset(y: -0.5)
                            case .waitingForGps:
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .tint(Color.yellow)
                                    .frame(width: 8, height: 8)
                            default:
                                EmptyView()
                            }

                            Text(state.state.liveActivityDisplayName)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                                .fixedSize()
                        }
                    }
                }

                if attributes.activityType.isDistanceBased {
                    HStack(spacing: 0) {
                        StatText(label: "DISTANCE",
                                 value: state.distance,
                                 formatting: .decimal,
                                 unit: attributes.unit.abbreviation.uppercased())
                        Spacer()
                        StatText(label: "PACE",
                                 value: state.pace,
                                 formatting: .timestamp,
                                 unit: "/\(attributes.unit.abbreviation.uppercased())")
                        Spacer()
                        StatText(label: durationLabelString,
                                 value: state.duration,
                                 formatting: .timestamp)
                    }
                } else {
                    HStack(spacing: 0) {
                        StatText(label: "CAL",
                                 value: state.totalCalories,
                                 formatting: .integer)
                        Spacer()

                        StatText(label: durationLabelString,
                                 value: state.duration,
                                 formatting: .timestamp)
                    }
                }

                if attributes.goal.type != .open {
                    GoalProgressBar(attributes: attributes,
                                    state: state)
                }
            }
            .activityBackgroundTint(.black.opacity(0.5))
            .padding()
        }
    }
}

fileprivate struct StatText: View {
    enum StatValueFormatting {
        case decimal
        case decimalOnePlace
        case timestamp
        case integer
    }

    var label: String
    var value: Double
    var formatting: StatValueFormatting
    var unit: String = ""
    var isBold: Bool = false
    var bigFontSize: CGFloat = 24
    var boldColor: UIColor = .adYellow

    private var valueString: String {
        switch formatting {
        case .decimal:
            return "\(value.rounded(toPlaces: 2))".zeroPadded(to: 4, front: false)
        case .decimalOnePlace:
            return "\(value.rounded(toPlaces: 1))".zeroPadded(to: 3, front: false)
        case .timestamp:
            return TimeInterval(value).timeFormatted()
        case .integer:
            return "\(Int(value.rounded()))".zeroPadded(to: 3, front: true)
        }
    }

    var body: some View {
        HStack {
            VStack(alignment: .center) {
                Text(valueString)
                    .font(.system(size: bigFontSize,
                                  weight: isBold ? .semibold : .regular,
                                  design: .monospaced))
                    .fixedSize()
                    .overlay {
                        GeometryReader { geo in
                            Text(unit)
                                .font(.system(size: 9,
                                              weight: isBold ? .black : .bold,
                                              design: .monospaced))
                                .offset(x: 6 + geo.size.width, y: 4.5)
                        }
                    }

                Text(label)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
            }
            .foregroundColor(isBold ? Color(boldColor) : .white)
        }
    }
}

fileprivate struct CircularGoalProgressBar: View {
    var attributes: RecordingLiveActivityAttributes
    var state: RecordingLiveActivityAttributes.ActivityState

    var body: some View {
        Circle()
            .stroke(Color.white.opacity(0.1), lineWidth: 4)
            .overlay(
                Circle()
                    .trim(from: 0, to: CGFloat(state.goalProgress))
                    .stroke(Color(uiColor: attributes.goal.type.color), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(Angle.degrees(90))
                    .scaleEffect(x: -1, y: -1, anchor: .center)
                    .opacity(0.85)
            )
            .overlay(
                Circle()
                    .trim(from: CGFloat(state.goalProgress-0.001), to: CGFloat(state.goalProgress))
                    .stroke(Color(uiColor: attributes.goal.type.color), style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(Angle.degrees(90))
                    .scaleEffect(x: -1, y: -1, anchor: .center)
            )
    }
}

fileprivate struct TinyCircularGoalProgressBar: View {
    var attributes: RecordingLiveActivityAttributes
    var state: RecordingLiveActivityAttributes.ActivityState

    var body: some View {
        Circle()
            .stroke(Color.white.opacity(0.15), lineWidth: 3)
            .overlay(
                Circle()
                    .trim(from: 0, to: CGFloat(state.goalProgress))
                    .stroke(Color(uiColor: attributes.goal.type.color), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(Angle.degrees(90))
                    .scaleEffect(x: -1, y: -1, anchor: .center)
                    .opacity(0.85)
            )
            .overlay(
                Circle()
                    .trim(from: CGFloat(state.goalProgress-0.001), to: CGFloat(state.goalProgress))
                    .stroke(Color(uiColor: attributes.goal.type.color), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(Angle.degrees(90))
                    .scaleEffect(x: -1, y: -1, anchor: .center)
            )
    }
}

fileprivate struct GoalProgressBar: View {
    var attributes: RecordingLiveActivityAttributes
    var state: RecordingLiveActivityAttributes.ActivityState

    private var goalColor: Color {
        return Color(uiColor: attributes.goal.type.color)
    }

    private var lighterGoalColor: Color {
        return Color(uiColor: attributes.goal.type.color.darker(by: 20) ?? .red)
    }

    var body: some View {
        HStack {
            ZStack {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 4)
                    .frame(maxWidth: .infinity)
                    .overlay {
                        GeometryReader { geo in
                            ZStack {
                                HStack {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(
                                            LinearGradient(colors: [lighterGoalColor, goalColor],
                                                           startPoint: .leading,
                                                           endPoint: .trailing)
                                        )
                                    Spacer()
                                        .frame(width: CGFloat(1 - state.goalProgress) * geo.size.width)
                                }
                                .frame(height: 4)
                                .offset(y: -3.5)

                                Circle()
                                    .fill(goalColor)
                                    .frame(width: 10, height: 10)
                                    .overlay {
                                        Circle()
                                            .fill(goalColor)
                                            .frame(width: 11, height: 11)
                                            .blur(radius: 6)
                                            .opacity(0.5)
                                            .transition(.identity)
                                    }
                                    .offset(x: CGFloat(state.goalProgress - 0.5) * geo.size.width,
                                            y: -3.6)
                            }
                        }
                    }
            }

            Text(attributes.goal.shortFormattedTargetWithUnit)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
        }
        .padding(.trailing, 6)
        .animation(.easeInOut(duration: 0.15), value: state.goalProgress)
    }
}

@available(iOS 16.1, *)
struct RecordingLiveActivity_Previews: PreviewProvider {
    static var previews: some View {
        let attributes = RecordingLiveActivityAttributes(activityType: .bikeRide,
                                                         unit: .miles,
                                                         goal: RecordingGoal(type: .distance, unit: .miles, target: 10000))
        let state = RecordingLiveActivityAttributes.ActivityState(uptime: 0,
                                                                  state: .paused,
                                                                  duration: 322.1,
                                                                  distance: 444.2,
                                                                  elevationAScended: 231.0,
                                                                  pace: 632.0,
                                                                  avgSpeed: 31.0,
                                                                  totalCalories: 125.1,
                                                                  goalProgress: 0.1)

        VStack {
            Spacer()
            LockScreenLiveActivityView(attributes: attributes, state: state)
                .background {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.black.opacity(0.4))
                }
                .padding(20)
        }
        .background(Color.white)
    }
}
