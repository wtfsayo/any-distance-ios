// Licensed under the Any Distance Source-Available License
//
//  Settings.swift
//  ADAC
//
//  Created by Daniel Kuntz on 12/8/21.
//

import SwiftUI
import SafariServices

// MARK: - Sections

struct NavBar: View {
    var title: String
    var closeTitle: String
    var closeAction: (() -> Void)?

    var body: some View {
        HStack {
            HStack {
                Text(title)
                    .foregroundColor(Color(UIColor.adGray3))
                    .font(.presicav(size: 18))
                Spacer()
                Button {
                    closeAction?()
                } label: {
                    Text(closeTitle)
                        .font(.system(size: 17.0, weight: .medium, design: .default))
                        .foregroundColor(.white)
                }
            }
            .padding(20)
        }
        .background(Color(white: 0.1, opacity: 1).ignoresSafeArea())
    }
}

fileprivate struct TitleView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var scrollViewOffset: CGFloat
    var presentedInSheet: Bool
    var showCloseButton: Bool

    var body: some View {
        HStack {
            VStack {
                Spacer()
                    .frame(height: 45.0)

                let p = (scrollViewOffset / -80.0)
                Text("Settings")
                    .font(.presicav(size: 31.0))
                    .scaleEffect((0.6 + ((1.0 - p) * 0.4)).clamped(to: 0.6...1.0),
                                 anchor: .leading)
                    .offset(y: scrollViewOffset < 0 ? (-1 * scrollViewOffset) : (-0.7 * scrollViewOffset))
                    .offset(y: (-22.0 * p).clamped(to: -22.0...0.0))
                    .opacity((0.6 + ((1.0 - p) * 0.4)).clamped(to: 0.6...1.0))
            }
            Spacer()
            if presentedInSheet || showCloseButton {
                Button {
                    presentationMode.dismiss()
                } label: {
                    Image(systemName: .xmarkCircleFill)
                        .font(.system(size: 20.0, weight: .medium))
                        .padding()
                        .contentShape(Rectangle())
                        .foregroundStyle(Color.white)
                }
                .offset(y: scrollViewOffset < 0 ? (-1 * scrollViewOffset) : (-0.7 * scrollViewOffset))
            }
        }
        .padding(.top, -22.5)
        .padding([.leading, .trailing], 15.0)
    }
}

struct SuperDistance: View {
    @ObservedObject var model: SettingsViewModel
    @ObservedObject var iapManager: iAPManager

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if iapManager.isSubscribed {
                SuperDistanceSubscribed(model: model, iapManager: iapManager)
            } else {
                SuperDistanceNotSubscribed(model: model, iapManager: iapManager)
            }
        }
    }
}

struct SuperDistanceNotSubscribed: View {
    @ObservedObject var model: SettingsViewModel
    @ObservedObject var iapManager: iAPManager

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(uiImage: .init(named: "glyph_superdistance_white")!)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 17)
            Spacer()
                .frame(height: 14)
            TableViewCell(text: "See Features",
                          accessoryImage: Image(systemName: "sparkles"),
                          type: .top,
                          onTap: model.seeFeaturesAction)
            TableViewCell(text: "Restore Purchase",
                          accessoryImage: Image(systemName: "goforward.plus"),
                          type: .bottom,
                          onTap: model.restoreAction)
        }
        .padding([.leading, .trailing], 20)
    }
}

struct SuperDistanceSubscribed: View {
    @ObservedObject var model: SettingsViewModel
    @ObservedObject var iapManager: iAPManager

    var priceString: String? {
        return iapManager.subscribedProduct?.localizedPrice ?? "Free"
    }

    var durationString: String {
        return iapManager.formattedDuration
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(uiImage: .init(named: "glyph_superdistance_white")!)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 17)
            Spacer()
                .frame(height: 14)
            HStack(alignment: .top, spacing: 12) {
                VStack() {
                    VStack(alignment: .center, spacing: 4) {
                        if let priceString = priceString {
                            Text(priceString)
                                .font(.presicav(size: 26, weight: .bold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.3)
                                .padding([.leading, .trailing], 7)
                            Text(durationString)
                                .font(.system(size: 16, weight: .medium, design: .default))
                            if iapManager.isSubscribedToLifetime {
                                Text("Purchased")
                                    .font(.system(size: 13))
                                    .foregroundColor(.green)
                            } else if iapManager.subscriptionIsNotCancellable {
                                Text("Redeemed")
                                    .font(.system(size: 13))
                                    .foregroundColor(.green)
                            } else {
                                Text("Subscribed")
                                    .font(.system(size: 13))
                                    .foregroundColor(.green)
                            }
                        } else {
                            ProgressView()
                        }
                    }
                    .animation(.linear(duration: 0.2))
                    .frame(width: 110, height: 102)
                }.overlay (
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color(white: 0.13), lineWidth: 3)
                )

                if iapManager.subscriptionIsNotCancellable {
                    VStack(alignment: .leading, spacing: 0) {
                        TableViewCell(text: "Features",
                                      accessoryImage: Image(systemName: "sparkles"),
                                      type: .top,
                                      onTap: model.seeFeaturesAction)
                        TableViewCell(text: "Billing Support",
                                      accessoryImage: Image(systemName: "message.fill"),
                                      type: .bottom,
                                      onTap: model.billingSupportAction)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        TableViewCell(text: "Cancel Plan",
                                      accessoryImage: Image(systemName: .xmarkCircleFill),
                                      type: .top,
                                      onTap: model.cancelPlanAction)
                        TableViewCell(text: "Billing Support",
                                      accessoryImage: Image(systemName: "message.fill"),
                                      type: .bottom,
                                      onTap: model.billingSupportAction)
                    }
                }
            }
            Spacer()
                .frame(height: 14)
            if iapManager.subscriptionIsNotCancellable {
                TableViewCell(text: "Expires on \(iapManager.formattedExpirationDate)",
                              accessoryImage: Image(systemName: "clock.arrow.circlepath"),
                              type: .floating,
                              onTap: nil)
            } else {
                TableViewCell(text: "Renews on \(iapManager.formattedExpirationDate)",
                              accessoryImage: Image(systemName: "clock.arrow.circlepath"),
                              type: .top,
                              onTap: model.renewsAction)
                TableViewCell(text: "Features",
                              accessoryImage: Image(systemName: "sparkles"),
                              type: .middle,
                              onTap: model.seeFeaturesAction)
                TableViewCell(text: "Join Beta",
                              accessoryImage: Image(systemName: "testtube.2"),
                              type: .bottom,
                              onTap: model.joinBetaAction)
            }
        }
        .padding([.leading, .trailing], 20)
    }
}

