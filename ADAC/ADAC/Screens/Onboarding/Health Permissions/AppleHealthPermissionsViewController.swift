// Licensed under the Any Distance Source-Available License
//
//  AppleHealthPermissionsViewController.swift
//  ADAC
//
//  Created by Daniel Kuntz on 11/15/22.
//

import UIKit

/// SwiftUIViewController wrapper for AppleHealthPermissionsView
class AppleHealthPermissionsViewController: SwiftUIViewController<AppleHealthPermissionsView> {

    // MARK: - Variables

    var nextAction: (() -> Void)?

    // MARK: - Setup

    override func createSwiftUIView() {
        swiftUIView = AppleHealthPermissionsView(nextAction: nextAction)
    }
}
