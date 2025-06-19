// Licensed under the Any Distance Source-Available License
//
//  RecordingActivityPickerView.swift
//  ADAC
//
//  Created by Daniel Kuntz on 6/28/22.
//

import SwiftUI
import HealthKit
import UIKit

fileprivate struct HeaderView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var searchText: String

    var body: some View {
        VStack {
            VStack(spacing: 0) {
                HStack {
                    Button {
                        UIApplication.shared.topViewController?.openUrl(withString: Links.faq.absoluteString)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: .infoCircleFill)
                                .foregroundColor(.white)
                            Text("FAQ")
                                .foregroundColor(.white)
                                .fontWeight(.medium)
                        }
                    }
                    Spacer()
                    Button {
                        presentationMode.wrappedValue.dismiss()
                    } label: {
                        Text("Cancel")
                            .foregroundColor(.white)
                            .fontWeight(.medium)
                    }
                }
                .padding(15)
            }
            .background(Color(hexadecimal: "#1D1D1D"))

            SearchField(text: $searchText)
                .placeholder("Search")
        }
    }
}

fileprivate struct ActivitiesTableViewCells: View {
    var activityTypes: [ActivityType]
    var tapHandler: (ActivityType) -> Void

    private func cellType(for idx: Int) -> TableViewCellType {
        if activityTypes.count == 1 {
            return .floating
        }

        switch idx {
        case 0:
            return .top
        case activityTypes.count - 1:
            return .bottom
        default:
            return .middle
        }
    }

    private func image(for type: ActivityType) -> Image? {
        return Image(type.glyphName)
    }

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            ForEach(Array(activityTypes.enumerated()), id: \.element.rawValue) { (idx, type) in
                TableViewCell(text: type.displayName,
                              image: nil,
                              accessoryImage: image(for: type),
                              imageSize: CGSize(width: 30, height: 30),
                              accessoryTint: .white,
                              type: cellType(for: idx)) {
                    tapHandler(type)
                }
            }
        }
    }
}

struct ActivitiesList: View {
    @State var activityTypesByCategory: [String: [ActivityType]]
    @Binding var searchText: String
    var tapHandler: (ActivityType) -> Void

    var filteredActivityTypesByCategory: [String: [ActivityType]] {
        if searchText.isEmpty {
            return activityTypesByCategory
        }

        return activityTypesByCategory.filter { element in
            return element.value.contains(where: { $0.displayName.lowercased().contains(searchText.lowercased()) })
        }.mapValues { types in
            return types.filter { $0.displayName.lowercased().contains(searchText.lowercased()) }
        }
    }

    var body: some View {
        VStack(alignment: .center, spacing: 12) {
            let sortedSections = Array(filteredActivityTypesByCategory.keys).sorted { cur, next in
                if cur == ActivityListProvider.recentlyUsedSectionName { return true }
                if next == ActivityListProvider.recentlyUsedSectionName { return false }
                return cur < next
            }

            ForEach(sortedSections, id: \.self) { sectionName in
                SectionHeaderText(text: sectionName)
                    .padding(.top, 12)
                    .lineLimit(1)
                    .padding([.leading, .trailing], 20)

                let sortedActivities: [ActivityType] = {
                    if sectionName == ActivityListProvider.recentlyUsedSectionName {
                        return filteredActivityTypesByCategory[sectionName] ?? []
                    } else {
                        return filteredActivityTypesByCategory[sectionName]?.sorted(by: \.displayName) ?? []
                    }
                }()

                ActivitiesTableViewCells(activityTypes: sortedActivities, tapHandler: tapHandler)
                    .padding([.leading, .trailing])
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 40)
    }
}

struct RecordingActivityPickerView: View {
    @Environment(\.presentationMode) var presentationMode

    @State var searchText: String = ""
    @State var selectedActivityType: ActivityType = .unknown
    @State var presentingGoalSelection: Bool = false
    @State var confettiStarted: Bool = false

    func tapHandler(_ type: ActivityType) {
        selectedActivityType = type
        presentingGoalSelection = true
    }

    private var bindingForPresentationMode: Binding<PresentationMode?> {
        return Binding<PresentationMode?>.init(get: {
            return presentationMode.wrappedValue
        }, set: { newValue in
            presentationMode.wrappedValue = newValue ?? presentationMode.wrappedValue
        })
    }

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            HeaderView(searchText: $searchText)
            ScrollView {
                ActivitiesList(activityTypesByCategory: ActivityListProvider.activityTypesByCategory(),
                               searchText: $searchText,
                               tapHandler: tapHandler(_:))
            }
            .edgesIgnoringSafeArea([.top])
            .maxHeight(.infinity)
            .background(Color.black)
        }
        .fullScreenCover(isPresented: $presentingGoalSelection) {
            RecordingGoalSelectionView(rootViewPresentationMode: bindingForPresentationMode,
                                       activityType: $selectedActivityType)
                .background(BackgroundClearView())
        }
    }
}

struct RecordingActivityPickerView_Previews: PreviewProvider {
    static var previews: some View {
        RecordingActivityPickerView()
    }
}