struct Display: View {
    @Binding var distanceUnit: DistanceUnit
    @Binding var showStepCountOn: Bool
    @Binding var showBrandingOn: Bool
    @Binding var showCollaborationsOn: Bool
    @ObservedObject var model: SettingsViewModel
    @ObservedObject var iapManager: iAPManager

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeaderText(text: "Display")
                .padding(.bottom, 8)
            let distancePicker = Picker("Display", selection: $distanceUnit) {
                Text("Mi").tag(DistanceUnit.miles)
                Text("Km").tag(DistanceUnit.kilometers)
            }
            .pickerStyle(.segmented)
            .frame(width: 124)
            TableViewCell(text: "Distance Metric",
                          accessory: AnyView(distancePicker),
                          type: .top)

            let stepCountSwitch = Toggle("", isOn: $showStepCountOn)
                .frame(width: 100)
            TableViewCell(text: "Show Step Count & Summaries",
                          accessory: AnyView(stepCountSwitch),
                          type: .middle)

            let collaborationSwitch = Toggle("", isOn: $showCollaborationsOn)
                .frame(width: 100)
            TableViewCell(text: "Collaboration Collectibles",
                          accessory: AnyView(collaborationSwitch),
                          type: .bottom)

            Text("You can choose to opt out of our Collectible collaborations with brands. These may include paid partnerships.")
                .font(.system(size: 13, weight: .regular, design: .default))
                .opacity(0.7)
                .padding([.leading, .trailing], 8)
                .padding(.top, 8)
                .fixedSize(horizontal: false, vertical: true)
        }.padding([.leading, .trailing], 20)
    }
}

struct DataEntryCell: View {
    let title: String
    @Binding var data: Double
    @State private var isEditing: Bool = false
        
    private var dataFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.minimum = 0.0
        formatter.numberStyle = .decimal
        return formatter
    }
    
    var body: some View {
        let textField = TextField("",
                                  value: $data,
                                  formatter: dataFormatter)
            .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidBeginEditingNotification)) { obj in
                if let textField = obj.object as? UITextField {
                    textField.selectedTextRange = textField.textRange(from: textField.beginningOfDocument, to: textField.endOfDocument)
                }
            }
            .introspectTextField { textField in
                textField.addDoneToolbar()
            }
            .keyboardType(.decimalPad)
            .disableAutocorrection(true)
            .frame(width: 130)
            .multilineTextAlignment(.trailing)
        
        TableViewCell(text: title,
                      accessory: AnyView(textField),
                      type: .floating)
            .padding(.bottom, 8)
    }
}


struct WeightEntryCell: View {
    @Binding var bodyMass: Int
    @State private var isEditing: Bool = false
    @Binding var massUnit: MassUnit
    var submitsOnKeyboardDismiss: Bool = false
    
    private func updateBodyMass() {
        if submitsOnKeyboardDismiss {
            Task(priority: .medium) {
                try await ActivitiesData.shared.hkActivitiesStore.writeBodyMass(Double(bodyMass),
                                                                                unit: massUnit)
            }
        }
    }

    private func updateUnit() {
        bodyMass = Int(UnitConverter.value(NSUbiquitousKeyValueStore.default.bodyMassKg,
                                           fromUnit: .kilograms,
                                           toUnit: massUnit).rounded())
    }
    
