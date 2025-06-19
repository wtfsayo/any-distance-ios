// Licensed under the Any Distance Source-Available License
//
//  YourClubViewController.swift
//  ADAC
//
//  Created by Daniel Kuntz on 2/23/23.
//

import UIKit

/// SwiftUIViewController wrapper for YourClubView
class YourClubViewController: SwiftUIViewController<YourClubView> {

    // MARK: - Variables

    private lazy var model: YourClubViewModel = YourClubViewModel(controller: self)

    // MARK: - Setup

    override func createSwiftUIView() {
        swiftUIView = YourClubView(model: model)
    }
}
