// Licensed under the Any Distance Source-Available License
//
//  Permissions.swift
//  ADAC
//
//  Created by Daniel Kuntz on 3/14/22.
//

import Foundation
import AVFoundation
import UIKit
import Combine

class Permissions: ObservableObject {

    // MARK: - Singleton

    static let shared = Permissions()

    // MARK: - Variables

    @Published var camera = AVCaptureDevice.authorizationStatus(for: .video)
    private var subscribers: Set<AnyCancellable> = []

    // MARK: - Setup

    init() {
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification).sink { [weak self] _ in
            self?.camera = AVCaptureDevice.authorizationStatus(for: .video)
        }.store(in: &subscribers)
    }
}