    var body: some View {
        let text = Binding<String>(
                get: {
                    if isEditing {
                        return "\(bodyMass)"
                    }
                    return "\(bodyMass) \(massUnit.abbreviation)"
                },
                set: { text in
                    if isEditing {
                        bodyMass = Int(text) ?? bodyMass
                    }
                }
            )
        
        let textField = TextField("", text: text, isEditing: $isEditing)
            .introspectTextField { textField in
                textField.addDoneToolbar()
            }
            .keyboardType(.numberPad)
            .disableAutocorrection(true)
            .frame(width: 130)
            .multilineTextAlignment(.trailing)
            .onChange(of: isEditing) { _ in
                if !isEditing {
                    updateBodyMass()
                }
            }
        
        TableViewCell(text: "Weight",
                      accessory: AnyView(textField),
                      type: .floating)
            .padding(.bottom, 8)
            .onChange(of: massUnit) { _ in
                updateUnit()
            }
            .onAppear {
                updateUnit()
            }
    }
}

struct BodyMeasurements: View {
    @State var bodyMass: Int = 0
    @Binding var massUnit: MassUnit
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeaderText(text: "Body Measurements")
                .padding(.bottom, 8)
            
            WeightEntryCell(bodyMass: $bodyMass,
                            massUnit: $massUnit,
                            submitsOnKeyboardDismiss: true)
            
            Text("With your current weight, we can improve the accuracy of your calorie burn. Data is written to and read from Apple Health and is not stored anywhere else.")
                .font(.system(size: 13, weight: .regular, design: .default))
                .foregroundColor(.white)
                .opacity(0.7)
                .padding(.leading, 5)
        }
        .padding([.leading, .trailing], 20)
    }
}

struct PrivacyRecordingSettings: View {
    @State var clipRoute: Bool = NSUbiquitousKeyValueStore.default.defaultRecordingSettings.clipRoute
    @State var showSafetyMessagePrompt: Bool = NSUbiquitousKeyValueStore.default.defaultRecordingSettings.showSafetyMessagePrompt
    @State private var routeClipPercent: Double = NSUbiquitousKeyValueStore.default.defaultRecordingSettings.routeClipPercentage
    @State var routeClipDescription: String = NSUbiquitousKeyValueStore.default.defaultRecordingSettings.routeClipDescriptionString

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeaderText(text: "Privacy")
                .padding(.bottom, 8)
            
            let routeClipToggle = Toggle("", isOn: $clipRoute)
            TableViewCell(text: "Clip route for sharing", accessory: AnyView(routeClipToggle), type: .top)
            VStack(spacing: 2) {
                Slider(value: $routeClipPercent, in: 0.01...0.4)
                    .tint(.white)
                    .saturation(clipRoute ? 1.0 : 0.0)
                    .brightness(clipRoute ? 0.0 : -0.3)
                    .animation(.easeInOut(duration: 0.25), value: clipRoute)
                    .allowsHitTesting(clipRoute)
                    .padding(.top, 8)
                    .introspectSlider { slider in
                        slider.minimumTrackTintColor = UIColor(white: 0.6, alpha: 1.0)
                        slider.setThumbImage(UIImage(systemName: "circle.fill"),
                                             for: .normal)
                    }

                HStack {
                    let percents: [Int] = [1, 10, 20, 30, 40]
                    ForEach(percents, id: \.self) { percent in
                        let textColor: Color = (routeClipPercent * 100) >= Double(percent) ? .white : .init(white: 0.5)
                        Text("\(percent)%")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(textColor)
                        if percent != 40 {
                            let dotColor: Color = (routeClipPercent * 100) >= Double(percent + 5) ? .white : .init(white: 0.3)
                            Spacer()
                                .overlay {
                                    Circle()
                                        .frame(width: 2, height: 2)
                                        .foregroundColor(dotColor)
                                }
                        }
                    }
                }
                .saturation(clipRoute ? 1.0 : 0.0)
                .opacity(clipRoute ? 1.0 : 0.6)
                .animation(.easeInOut(duration: 0.25), value: clipRoute)
                .padding(.bottom, 8)
                .padding([.leading, .trailing], 3)
                .offset(y: -6)
            }
            .padding([.leading, .trailing], 15)
            .background {
                Rectangle()
                    .fill(Color(white: 0.125))
                    .opacity(clipRoute ? 1.0 : 0.5)
                    .animation(.easeInOut(duration: 0.25), value: clipRoute)
            }
            
            Spacer()
                .frame(height: 0.5)
                .frame(maxWidth: .infinity)
                .background(Color(white: 0.25))

            TableViewCell(text: "Read our Privacy Commitment",
                          accessoryImage: Image(systemName: "lock.shield.fill"),
                          type: .bottom, onTap: {
                Analytics.logEvent("Read our Privacy Commitment", "Settings", .buttonTap)
                UIApplication.shared.topViewController?.openUrl(withString: Links.privacyCommitment.absoluteString)
            })

            Text(routeClipDescription)
                .font(.system(size: 13, weight: .regular, design: .default))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundColor(.white)
                .padding(.top, 8)
                .padding(.bottom, 20)
                .padding(.leading, 5)
                .opacity(0.7)
            
