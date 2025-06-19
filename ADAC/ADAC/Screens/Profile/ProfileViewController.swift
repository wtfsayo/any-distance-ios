// Licensed under the Any Distance Source-Available License
//
//  ProfileViewController.swift
//  ADAC
//
//  Created by Daniel Kuntz on 2/23/23.
//

import UIKit

/// SwiftUIViewController wrapper around ProfileView
class ProfileViewController: SwiftUIViewController<ProfileView> {

    // MARK: - Variables

    private lazy var model: ProfileViewModel = ProfileViewModel(controller: self)

    // MARK: - Setup

    override func createSwiftUIView() {
        swiftUIView = ProfileView(model: model)
    }
}
