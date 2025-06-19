// Licensed under the Any Distance Source-Available License
//
//  PillPageControl.swift
//  PillPageControl
//
//  Created by Daniel Kuntz on 9/10/21.
//

import UIKit
import PureLayout

final class PillPageControl: UIView {
    enum PillPageControlMode {
        case pages
        case story
    }

    // MARK: - Variables

    var mode: PillPageControlMode = .pages {
        didSet {
            setup()
            updatePageIdx()
        }
    }

    var animatesPageIdxUpdate: Bool = false

    var numberOfPages: Int = 4 {
        didSet {
            setup()
        }
    }

    var pageIdx: CGFloat = 0 {
        didSet {
            updatePageIdx()
        }
    }

    var pillWidth: CGFloat = 58 {
        didSet {
            setup()
        }
    }

    var pillSpacing: CGFloat = 14 {
        didSet {
            setup()
        }
    }

    var pillHeight: CGFloat = 5 {
        didSet {
            setup()
        }
    }

    var leftRightMargin: CGFloat = 40 {
        didSet {
            adjustScale()
        }
    }

    private var pillViews: [UIView] = []
    private var indicatorLeadingConstraints: [NSLayoutConstraint] = []

    // MARK: - Constants

    private let deselectedColor: UIColor = .white.withAlphaComponent(0.5)
    private let selectedColor: UIColor = .white

    // MARK: - Setup

    override func willMove(toSuperview newSuperview: UIView?) {
        super.willMove(toSuperview: newSuperview)
        setup()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        adjustScale()
    }

    private func setup() {
        pillViews.forEach { view in
            view.removeFromSuperview()
        }
        pillViews.removeAll()
        indicatorLeadingConstraints.removeAll()

        for i in 0..<numberOfPages {
            let pill = UIView()
            pillViews.append(pill)
            pill.clipsToBounds = true
            pill.layer.masksToBounds = true
            pill.backgroundColor = deselectedColor
            pill.layer.cornerRadius = pillHeight / 2
            addSubview(pill)

            pill.autoSetDimension(.width, toSize: pillWidth)
            pill.autoSetDimension(.height, toSize: pillHeight)
            pill.autoAlignAxis(toSuperviewAxis: .horizontal)

            let distanceToCenter = CGFloat(i) - (CGFloat(numberOfPages - 1) / 2)
            let offset = distanceToCenter * (pillWidth + pillSpacing)
            pill.autoAlignAxis(.vertical, toSameAxisOf: self, withOffset: offset)

            let indicator = UIView()
            indicator.backgroundColor = selectedColor
            indicator.layer.cornerRadius = pillHeight / 2
            pill.addSubview(indicator)

            indicator.autoAlignAxis(toSuperviewAxis: .horizontal)
            indicator.autoSetDimension(.width, toSize: pillWidth)
            indicator.autoSetDimension(.height, toSize: pillHeight)
            let leadingConstraint = indicator.autoPinEdge(toSuperviewEdge: .leading, withInset: 0)
            indicatorLeadingConstraints.append(leadingConstraint)
        }

        updatePageIdx()
        adjustScale()
    }

    private func adjustScale() {
        // Scale down if there are a lot of pages
        let totalWidth = (pillWidth + pillSpacing) * CGFloat(numberOfPages)
        if totalWidth > bounds.size.width && bounds.size.width > 0 {
            self.transform = CGAffineTransform(scaleX: (bounds.size.width - leftRightMargin) / totalWidth, y: 1)
        }
    }

    private func updatePageIdx() {
        let block = {
            switch self.mode {
            case .pages:
                for (i, constraint) in self.indicatorLeadingConstraints.enumerated() {
                    constraint.constant = (self.pageIdx - CGFloat(i)) * (self.pillWidth + self.pillSpacing)
                }
            case .story:
                for (i, constraint) in self.indicatorLeadingConstraints.enumerated() {
                    constraint.constant = min(0, (self.pageIdx - CGFloat(i)) * (self.pillWidth + self.pillSpacing))
                }
            }
        }

        if animatesPageIdxUpdate {
            UIView.animate(withDuration: 0.1) {
                block()
                self.layoutIfNeeded()
            }
        } else {
            block()
        }
    }
}
