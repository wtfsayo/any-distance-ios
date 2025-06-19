// Licensed under the Any Distance Source-Available License
//
//  GoalWidget.swift
//  ADAC
//
//  Created by Daniel Kuntz on 9/15/22.
//

import WidgetKit
import SwiftUI
import Intents

struct GoalWidgetEntryProvider: IntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: ConfigurationIntent())
    }

    func getSnapshot(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), configuration: configuration)
        completion(entry)
    }

    func getTimeline(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        var entries: [SimpleEntry] = []

        // Generate a timeline consisting of five entries an hour apart, starting from the current date.
        let currentDate = Date()
        for hourOffset in 0 ..< 24 {
            let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate)!
            let entry = SimpleEntry(date: entryDate, configuration: configuration)
            entries.append(entry)
        }

        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationIntent
}

struct GoalWidgetEntryView : View {
    private var gradient: AngularGradient {
        return AngularGradient(
            gradient: Gradient(colors: [Color.adBrown,
                                        Color.adOrange,
                                        Color.adOrangeLighter]),
            center: .center,
            startAngle: .degrees(0),
            endAngle: .degrees(360 * Double(UserDefaults.appGroup.goalProgress)))
    }

    var body: some View {
        if UserDefaults.appGroup.doesGoalExist {
            ZStack {
                HStack {
                    VStack {
                        Image("logo_a")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 12, height: 12)
                            .opacity(0.3)
                        Spacer()
                    }
                    Spacer()
                }
                .padding(11)

                Image(UserDefaults.appGroup.goalActivityType.glyphName)
                    .resizable()
                    .scaleEffect(0.4)

                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 11)
                    .padding(16)
                    .overlay(
                        Circle()
                            .trim(from: 0, to: CGFloat(UserDefaults.appGroup.goalProgress))
                            .stroke(gradient, style: StrokeStyle(lineWidth: 11, lineCap: .round))
                            .rotationEffect(Angle.degrees(90))
                            .scaleEffect(x: -1, y: -1, anchor: .center)
                            .padding(16)
                    )
                    .overlay(
                        Circle()
                            .trim(from: CGFloat(UserDefaults.appGroup.goalProgress-0.001),
                                  to: CGFloat(UserDefaults.appGroup.goalProgress))
                            .stroke(Color.adOrangeLighter,
                                    style: StrokeStyle(lineWidth: 15, lineCap: .round))
                            .rotationEffect(Angle.degrees(90))
                            .scaleEffect(x: -1, y: -1, anchor: .center)
                            .padding(16)
                            .shadow(color: .adOrangeLighter, radius: 10, x: 0, y: 0)
                    )

            }
            .background(Color.black)
        } else {
            ZStack {
                Color.black

                VStack {
                    Image("glyph_goal_big")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60, height: 60)
                        .padding(.bottom, 5)
                    Text("Tap to open Any Distance and start a new goal")
                        .font(Font.system(size: 12))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                        .lineLimit(3)
                        .padding([.leading, .trailing], 16)
                }
            }
        }
    }
}

struct GoalWidget: Widget {
    let kind: String = "Widget"

    var body: some WidgetConfiguration {
        IntentConfiguration(kind: kind,
                            intent: ConfigurationIntent.self,
                            provider: GoalWidgetEntryProvider()) { entry in
            GoalWidgetEntryView()
        }
        .configurationDisplayName("Goal Progress")
        .description("Track your goal progress in Any Distance.")
        .supportedFamilies([.systemSmall])
    }
}
