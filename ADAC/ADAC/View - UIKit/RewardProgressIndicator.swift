// Licensed under the Any Distance Source-Available License
//
//  RewardProgressIndicator.swift
//  ADAC
//
//  Created by Daniel Kuntz on 1/27/23.
//

import UIKit
import PureLayout

final class RewardProgressIndicator: UIView {

    // MARK: - Contants

    let trackHeight: CGFloat = 7
    let trackGradientColors: [UIColor] = [UIColor(hex: "#027307"),
                                          UIColor(hex: "#36C603"),
                                          UIColor(hex: "#B7FB69")]

    // MARK: - Variables

    private var inactiveTrack: UIView!
    private var activeTrack: GradientView!

    @Clamped(initialValue: 0.6, 0...1) var progress: CGFloat {
        didSet {
            updateProgress()
        }
    }

    private var activeTrackWidthConstraint: NSLayoutConstraint?

    // MARK: - Setup

    override func willMove(toSuperview newSuperview: UIView?) {
        super.willMove(toSuperview: newSuperview)
        setup()
    }

    private func setup() {
        inactiveTrack = UIView()
        inactiveTrack.backgroundColor = .white
        inactiveTrack.alpha = 0.3
        inactiveTrack.layer.cornerRadius = trackHeight / 2
        addSubview(inactiveTrack)
        inactiveTrack.autoAlignAxis(toSuperviewAxis: .horizontal)
        inactiveTrack.autoPinEdge(toSuperviewEdge: .leading)
        inactiveTrack.autoPinEdge(toSuperviewEdge: .trailing)
        inactiveTrack.autoSetDimension(.height, toSize: trackHeight)

        activeTrack = GradientView()
        activeTrack.colors = trackGradientColors
        activeTrack.layer.cornerRadius = trackHeight / 2
        addSubview(activeTrack)
        activeTrack.autoAlignAxis(toSuperviewAxis: .horizontal)
        activeTrack.autoPinEdge(toSuperviewEdge: .leading)
        activeTrackWidthConstraint = activeTrack.autoMatch(.width, to: .width, of: self, withMultiplier: progress)
        activeTrack.autoSetDimension(.height, toSize: trackHeight)

        activeTrack.layer.shadowColor = trackGradientColors[1].cgColor
        activeTrack.layer.shadowRadius = 10
        activeTrack.layer.shadowOpacity = 1.0
        activeTrack.layer.shadowOffset = .zero

        inactiveTrack.backgroundColor = trackGradientColors[0].withAlphaComponent(0.9)
    }

    func updateProgress() {
        activeTrackWidthConstraint?.autoRemove()
        activeTrackWidthConstraint = activeTrack.autoMatch(.width, to: .width, of: self, withMultiplier: self.progress)
    }
}

