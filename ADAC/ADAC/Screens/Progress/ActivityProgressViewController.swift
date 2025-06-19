// Licensed under the Any Distance Source-Available License
//
//  ProgressViewController.swift
//  ADAC
//
//  Created by Daniel Kuntz on 6/29/23.
//

import UIKit
import SwiftUI

class ActivityProgressViewController: SwiftUIViewController<ActivityProgressView> {
    override func createSwiftUIView() {
        swiftUIView = ActivityProgressView()
    }
}