            let safetyMessageToggle = Toggle("", isOn: $showSafetyMessagePrompt)
            TableViewCell(text: "Safety Message Prompt", accessory: AnyView(safetyMessageToggle), type: .floating)
            Text("Get prompts to message friends and family your activity start and finish location.")
                .font(.system(size: 13, weight: .regular, design: .default))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundColor(.white)
                .padding(.top, 8)
                .padding(.leading, 5)
                .opacity(0.7)
            
        }
        .padding([.leading, .trailing], 20)
        .onChange(of: clipRoute) { newValue in
            NSUbiquitousKeyValueStore.default.defaultRecordingSettings.clipRoute = newValue
        }
        .onChange(of: routeClipPercent) { newValue in
            NSUbiquitousKeyValueStore.default.defaultRecordingSettings.routeClipPercentage = newValue.rounded(toPlaces: 2)
            routeClipDescription = NSUbiquitousKeyValueStore.default.defaultRecordingSettings.routeClipDescriptionString
        }
        .onChange(of: showSafetyMessagePrompt) { newValue in
            Analytics.logEvent("Changed Safety Message Prompt Setting", "Privacy Recording Settings", .buttonTap, withParameters: ["enabled": newValue])

            NSUbiquitousKeyValueStore.default.defaultRecordingSettings.showSafetyMessagePrompt = newValue
        }
    }
}

struct ActiveClubNotifications: View {
    @State var newPost: Bool = ADUser.current.activeClubNotificationSettings.setting(for: .newPost)
    @State var commentsAndReactions: Bool = ADUser.current.activeClubNotificationSettings.setting(for: .commentsAndReactions)
    @State var friendRequest: Bool = ADUser.current.activeClubNotificationSettings.setting(for: .friendRequest)
    @State var friendApproval: Bool = ADUser.current.activeClubNotificationSettings.setting(for: .friendApproval)
    @State var friendJoin: Bool = ADUser.current.activeClubNotificationSettings.setting(for: .friendJoin)
    @State var friendSuggestion: Bool = ADUser.current.activeClubNotificationSettings.setting(for: .friendSuggestion)
    @State var startOfTheWeek: Bool = ADUser.current.activeClubNotificationSettings.setting(for: .startOfTheWeek)

    private func updateUser() {
        Task(priority: .userInitiated) {
            do {
                try await UserManager.shared.updateUser(.current)
            } catch {
                DispatchQueue.main.async {
                    UIApplication.shared.topViewController?.showFailureToast(with: error)
                }
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeaderText(text: "Active Club Notifications")
                .padding(.bottom, 8)

            TableViewCell(text: "New activity posts",
                          accessory: AnyView(Toggle("", isOn: $newPost)),
                          type: .top)
            TableViewCell(text: "Post comments and reactions",
                          accessory: AnyView(Toggle("", isOn: $commentsAndReactions)),
                          type: .middle)
            TableViewCell(text: "Friend requests",
                          accessory: AnyView(Toggle("", isOn: $friendRequest)),
                          type: .middle)
            TableViewCell(text: "Friend approvals",
                          accessory: AnyView(Toggle("", isOn: $friendApproval)),
                          type: .middle)
            TableViewCell(text: "Friend joined Any Distance",
                          accessory: AnyView(Toggle("", isOn: $friendJoin)),
                          type: .middle)
            TableViewCell(text: "Friend suggestions",
                          accessory: AnyView(Toggle("", isOn: $friendSuggestion)),
                          type: .middle)
            TableViewCell(text: "Start of the week",
                          accessory: AnyView(Toggle("", isOn: $startOfTheWeek)),
                          type: .bottom)
        }
        .padding([.leading, .trailing], 20)
        .onChange(of: newPost) { newValue in
            ADUser.current.activeClubNotificationSettings.set(newValue, for: .newPost)
            updateUser()
        }
        .onChange(of: commentsAndReactions) { newValue in
            ADUser.current.activeClubNotificationSettings.set(newValue, for: .commentsAndReactions)
            updateUser()
        }
        .onChange(of: friendRequest) { newValue in
            ADUser.current.activeClubNotificationSettings.set(newValue, for: .friendRequest)
            updateUser()
        }
        .onChange(of: friendApproval) { newValue in
            ADUser.current.activeClubNotificationSettings.set(newValue, for: .friendApproval)
            updateUser()
        }
        .onChange(of: friendJoin) { newValue in
            ADUser.current.activeClubNotificationSettings.set(newValue, for: .friendJoin)
            updateUser()
        }
        .onChange(of: friendSuggestion) { newValue in
            ADUser.current.activeClubNotificationSettings.set(newValue, for: .friendSuggestion)
            updateUser()
        }
        .onChange(of: startOfTheWeek) { newValue in
            ADUser.current.activeClubNotificationSettings.set(newValue, for: .startOfTheWeek)
            updateUser()
        }
    }
}

struct AutoLockSettings: View {
    @State var preventAutoLock = NSUbiquitousKeyValueStore.default.defaultRecordingSettings.preventAutoLock

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeaderText(text: "Auto-Lock")
                .padding(.bottom, 8)

            let autoLockToggle = Toggle("", isOn: $preventAutoLock)
            TableViewCell(text: "Prevent screen auto-lock", accessory: AnyView(autoLockToggle), type: .floating)

            Text("This will keep your screen on indefinitely during activity tracking unless you lock your device manually.")
                .font(.system(size: 13, weight: .regular, design: .default))
                .foregroundColor(.white)
                .padding(.top, 8)
                .padding(.leading, 5)
                .opacity(0.7)
        }
        .padding([.leading, .trailing], 20)
        .onChange(of: preventAutoLock) { newValue in
            NSUbiquitousKeyValueStore.default.defaultRecordingSettings.preventAutoLock = newValue
        }
    }
}

