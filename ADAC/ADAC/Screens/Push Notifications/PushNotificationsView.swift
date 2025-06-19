// Licensed under the Any Distance Source-Available License
//
//  PushNotificationsView.swift
//  ADAC
//
//  Created by Daniel Kuntz on 2/22/24.
//

import SwiftUI
import OneSignal

extension NSUbiquitousKeyValueStore {
    var pushReminders: [PushReminder] {
        get {
            let data = data(forKey: "pushReminders")
            if let data = data {
                return (try? JSONDecoder().decode([PushReminder].self, from: data)) ?? []
            }

            let calendar = Calendar.current
            var components = DateComponents()
            components.hour = 8
            components.minute = 0
            components.year = 2023
            let defaultTime = calendar.date(from: components)!.timeIntervalSince1970

            return [
                PushReminder(day: "Monday", time: defaultTime, on: true),
                PushReminder(day: "Tuesday", time: defaultTime, on: true),
                PushReminder(day: "Wednesday", time: defaultTime, on: true),
                PushReminder(day: "Thursday", time: defaultTime, on: true),
                PushReminder(day: "Friday", time: defaultTime, on: true),
                PushReminder(day: "Saturday", time: defaultTime, on: false),
                PushReminder(day: "Sunday", time: defaultTime, on: false),
            ]
        }

        set {
            if let data = try? JSONEncoder().encode(newValue) {
                set(data, forKey: "pushReminders")
            }
        }
    }

    var hasSetPushReminders: Bool {
        get {
            return object(forKey: "pushReminders") != nil
        }
    }
}

class ReminderNotificationScheduler {
    static let titles = [
        "Active Break: You In? 💪",
        "Today's Challenge 🎯",
        "Ready, Set, Go! 🚀",
        "Ready for a Boost? 🏃",
        "Make Today Count 📆",
        "Let’s Get Moving! 🚴"
    ]

    static let subtitles = [
        "Choose your adventure: walk, bike, hike, or run.",
        "Let's move towards your fitness goals together.",
        "Boost your mood and energy with a workout.",
        "Let loose, have fun, and get your heart pumping.",
        "Any activity, anywhere. Just start! #anydistancecounts",
        "Small movements can make a big difference.",
        "Time for a quick workout!"
    ]

    static func schedule(with reminders: [PushReminder], sendEvents: Bool = false) {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

        for (idx, reminder) in reminders.enumerated() {
            if !reminder.on {
                continue
            }

            let content = UNMutableNotificationContent()
            content.title = titles.randomElement()!
            content.body = subtitles.randomElement()!
            content.userInfo = ["type": "trackActivity"]
            content.sound = .default

            var dateComponents = Calendar.current.dateComponents([.hour, .minute, .timeZone], from: Date(timeIntervalSince1970: reminder.time))
            dateComponents.weekday = ((1 + idx) % 7) + 1
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Error scheduling notification: \(error)")
                } else {
                    print("Scheduled workout reminder for \(reminder.day)")
                    if sendEvents {
                        Analytics.logEvent("Scheduled workout reminder", "Notifications", .otherEvent,
                                           withParameters: ["day": reminder.day])
                    }
                }
            }
        }
    }
}

struct PushReminder: Codable, Equatable {
    var day: String
    var time: TimeInterval
    var on: Bool
}

struct PushNotificationsView: View {
    let screenName = "Notifications"
    
    @Environment(\.dismiss) var dismiss
    @State var days = NSUbiquitousKeyValueStore.default.pushReminders
    @State private var date = Date()

    func nextTapped() {
        Analytics.logEvent("Allow Push Notifications", screenName, .buttonTap)

        OneSignal.promptForPushNotifications(userResponse: { accepted in
            if accepted {
                Analytics.logEvent("Notifications Permission Granted", self.screenName, .otherEvent)

                DispatchQueue.main.async {
                    NSUbiquitousKeyValueStore.default.pushReminders = days
                    ReminderNotificationScheduler.schedule(with: days, sendEvents: true)
                    NSUbiquitousKeyValueStore.default.enableAllNotifications()
                    ActivitiesData.shared.startObservingNewActivities(for: .appleHealth)
                    dismiss()
                }
            } else {
                Analytics.logEvent("Notifications Permission Denied", self.screenName, .otherEvent)
                dismiss()
            }
        }, fallbackToSettings: false)
    }

    var body: some View {
        VStack {
            Spacer()
            VStack(alignment: .center, spacing: 16) {
                Image("andi_notifications")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(.top, 15.0)
                    .padding(.bottom, -20.0)

                Text("Stay motivated with a daily reminder to exercise. Customize in settings any time.")
                    .multilineTextAlignment(.center)
                    .padding([.leading, .trailing], 20.0)

                VStack(alignment: .center, spacing: 0.0) {
                    ForEach(0..<days.count, id: \.self) { idx in
                        HStack {
                            Toggle(isOn: Binding<Bool>(
                                get: { days[idx].on },
                                set: { newValue in
                                    days[idx].on = newValue
                                    days = days
                                }
                            ),
                                   label: {})
                                .scaleEffect(x: 0.9, y: 0.9, anchor: .leading)
                                .frame(width: 52.0)
                            Text(days[idx].day)
                            Spacer()
                            DatePicker("",
                                       selection: Binding<Date>(
                                        get: { Date(timeIntervalSince1970: days[idx].time) },
                                        set: { newValue in
                                            days[idx].time = newValue.timeIntervalSince1970
                                            days = days
                                        }),
                                       displayedComponents: [.hourAndMinute])
                            .datePickerStyle(.compact)
                            .padding(.trailing, -4.0)
                            .tint(Color.white)
                            .opacity(days[idx].on ? 1.0 : 0.0)
                            .animation(.easeInOut(duration: 0.2), value: days[idx].on)
                        }
                        .font(.system(size: 17.0))
                        .padding([.leading, .trailing], 12.0)
                        .padding([.top, .bottom,], 7.0)
                        .background(Color.white.opacity(0.05))
                        .if(idx == 0) { view in
                            view
                                .cornerRadius(12, corners: [.topLeft, .topRight])
                        }
                        .if(idx == days.count - 1) { view in
                            view
                                .cornerRadius(12, corners: [.bottomLeft, .bottomRight])
                        }

                        if (idx < days.count - 1) {
                            Color.white
                                .opacity(0.1)
                                .height(1.0)
                        }
                    }
                }
                .padding([.leading, .trailing], 20.0)

                ADWhiteButton(title: "Next") {
                    nextTapped()
                }
                .padding([.leading, .trailing], 20.0)
                .padding(.bottom, 12.0)
            }
            .background{
                Color(white: 0.05)
                    .cornerRadius(16, corners: [.topLeft, .topRight])
                    .ignoresSafeArea()
            }
        }
        .onChange(of: days) { _ in
            NSUbiquitousKeyValueStore.default.pushReminders = days
        }
        .onAppear {
            Analytics.logEvent(screenName, screenName, .screenViewed)
        }
    }
}

#Preview {
    PushNotificationsView()
}
