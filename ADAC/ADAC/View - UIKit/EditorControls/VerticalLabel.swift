// Licensed under the Any Distance Source-Available License
//
//  VerticalLabel.swift
//  ADAC
//
//  Created by Daniel Kuntz on 11/12/21.
//

import UIKit
import PureLayout

final class VerticalLabel: UIView {
    private var label: UILabel!
    private var verticalPositionAnchor: UIView!

    init(text: String) {
        super.init(frame: .zero)

        verticalPositionAnchor = UIView()
        verticalPositionAnchor.backgroundColor = .clear
        addSubview(verticalPositionAnchor)
        verticalPositionAnchor.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 10, left: 0, bottom: 0, right: 0), excludingEdge: .bottom)
        verticalPositionAnchor.autoMatch(.height, to: .height, of: self, withMultiplier: 0.75)
        
        label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: 13, weight: .bold)
        label.textColor = .white
        label.alpha = 0.5
        addSubview(label)
        label.autoAlignAxis(.horizontal, toSameAxisOf: verticalPositionAnchor)
        label.autoAlignAxis(.vertical, toSameAxisOf: self, withOffset: 8)
        label.layer.transform = CATransform3DMakeRotation(-1 * .pi / 2, 0, 0, 1)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}