struct Notifications: View {
    @ObservedObject var model: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeaderText(text: "Notifications")
                .padding(.bottom, 8)
            TableViewCell(text: "Daily Workout Reminders", accessoryImage: Image(systemName: "chevron.right"), type: .top, onTap: model.dailyRemindersAction)
            let shareAccessory = Toggle("", isOn: $model.activityShareReminderNotificationsOn)
                .frame(width: 100)
            TableViewCell(text: "Activity Share Reminders", accessory: AnyView(shareAccessory), type: .middle)
            let featureAccessory = Toggle("", isOn: $model.featureNotificationsOn)
                .frame(width: 100)
            TableViewCell(text: "Feature Updates", accessory: AnyView(featureAccessory), type: .middle)
            let collectiblesAccessory = Toggle("", isOn: $model.collectiblesNotificationsOn)
                .frame(width: 100)
            TableViewCell(text: "Collectible Updates", accessory: AnyView(collectiblesAccessory), type: .bottom)
        }.padding([.leading, .trailing], 20)
    }
}

struct SyncConnect: View {
    @ObservedObject var model: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeaderText(text: "Sync Connect")
                .padding(.bottom, 8)
            TableViewCell(text: "Apple Health Permissions",
                          accessoryImage: Image(systemName: "checkmark.circle.fill"),
                          accessoryTint: (ActivitiesData.shared.hasHealthKitActivities ? Color(UIColor.adGreen) : nil),
                          type: .top,
                          onTap: model.appleHealthAction)
            TableViewCell(text: "Learn More About Syncing",
                          accessoryImage: Image(systemName: "info.circle.fill"),
                          type: .bottom,
                          onTap: model.learnMoreSyncingAction)
        }.padding([.leading, .trailing], 20)
        
        // external services
        VStack(alignment: .leading, spacing: 0) {
            
            switch model.garminConnectionState {
            case .disconnected:
                TableViewCell(text: "Connect",
                              image: Image(ExternalService.garmin.imageNameSmall),
                              accessoryImage: Image(systemName: "chevron.right"),
                              type: .top,
                              onTap: model.garminAction)
            case .revoked:
                TableViewCell(text: "Reconnect",
                              image: Image(ExternalService.garmin.imageNameSmall),
                              accessoryImage: Image(systemName: "exclamationmark.triangle.fill"),
                              type: .top,
                              onTap: model.garminAction)
            case .connected:
                TableViewCell(image: Image(ExternalService.garmin.imageNameSmall),
                              accessoryImage: Image(systemName: "checkmark.circle.fill"),
                              accessoryTint: Color(UIColor.adGreen),
                              type: .top,
                              onTap: model.garminAction)
            case .unknown:
                TableViewCell(text: "Checking Garmin status...",
                              type: .top,
                              onTap: nil)
            }

            switch model.wahooConnectionState {
            case .disconnected:
                TableViewCell(text: "Connect",
                              image: Image(ExternalService.wahoo.imageNameSmall),
                              accessoryImage: Image(systemName: "chevron.right"),
                              type: .bottom,
                              onTap: model.wahooAction)
            case .revoked:
                TableViewCell(text: "Reconnect",
                              image: Image(ExternalService.wahoo.imageNameSmall),
                              accessoryImage: Image(systemName: "exclamationmark.triangle.fill"),
                              type: .bottom,
                              onTap: model.wahooAction)
            case .connected:
                TableViewCell(image: Image(ExternalService.wahoo.imageNameSmall),
                              accessoryImage: Image(systemName: "checkmark.circle.fill"),
                              accessoryTint: Color(UIColor.adGreen),
                              type: .bottom,
                              onTap: model.wahooAction)
            case .unknown:
                TableViewCell(text: "Checking Wahoo status...",
                              type: .bottom,
                              onTap: nil)
            }
        }.padding([.leading, .trailing], 20)

    }
}

struct AppIconButton: View {
    var icon: Image
    var name: String
    var idx: Int
    var lockedAction: () -> Void
    @ObservedObject var iapManager: iAPManager
    @Binding var selectedIdx: Int

    private var isSelected: Bool {
        return selectedIdx == idx
    }

    var body: some View {
        VStack(alignment: .center, spacing: 14) {
            Button {
                withAnimation(.linear(duration: 0.1)) {
                    if iapManager.hasSuperDistanceFeatures || idx <= 1 {
                        selectedIdx = idx
                    } else {
                        lockedAction()
                    }
                }
            } label: {
                icon
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 66, height: 66)
                    .mask(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        GeometryReader { geo in
                            let offset: CGFloat = 12
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(isSelected ? Color(UIColor.adOrangeLighter) : Color.clear, lineWidth: 2.5)
                                .frame(width: geo.size.width + offset, height: geo.size.height + offset, alignment: .center)
                                .offset(x: offset / -2, y: offset / -2)
                        }
                    )
                    .overlay(
                        GeometryReader { geo in
                            if !(iapManager.hasSuperDistanceFeatures || idx <= 1) {
                                let img = UIImage(named: "glyph_lock")!
                                Image(uiImage: img)
                                    .offset(x: (img.size.width / img.scale) / 2, y: (img.size.height / img.scale) / 2)
                                    .offset(x: geo.size.width / 2.3, y: geo.size.height / -2.3)
                            } else {
                                EmptyView()
                            }
                        }
                    )
            }
            VStack {
                Text(name)
                    .font(.system(size: 15, weight: .medium, design: .default))
                    .foregroundColor(isSelected ? Color(UIColor.adOrangeLighter) : Color.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: 90)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: 20)
        }
    }
}

