// Licensed under the Any Distance Source-Available License
//
//  OnboardingViewController.swift
//  ADAC
//
//  Created by Daniel Kuntz on 11/8/22.
//

import SwiftUI
import UIKit

/// Convenience SwiftUIViewController that contains an OnboardingView
class OnboardingViewController: SwiftUIViewController<OnboardingView> {

    let model: OnboardingViewModel = OnboardingViewModel()
    let screenName: String = "Onboarding"

    override func createSwiftUIView() {
        self.swiftUIView = OnboardingView(model: model)
    }
}
