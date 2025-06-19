// Licensed under the Any Distance Source-Available License
//
//  BlurView.swift
//  ADAC
//
//  Created by Daniel Kuntz on 2/14/22.
//

import SwiftUI
import UIKit
import CoreImage.CIFilterBuiltins
import QuartzCore

struct DarkBlurView: View {
    var body: some View {
        BlurView(style: .systemUltraThinMaterialDark, intensity: 0.8)
            .brightness(-0.08)
    }
}

struct LightBlurView: View {
    var body: some View {
        BlurView(style: .systemUltraThinMaterialLight, intensity: 0.8)
            .brightness(0.18)
    }
}

struct BlurView: UIViewRepresentable {
    var style: UIBlurEffect.Style = .systemMaterial
    var intensity: CGFloat = 1.0
    var animatesIn: Bool = false
    var animateOut: Bool = false

    func makeUIView(context: Context) -> CustomIntensityVisualEffectView {
        if animatesIn {
            let view = CustomIntensityVisualEffectView(effect: UIBlurEffect(style: style), intensity: 0.0)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                view.animate(toIntensity: intensity, duration: 0.4)
            }
            return view
        }
        
        return CustomIntensityVisualEffectView(effect: UIBlurEffect(style: style),
                                               intensity: intensity)
    }

    func updateUIView(_ uiView: CustomIntensityVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
        
        if animateOut {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                uiView.animate(toIntensity: 0.0, duration: 0.2)
            }
        }
    }
}

class CustomIntensityVisualEffectView: UIVisualEffectView {
    
    private var displayLink: CADisplayLink?
    private var startTime: Date?
    private var duration: TimeInterval?
    private var targetIntensity: CGFloat?
    private var startIntensity: CGFloat?
    
    /// Create visual effect view with given effect and its intensity
    ///
    /// - Parameters:
    ///   - effect: visual effect, eg UIBlurEffect(style: .dark)
    ///   - intensity: custom intensity from 0.0 (no effect) to 1.0 (full effect) using linear scale
    init(effect: UIVisualEffect, intensity: CGFloat) {
        super.init(effect: nil)
        animator = UIViewPropertyAnimator(duration: 0.4, curve: .easeOut) { [unowned self] in self.effect = effect }
        animator.fractionComplete = intensity
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError()
    }

    // MARK: Private
    private var animator: UIViewPropertyAnimator!

    func animate(toIntensity intensity: CGFloat, duration: CGFloat) {
        self.startTime = Date()
        self.duration = duration
        self.targetIntensity = intensity
        self.startIntensity = self.animator.fractionComplete
        self.displayLink = CADisplayLink(target: self, selector: #selector(updateAnimationState))
        if #available(iOS 15.0, *) {
            self.displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 80, maximum: 120, preferred: 120)
        }
        self.displayLink?.add(to: .main, forMode: .common)
        self.displayLink?.add(to: .main, forMode: .tracking)
    }
    
    func easeOutQuad(_ x: Double) -> Double {
        return 1 - (1 - x) * (1 - x)
    }
    
    @objc private func updateAnimationState() {
        guard let startTime = startTime,
              let duration = duration,
              let startIntensity = startIntensity,
              let targetIntensity = targetIntensity else {
            return
        }

        let fractionComplete = Date().timeIntervalSince(startTime) / duration
        let easedFraction = easeOutQuad(fractionComplete)
        animator.fractionComplete = (easedFraction * (targetIntensity - startIntensity)) + startIntensity
        
        if fractionComplete >= 1.0 {
            self.displayLink?.remove(from: .main, forMode: .common)
            self.displayLink = nil
            self.startTime = nil
            self.duration = nil
            self.startIntensity = 0
            self.targetIntensity = 0
        }
    }
}


public enum VariableBlurDirection {
    case blurredTopClearBottom
    case blurredBottomClearTop
}


public struct VariableBlurView: UIViewRepresentable {
    public var maxBlurRadius: CGFloat = 2
    public var direction: VariableBlurDirection = .blurredTopClearBottom
    public var startOffset: CGFloat = 0

    public func makeUIView(context: Context) -> VariableBlurUIView {
        VariableBlurUIView(maxBlurRadius: maxBlurRadius, direction: direction, startOffset: startOffset)
    }

    public func updateUIView(_ uiView: VariableBlurUIView, context: Context) {}
}


open class VariableBlurUIView: UIVisualEffectView {
    public init(maxBlurRadius: CGFloat = 20, 
                direction: VariableBlurDirection = .blurredTopClearBottom,
                startOffset: CGFloat = 0) {
        super.init(effect: UIBlurEffect(style: .regular))

        // Same but no need for `CAFilter.h`.
        let CAFilter = NSClassFromString("CAFilter")! as! NSObject.Type
        let variableBlur = CAFilter.self.perform(NSSelectorFromString("filterWithType:"), with: "variableBlur").takeUnretainedValue() as! NSObject

        // The blur radius at each pixel depends on the alpha value of the corresponding pixel in the gradient mask.
        // An alpha of 1 results in the max blur radius, while an alpha of 0 is completely unblurred.
        let gradientImage = direction == .blurredTopClearBottom ? UIImage(named: "layout_top_gradient")?.cgImage : UIImage(named: "layout_gradient")?.cgImage

        variableBlur.setValue(maxBlurRadius, forKey: "inputRadius")
        variableBlur.setValue(gradientImage, forKey: "inputMaskImage")
        variableBlur.setValue(true, forKey: "inputNormalizeEdges")

        // We use a `UIVisualEffectView` here purely to get access to its `CABackdropLayer`,
        // which is able to apply various, real-time CAFilters onto the views underneath.
        let backdropLayer = subviews.first?.layer

        // Replace the standard filters (i.e. `gaussianBlur`, `colorSaturate`, etc.) with only the variableBlur.
        backdropLayer?.filters = [variableBlur]

        // Get rid of the visual effect view's dimming/tint view, so we don't see a hard line.
        for subview in subviews.dropFirst() {
            subview.alpha = 0
        }
    }

    override open func layoutSubviews() {
        subviews.first?.layer.frame = self.bounds
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        subviews.first?.layer.filters = nil
    }

    open override func didMoveToWindow() {
        // fixes visible pixelization at unblurred edge (https://github.com/nikstar/VariableBlur/issues/1)
        guard let window, let backdropLayer = subviews.first?.layer else { return }
        backdropLayer.setValue(window.screen.scale, forKey: "scale")
    }

    open override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {}
}