struct AppIconView: View {
    @ObservedObject var model: SettingsViewModel
    @ObservedObject var iapManager: iAPManager

    @State var selectedIdx: Int = AppIcon.selectedIconIdx

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeaderText(text: "App Icon")
                .padding(.bottom, 8)
            VStack(alignment: .center, spacing: 20) {
                ForEach(stride(from: 0, to: AppIcon.allCases.count - 2, by: 3).map { $0 },
                        id: \.self) { idx in
                    HStack {
                        ForEach(AppIcon.allCases[idx...(idx + 2)], id: \.self) { icon in
                            AppIconButton(icon: Image(uiImage: icon.previewImage),
                                          name: icon.displayName,
                                          idx: icon.rawValue,
                                          lockedAction: {},
                                          iapManager: iapManager,
                                          selectedIdx: $selectedIdx)
                            if icon.rawValue < (idx + 2) {
                                Spacer()
                            }
                        }
                    }
                }

                if Config.isDebug || Config.isTestFlight {
                    let icon = AppIcon.allCases.last!
                    HStack {
                        AppIconButton(icon: Image(uiImage: icon.previewImage),
                                      name: icon.displayName,
                                      idx: icon.rawValue,
                                      lockedAction: {},
                                      iapManager: iapManager,
                                      selectedIdx: $selectedIdx)
                        Spacer()
                    }
                }
            }
            .padding(EdgeInsets(top: 24, leading: 30, bottom: 16, trailing: 30))
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .foregroundColor(Color(white: 0.07))
            )
        }
        .padding([.leading, .trailing], 20)
        .onChange(of: selectedIdx) { newValue in
            model.setAppIcon(newValue)
        }
    }
}

struct About: View {
    @ObservedObject var model: SettingsViewModel
    @State private var showingSheet: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeaderText(text: "About")
                .padding(.bottom, 8)
            TableViewCell(text: "New Features and News",
                          accessoryImage: Image(systemName: "newspaper.fill"),
                          type: .top,
                          onTap: { self.showingSheet.toggle() })
            TableViewCell(text: "Request New Features",
                          accessoryImage: Image(systemName: .lightbulbFill),
                          type: .middle,
                          onTap: model.requestNewFeaturesAction)
            TableViewCell(text: "Follow @anydistance",
                          accessoryImage: Image(systemName: "plus.circle.fill"),
                          type: .middle,
                          onTap: model.followAction)
            TableViewCell(text: "Contact Us",
                          accessoryImage: Image(systemName: .envelopeFill),
                          type: .middle,
                          onTap: model.contactAction)
            TableViewCell(text: "Send Feedback",
                          accessoryImage: Image(systemName: .messageFill),
                          type: .bottom,
                          onTap: model.sendFeedbackAction)
        }
        .padding([.leading, .trailing], 20)
        .sheet(isPresented: $showingSheet) {
            Updates()
        }
    }
}

struct TakeNote: View {
    @ObservedObject var model: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeaderText(text: "Take Note")
                .padding(.bottom, 8)
            TableViewCell(text: "Our Privacy Commitment",
                          accessoryImage: Image(systemName: "eye.circle.fill"),
                          type: .top,
                          onTap: model.privacyCommitmentAction)
            TableViewCell(text: "Privacy Policy",
                          accessoryImage: Image(systemName: "lock.fill"),
                          type: .middle,
                          onTap: model.privacyPolicyAction)
            TableViewCell(text: "Terms and Conditions",
                          accessoryImage: Image(systemName: "pencil.and.outline"),
                          type: .bottom,
                          onTap: model.termsAction)
        }.padding([.leading, .trailing], 20)
    }
}

struct Admin: View {
    @ObservedObject var model: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeaderText(text: "Admin")
                .padding(.bottom, 8)
            TableViewCell(text: "Show Onboarding",
                          type: .top,
                          onTap: model.showOnboardingAction)

            ZStack {
                let featureAccessory = Toggle("", isOn: $model.overrideHasPosted)
                    .frame(width: 100)
                TableViewCell(text: "Blur this week's posts",
                              accessory: AnyView(featureAccessory),
                              type: .middle)
            }

            ZStack {
                let featureAccessory = Toggle("", isOn: $model.overrideShowNoFriendsEmptyState)
                    .frame(width: 100)
                TableViewCell(text: "Show no friends empty state",
                              accessory: AnyView(featureAccessory),
                              type: .bottom)
            }
        }.padding([.leading, .trailing], 20)
    }
}

