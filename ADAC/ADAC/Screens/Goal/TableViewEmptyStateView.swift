// Licensed under the Any Distance Source-Available License
//
//  TableViewEmptyStateView.swift
//  ADAC
//
//  Created by Daniel Kuntz on 2/7/21.
//

import UIKit
import PureLayout

/// Generic empty state view for a table view or collection view. Shows an image, title label, subtitle
/// label, and a button with a custom action.
final class TableViewEmptyStateView: UIView {

    // MARK: - Variables

    var imageView: UIImageView!
    var bigLabel: UILabel!
    var label: UILabel!
    var button: UIButton!

    var buttonHandler: (() -> Void)?

    // MARK: - Setup

    init() {
        super.init(frame: .zero)
        backgroundColor = .clear

        imageView = UIImageView(image: UIImage(named: "activities_emptystate_eyes"))
        addSubview(imageView)
        label = UILabel()
        addSubview(label)
        bigLabel = UILabel()
        addSubview(bigLabel)
        button = UIButton()
        addSubview(button)

        imageView.autoAlignAxis(.horizontal, toSameAxisOf: self, withOffset: -60)
        imageView.autoAlignAxis(toSuperviewAxis: .vertical)

        button.backgroundColor = .white
        button.layer.cornerRadius = 8
        button.layer.cornerCurve = .continuous
        button.setTitle("Open Settings", for: .normal)
        button.setTitleColor(.black, for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 17)
        button.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 0, left: 30, bottom: 130, right: 30), excludingEdge: .top)
        button.autoSetDimension(.height, toSize: 50)
        button.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)

        bigLabel.autoPinEdge(toSuperviewEdge: .leading, withInset: 30)
        bigLabel.autoPinEdge(toSuperviewEdge: .trailing, withInset: 30)
        bigLabel.autoPinEdge(.top, to: .bottom, of: imageView, withOffset: 16)

        bigLabel.textColor = .white
        bigLabel.numberOfLines = 2
        bigLabel.textAlignment = .center
        bigLabel.font = UIFont(name: "PresicavRg-Regular", size: 26)
        bigLabel.text = "Syncing All Your\nHard Work"

        label.autoPinEdge(toSuperviewEdge: .leading, withInset: 30)
        label.autoPinEdge(toSuperviewEdge: .trailing, withInset: 30)
        label.autoPinEdge(.top, to: .bottom, of: bigLabel, withOffset: 16)

        label.textColor = .white
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 15)
        label.text = "This should only take a few moments."
    }

    func addRotationAnimation() {
        let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotation.toValue = CGFloat.pi * 2
        rotation.duration = 4
        rotation.isCumulative = true
        rotation.repeatCount = .greatestFiniteMagnitude
        imageView.layer.add(rotation, forKey: "rotationAnimation")
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    @objc private func buttonTapped() {
        buttonHandler?()
    }
}
