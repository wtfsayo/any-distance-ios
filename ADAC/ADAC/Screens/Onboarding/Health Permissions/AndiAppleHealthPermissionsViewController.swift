// Licensed under the Any Distance Source-Available License
//
//  AndiAppleHealthPermissionsViewController.swift
//  ADAC
//
//  Created by Daniel Kuntz on 5/30/23.
//

import UIKit

/// SwiftUIViewController wrapper for AndiAppleHealthPermissionsView
class AndiAppleHealthPermissionsViewController: SwiftUIViewController<AndiAppleHealthPermissionsView> {

    // MARK: - Variables

    var nextAction: (() -> Void)?

    // MARK: - Setup

    override func createSwiftUIView() {
        swiftUIView = AndiAppleHealthPermissionsView(nextAction: nextAction)
    }
}