struct DangerZone: View {
    @ObservedObject var model: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeaderText(text: "Danger Zone")
                .padding(.bottom, 8)
            if ADUser.current.hasRegistered {
                TableViewCell(text: "Delete Account",
                              accessoryImage: Image(systemName: "minus.circle.fill"),
                              type: .top,
                              onTap: model.deleteAccountAction)
            }
            TableViewCell(text: "Recalculate collectibles",
                          type: ADUser.current.hasRegistered ? .bottom : .floating,
                          onTap: model.recalculateCollectiblesAction)
            Text("If you think you didn't earn a collectible that you should have earned, or if you lost your collectibles for some reason, this will recalculate all your earned collectibles.")
                .font(.system(size: 13, weight: .regular, design: .default))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundColor(.white)
                .padding(.top, 8)
                .padding(.leading, 5)
                .opacity(0.7)
        }.padding([.leading, .trailing], 20)
    }
}

struct UserIDButton: View {
    @State private var copied: Bool = false

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            Button(copied ? "Copied!" : "User ID: \(ADUser.current.id)\nApp Version: \(UIApplication.shared.versionAndBuildNumber)") {
                UIPasteboard.general.string = ADUser.current.id + " " + UIApplication.shared.versionAndBuildNumber
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    copied = false
                }
            }
            .font(.system(size: 10, weight: .regular, design: .monospaced))
            .foregroundColor(.white)
        }
    }
}

struct CreatorView: View {
    var image: Image
    var title: String
    var subtitle: String
    var instaURL: URL
    var twitterURL: URL

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            image
                .frame(width: 105, height: 160)
                .cornerRadius(52.5)
            Spacer()
                .frame(height: 8)
            Text(title)
                .font(.presicav(size: 16, weight: .bold))
            Text(subtitle)
                .font(.system(size: 14, weight: .regular, design: .monospaced))
            Spacer()
                .frame(height: 16)
            HStack(alignment: .center, spacing: 16) {
                Link(destination: instaURL) {
                    Image(uiImage: .init(named: "glyph_insta")!)
                }

                Link(destination: twitterURL) {
                    Image(uiImage: .init(named: "glyph_twitter")!)
                }
            }
        }.frame(width: 130)
    }
}

struct SwiftUIFlickeringImageView: UIViewRepresentable {
    typealias UIViewType = FlickeringImageView
    var image: UIImage?

    func makeUIView(context: Context) -> FlickeringImageView {
        return FlickeringImageView(image: image)
    }

    func updateUIView(_ uiView: FlickeringImageView, context: Context) {
        uiView.image = image
    }
}

struct Credits: View {
    var body: some View {
        VStack(alignment: .center, spacing: 12) {
            SwiftUIFlickeringImageView(image: UIImage(named: "madewithsoul")!)
                .frame(width: 80, height: 52)
                .padding([.top, .bottom], 30)

            Group {
                Text("Our Investors")
                    .font(.presicav(size: 18))
                    .padding(.bottom, 6)
                HStack(alignment: .center, spacing: 50) {
                    Image("investor_overline")
                    Image("investor_bungalow")
                }
                Spacer()
                    .height(4)
                HStack(alignment: .center, spacing: 50) {
                    Image("investor_fitt")
                    Image("investor_shorewind")
                }
                Spacer()
                    .height(4)
                Text("Alex Baldwin, Kyle Bragger, Varadh Jain, Behzod Sirjani, Oliver Cameron, Joel Califa, Brian Lovin, Jack Cohen, Stew Bradley, Chris Jennings, Josh Pigford, Amy Devereux, Max Di Capua, Parteek Saran, Cameron Koczon, Chacho Valadez, Katie Chen, Taylor Pemberton, Santi Pochat, Michael E. Gruen, Daley Ervin, Tom Moor, Kat Cole, Trent Gegax, The Gramercy Fund, James Nord, Willem Van Lancker, OliveX")
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .multilineTextAlignment(.center)
                Spacer()
                    .height(4)
            }

            Group {
                Text("Special Thanks")
                    .font(.presicav(size: 18))
                Text("Hipstamatic, Nicole Loher, Zach Cole, Jaz Atherton, Rebecca Carmen, Jared Erickson, Lyzi Unwin, Amy Devereux, Aravind Kaimal, Tim Apple, Ben Clement, Joseph Danger, James Nord, Tracksmith stuff, Simon Schmid, Daniel Zarick, Aravind Kaimal, Lucas Buick, Nikhil Sethi, Mike Smith, Josh Abbott, Switchyards, Jarod Luebbert, Gabi Valladares")
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .multilineTextAlignment(.center)
            }
        }
        .padding([.leading, .trailing], 20)
    }
}

struct SayHiToAndi: View {
    @State private var playing: Bool = false

    var body: some View {
        ZStack {
            Button {
                playing = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                    playing = false
                }
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 25, style: .continuous)
                        .fill(Color.white)
                    Text("Say Hi to Andi →")
                        .foregroundColor(.black)
                        .font(.system(size: 14, weight: .semibold))
                }
                .frame(width: 150, height: 45)
            }
            .opacity(playing ? 0 : 1)
            .animation(.easeInOut(duration: 0.5), value: playing)

            if playing {
                LoopingVideoView(videoUrl: Bundle.main.url(forResource: "andi", withExtension: "mov")!)
                    .opacity(playing ? 1 : 0)
                    .animation(.easeInOut(duration: 0.3), value: playing)
            }
        }
        .frame(height: UIScreen.main.bounds.width)
    }
}

