// Licensed under the Any Distance Source-Available License
//
//  TableViewHeader.swift
//  ADAC
//
//  Created by Daniel Kuntz on 2/3/21.
//

import UIKit

final class TableViewHeader: UIView {
    private var label: UILabel!
    private var button: ScalingPressButton!
    private var buttonAction: (() -> Void)?

    init(title: String, showsShareGlyph: Bool = false, action: (() -> Void)? = nil) {
        super.init(frame: .zero)

        label = UILabel()
        setTitle(title)
        label.font = UIFont.presicav(size: 17)

        button = ScalingPressButton()
        button.tintColor = UIColor.white.withAlphaComponent(0.5)

        backgroundColor = .clear
        let gradient = UIImage(named: "cell_header_gradient")
        let imageView = UIImageView(image: gradient)
        imageView.contentMode = .scaleToFill
        addSubview(imageView)
        imageView.autoPinEdgesToSuperviewEdges()

        if showsShareGlyph {
            button.setImage(UIImage(systemName: "square.and.arrow.up"), for: .normal)
            let config = UIImage.SymbolConfiguration(pointSize: 17, weight: .medium, scale: .medium)
            button.setPreferredSymbolConfiguration(config, forImageIn: .normal)
        }

        addSubview(button)
        button.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .leading)
        button.autoSetDimension(.width, toSize: 60)

        addSubview(label)
        label.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 0, left: 15, bottom: 0, right: 0), excludingEdge: .trailing)

        if let action = action {
            buttonAction = action
            button.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
        } else {
            button.isUserInteractionEnabled = false
        }
    }

    @objc func buttonTapped() {
        buttonAction?()
    }

    func setTitle(_ title: String) {
        label.text = title
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}
