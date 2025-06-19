// Licensed under the Any Distance Source-Available License
//
//  StatisticView.swift
//  StatisticView
//
//  Created by Daniel Kuntz on 8/3/21.
//

import UIKit
import PureLayout
import SwiftRichString

final class StatisticView: UIView {

    // MARK: -  Variables

    private var mainLabel: UILabel!
    private var secondaryLabel: UILabel!
    private var mainLabelText: String = ""
    private var superscriptText: String = ""
    private var mainLabelCenterConstraint: NSLayoutConstraint!
    private var secondaryLabelCenterConstraint: NSLayoutConstraint!

    private let mainLabelHeight: CGFloat = 35
    private let secondaryLabelHeight: CGFloat = 18

    private var alignment: StatisticAlignment = .left {
        didSet {
            updateAlignmentConstraints()
        }
    }

    var font: ADFont = .og {
        didSet {
            updateFont()
        }
    }

    var finalContentHeight: CGFloat {
        return mainLabelHeight + secondaryLabelHeight
    }

    // MARK: - Setup

    init() {
        super.init(frame: .zero)

        layer.masksToBounds = false

        mainLabel = UILabel()
        mainLabel.font = font.primaryFont
        addSubview(mainLabel)

        secondaryLabel = UILabel()
        secondaryLabel.font = font.secondaryFont
        addSubview(secondaryLabel)

        mainLabel.autoSetDimension(.height, toSize: mainLabelHeight)
        mainLabel.autoPinEdge(toSuperviewEdge: .top)
        mainLabelCenterConstraint = mainLabel.autoAlignAxis(toSuperviewAxis: .vertical)

        secondaryLabel.autoSetDimension(.height, toSize: secondaryLabelHeight)
        secondaryLabel.autoPinEdge(.top, to: .bottom, of: mainLabel)
        secondaryLabel.autoPinEdge(toSuperviewEdge: .bottom)
        secondaryLabelCenterConstraint = secondaryLabel.autoAlignAxis(toSuperviewAxis: .vertical)
        layoutIfNeeded()

        isUserInteractionEnabled = false
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateAlignmentConstraints()
    }

    func set(mainLabelText: String, secondaryLabelText: String, superscriptLabelText: String) {
        self.mainLabelText = mainLabelText
        self.superscriptText = superscriptLabelText
        updateMainLabel()
        secondaryLabel.text = secondaryLabelText
        updateAlignmentConstraints()
    }

    func setAlignment(alignment: StatisticAlignment, animated: Bool) {
        self.alignment = alignment
        if animated {
            UIView.animate(withDuration: 0.5,
                           delay: 0,
                           usingSpringWithDamping: 0.8,
                           initialSpringVelocity: 1,
                           options: [.beginFromCurrentState],
                           animations: {
                self.layoutIfNeeded()
            }, completion: nil)
        } else {
            layoutIfNeeded()
        }
    }

    func setPalette(_ palette: Palette, animated: Bool) {
        mainLabel.clipsToBounds = false
        mainLabel.layer.masksToBounds = false
        secondaryLabel.clipsToBounds = false
        secondaryLabel.layer.masksToBounds = false

        UIView.transition(with: self,
                          duration: animated ? 0.2 : 0,
                          options: [.transitionCrossDissolve],
                          animations: {
            self.mainLabel.textColor = palette.foregroundColor
            self.secondaryLabel.textColor = palette.foregroundColor

            if palette.backgroundColor == .black && palette.name != "Dark" {
                self.mainLabel.layer.shadowColor = UIColor.black.cgColor
                self.mainLabel.layer.shadowRadius = 7.0
                self.mainLabel.layer.shadowOpacity = 0.5
                self.secondaryLabel.layer.shadowColor = UIColor.black.cgColor
                self.secondaryLabel.layer.shadowRadius = 7.0
                self.secondaryLabel.layer.shadowOpacity = 0.5
            } else {
                self.mainLabel.layer.shadowColor = UIColor.clear.cgColor
                self.secondaryLabel.layer.shadowColor = UIColor.clear.cgColor
            }
        }, completion: nil)
    }

    private func updateMainLabel() {
        if !superscriptText.isEmpty {
            let style = mainLabelStyle()
            let string = mainLabelText + "<super> " + superscriptText + "</super>"
            mainLabel.attributedText = string.set(style: style)
            mainLabel.sizeToFit()
        } else {
            mainLabel.font = font.primaryFont
            mainLabel.text = mainLabelText
        }
    }

    private func mainLabelStyle() -> StyleXML {
        let normal = Style { $0.font = self.font.primaryFont }
        let superscript = Style {
            $0.font = self.font.secondaryFont
            $0.baselineOffset = self.font.superscriptBaselineOffset
        }
        return StyleXML(base: normal, ["super": superscript])
    }

    private func updateFont() {
        updateMainLabel()
        secondaryLabel.font = font.secondaryFont
        updateAlignmentConstraints()
    }

    private func updateAlignmentConstraints() {
        for (label, constraint) in zip([mainLabel, secondaryLabel],
                                       [mainLabelCenterConstraint, secondaryLabelCenterConstraint]) {
            let width = label!.intrinsicContentSize.width
            switch alignment {
            case .left:
                constraint?.constant = -1 * ((bounds.width / 2) - (width / 2))
            case .center:
                if label === mainLabel && !superscriptText.isEmpty {
                    let superscriptLabel = UILabel()
                    superscriptLabel.text = " " + superscriptText
                    superscriptLabel.font = font.secondaryFont
                    let superscriptWidth = superscriptLabel.intrinsicContentSize.width
                    constraint?.constant = superscriptWidth / 2
                } else {
                    constraint?.constant = 0
                }
            case .right:
                constraint?.constant = (bounds.width / 2) - (width / 2)
            }
        }
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}
