// Licensed under the Any Distance Source-Available License
//
//  FrameRateRequest.swift
//  ADAC
//
//  Created by Daniel Kuntz on 6/29/22.
//

import UIKit
import Foundation

class FrameRateRequest {
    private let duration: Double

    /// Prepares your frame rate request parameters.
    init(duration: Double) {
        self.duration = duration
    }

    /// Perform frame rate request.
    func perform() {
        let displayLink = CADisplayLink(target: self, selector: #selector(dummyFunction))
        displayLink.preferredFramesPerSecond = 120
        displayLink.add(to: .current, forMode: .common)
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            displayLink.remove(from: .current, forMode: .common)
        }
    }

    @objc private func dummyFunction() {}
}