struct Footer: View {
    var body: some View {
        ZStack {
            Image(uiImage: UIImage(named: "settings_route")!)
                .frame(height: 220)
                .aspectRatio(contentMode: .fill)
            VStack(alignment: .center, spacing: 0) {
                Image(uiImage: UIImage(named: "wordmark")!)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 211)
                    .padding([.bottom], 12)
                Text("© Any Distance Inc. 2024")
                    .foregroundColor(.white)
                    .font(.system(size: 13))
                    .opacity(0.6)
                    .padding([.bottom], 15)
                Text("#AnyDistanceCounts")
                    .font(.presicav(size: 18))
                    .foregroundColor(.white)
            }
            .offset(y: -80)
        }
        .offset(y: 60)
    }
}

// MARK: - Main View

struct Settings: View {
    @ObservedObject var model: SettingsViewModel
    var presentedInSheet: Bool
    var showCloseButton: Bool = false
    @StateObject var iapManager: iAPManager = iAPManager.shared

    @State var scrollViewOffset: CGFloat = 0.0
    @State var distanceUnit: DistanceUnit = ADUser.current.distanceUnit
    @State var showStepCountOn: Bool = NSUbiquitousKeyValueStore.default.shouldShowStepCount
    @State var showBrandingOn: Bool = NSUbiquitousKeyValueStore.default.shouldShowAnyDistanceBranding
    @State var showCollaborationCollectibles: Bool = NSUbiquitousKeyValueStore.default.shouldShowCollaborationCollectibles
    @State private var massUnit = ADUser.current.massUnit

    @ViewBuilder
    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            ReadableScrollView(offset: $scrollViewOffset) {
                VStack(alignment: .center, spacing: 20) {
                    if presentedInSheet {
                        Spacer()
                            .frame(height: 4.0)
                    }

                    TitleView(scrollViewOffset: $scrollViewOffset,
                              presentedInSheet: presentedInSheet,
                              showCloseButton: showCloseButton)
                    .zIndex(1000)

                    VStack(alignment: .center, spacing: 20.0) {
                        Group {
                            SuperDistance(model: model,
                                          iapManager: iapManager)
                            PrivacyRecordingSettings()
                            Display(distanceUnit: $distanceUnit,
                                    showStepCountOn: $showStepCountOn,
                                    showBrandingOn: $showBrandingOn,
                                    showCollaborationsOn: $showCollaborationCollectibles,
                                    model: model,
                                    iapManager: iapManager)
                            SyncConnect(model: model)
                            if ADUser.current.hasRegistered {
                                ActiveClubNotifications()
                            }
                            BodyMeasurements(massUnit: $massUnit)
                        }

                        Group {
                            AutoLockSettings()
                            Notifications(model: model)
                            AppIconView(model: model, iapManager: iapManager)
                            About(model: model)
                            TakeNote(model: model)
                            if ADUser.current.isTeamADAC {
                                Admin(model: model)
                            }
                            DangerZone(model: model)
                            UserIDButton()
                        }

                        Group {
                            Credits()
                            SayHiToAndi()
                            Footer()
                            Spacer()
                                .frame(height: 30.0)
                        }
                    }
                    .mask {
                        VStack(spacing: 0) {
                            Image("gradient_bottom_ease_in_out")
                                .renderingMode(.template)
                                .resizable(resizingMode: .stretch)
                                .frame(width: UIScreen.main.bounds.width, height: 60.0)
                                .foregroundColor(.black)
                            Color.black
                                .padding(.bottom, -800)
                        }
                        .offset(y: -1 * scrollViewOffset)
                        .offset(y: -60.0)
                    }
                }
            }
            .background(Color.black)
        }
        .edgesIgnoringSafeArea(.bottom)
        .onChange(of: distanceUnit) { newValue in
            model.setDisplayAction(newValue)
            massUnit = ADUser.current.massUnit
        }
        .onChange(of: showStepCountOn) { newValue in
            model.setStepCountOnAction(newValue)
        }
        .onChange(of: showBrandingOn) { newValue in
            model.setShowBrandingOnAction(newValue)
        }
        .onChange(of: showCollaborationCollectibles) { newValue in
            model.setShowCollaborationsOnAction(newValue)
        }
        .onChange(of: model.overrideHasPosted) { newValue in
            NSUbiquitousKeyValueStore.default.overrideHasPosted = newValue
            PostCache.shared.postCachedPublisher.send()
        }
        .onChange(of: model.overrideShowNoFriendsEmptyState) { newValue in
            NSUbiquitousKeyValueStore.default.overrideShowNoFriendsEmptyState = newValue
            PostCache.shared.postCachedPublisher.send()
        }
    }
}

struct Settings_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            Settings(model: SettingsViewModel(controller: SettingsViewController()), 
                     presentedInSheet: false)
            AppIconView(model: SettingsViewModel(controller: SettingsViewController()), 
                        iapManager: .shared)
        }
    }
}
