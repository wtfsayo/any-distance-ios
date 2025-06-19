// Licensed under the Any Distance Source-Available License
//
//  ParallaxEffect.swift
//  ADAC
//
//  Created by Daniel Kuntz on 5/24/23.
//

import SwiftUI

struct ParallaxEffect: ViewModifier {
    @StateObject private var motionManager = MotionManager()
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(1.05)
            .offset(x: (motionManager.roll * -15.0).clamped(to: -8.0...8.0),
                    y: (motionManager.pitch * -15.0).clamped(to: -8.0...8.0))
            .animation(.easeInOut(duration: 0.05), value: motionManager.roll)
            .animation(.easeInOut(duration: 0.05), value: motionManager.pitch)
    }
}

extension View {
    func parallaxEffect() -> some View {
        modifier(ParallaxEffect())
    }
}
