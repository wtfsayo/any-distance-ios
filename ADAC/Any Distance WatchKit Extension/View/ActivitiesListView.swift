// Licensed under the Any Distance Source-Available License
//
//  ActivitiesListView.swift
//  Any Distance WatchKit Extension
//
//  Created by Any Distance on 8/16/22.
//

import SwiftUI
import HealthKit

fileprivate struct StepCountCell: View {
    @Environment(\.scenePhase) var scenePhase
    @State var stepCount: Int = -1

    private func reloadStepCount() {
        Task {
            stepCount = await WatchHealthKitActivitiesStore.shared.getTodaysStepCount()
        }
    }

    var body: some View {
        VStack {
            TitleLabel(title: "Step Count")
            HStack {
                Text(stepCount > 0 ? "\(stepCount)" : "--")
                    .font(.system(size: 24, weight: .regular, design: .monospaced))
                    .foregroundColor(.white)
                Spacer()
                Image("activity_steps")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 25, height: 25)
            }
        }
        .padding(.bottom, 10)
        .onAppear {
            self.reloadStepCount()
        }
        .onChange(of: scenePhase) { _ in
            self.reloadStepCount()
        }
    }
}

fileprivate struct ActivityCell: View {
    var activityType: ActivityType
    
    var body: some View {
        ZStack {
            HStack {
                Text(activityType.displayName)
                    .multilineTextAlignment(.leading)
                Spacer()
                Image(activityType.glyphName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 22, height: 22)
            }
            .background(Color.clear)
        }
    }
}

fileprivate struct ActivitiesTableViewCells: View {
    var activityTypes: [ActivityType]

    var body: some View {
        VStack(alignment: .center, spacing: 4) {
            ForEach(Array(activityTypes.enumerated()), id: \.element.rawValue) { (idx, type) in
                NavigationLink {
                    GoalSelectView(activityType: type)
                } label: {
                    ActivityCell(activityType: type)
                        .frame(height: 40)
                }
            }
        }
    }
}

struct TitleLabel: View {
    var title: String

    var body: some View {
        HStack {
            Text(title)
                .font(.presicav(size: 17))
                .foregroundColor(.white)
                .opacity(0.5)
                .multilineTextAlignment(.leading)
                .lineLimit(3)
                .truncationMode(.head)
                .minimumScaleFactor(0.5)
            Spacer()
        }
    }
}

fileprivate struct ActivitiesList: View {
    var activityTypesByCategory: [String: [ActivityType]]
    
    var body: some View {
        VStack(alignment: .center, spacing: 4) {
            let topSections = [ActivityListProvider.recentlyUsedSectionName,
                               ActivityListProvider.popularSectionName]
            let remainingSections = Array(activityTypesByCategory.keys)
                .filter { !topSections.contains($0) }
                .sorted()
            let sortedSections = topSections + remainingSections

            TitleLabel(title: "Start Activity")

            ForEach(sortedSections, id: \.self) { sectionName in
                HStack {
                    Text(sectionName)
                        .multilineTextAlignment(.leading)
                    Spacer()
                }
                .padding(.top, 4)
                
                let sortedActivities: [ActivityType] = {
                    if sectionName == ActivityListProvider.recentlyUsedSectionName ||
                       sectionName == ActivityListProvider.popularSectionName {
                        return activityTypesByCategory[sectionName] ?? []
                    } else {
                        return activityTypesByCategory[sectionName]?.sorted(by: \.displayName) ?? []
                    }
                }()

                ActivitiesTableViewCells(activityTypes: sortedActivities)
            }
        }
    }
}


struct ActivitiesListView: View {
    @Environment(\.scenePhase) var scenePhase
    @StateObject var prefs = iPhonePreferences.shared
    @State var activityTypesByCategory: [String: [ActivityType]] = [:]
    @State var healthKitAuthStatus: HKAuthorizationStatus = WatchHealthAuthorization.sharingAuthorizationStatus()

    private func reload() {
        activityTypesByCategory = ActivityListProvider.activityTypesByCategory()
        healthKitAuthStatus = WatchHealthAuthorization.sharingAuthorizationStatus()
    }

    var body: some View {
        ZStack {
            switch healthKitAuthStatus {
            case .notDetermined:
                ScrollView {
                    VStack {
                        Text("Any Distance needs access to your Health data to track workouts. On the following screen, tap \"Review,\" then turn on access for \"All Requested Data Below.\" Scroll down and tap \"Next,\" then repeat on the next screen.")
                        Button("Next") {
                            Task {
                                try? await WatchHealthAuthorization.requestAuthorization()
                            }
                            reload()
                        }
                    }
                }
            case .sharingAuthorized:
                ScrollView {
                    if prefs.showsStepCount {
                        StepCountCell()
                    }
                    ActivitiesList(activityTypesByCategory: activityTypesByCategory)
                }
                .toolbar(.hidden)
                .overlay {
                    VStack {
                        LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                            .frame(height: 30)
                        Color.clear
                    }
                    .ignoresSafeArea()
                }
            case .sharingDenied:
                Text("Any Distance needs access to your Health data to track workouts. Go to Watch Settings -> Health -> Apps -> Any Distance and turn all categories on.")
            default: EmptyView()
            }
        }
        .onAppear {
            reload()
        }
        .onChange(of: scenePhase) { _ in
            reload()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ActivitiesListView()
        }
        .previewDevice("Apple Watch Series 6 - 40mm")
    }
}
