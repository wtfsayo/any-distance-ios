// Licensed under the Any Distance Source-Available License
//
//  ActivityRingView.swift
//  ADAC
//
//  Created by Daniel Kuntz on 6/29/23.
//

import SwiftUI
import HealthKitUI

struct ActivityRingView: UIViewRepresentable {
    @Binding var summary: HKActivitySummary?

    func makeUIView(context: Context) -> HKActivityRingView {
        let activityRingView = HKActivityRingView(frame: .zero)
        return activityRingView
    }

    func updateUIView(_ activityRingView: HKActivityRingView, context: Context) {
        activityRingView.setActivitySummary(summary, animated: true)
    }
}
