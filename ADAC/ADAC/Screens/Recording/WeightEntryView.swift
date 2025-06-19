// Licensed under the Any Distance Source-Available License
//
//  WeightEntryView.swift
//  ADAC
//
//  Created by Any Distance on 8/2/22.
//

import SwiftUI
import Introspect

struct WeightEntryView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var bodyMass: Double = 0.0
    @State private var unit: MassUnit = .kilograms
    
    private func saveBodyMass() {
        presentationMode.dismiss()
    }

    var body: some View {
        DataEntryView(data: bodyMass,
                      title: "Calorie Burn",
                      description: "With your current weight, we can improve the accuracy of your calorie burn. Data is written to and read from Apple Health and is not stored anywhere else.\n\nYou can edit this in Apple Health or Any Distance settings.",
                      inputTitle: "Weight",
                      confirmButtonTitle: "Save",
                      dismissButtonTitle: "Remind Me Later",
                      unit: ADUser.current.massUnit.abbreviation,
                      updateDataHandler: { data in
            self.bodyMass = data
            Task(priority: .medium) {
                try await ActivitiesData.shared.hkActivitiesStore.writeBodyMass(data,
                                                                                unit: ADUser.current.massUnit)
            }
        })
        .onDisappear {
            Task(priority: .medium) {
                if bodyMass == 0.0 {
                    NSUbiquitousKeyValueStore.default.writeDefaultBodyMass()
                } else {
                    try await ActivitiesData.shared.hkActivitiesStore.writeBodyMass(Double(bodyMass),
                                                                                    unit: ADUser.current.massUnit)
                }
            }
        }
    }
}

struct WeightEntryView_Previews: PreviewProvider {
    static var previews: some View {
        WeightEntryView()
    }
}
