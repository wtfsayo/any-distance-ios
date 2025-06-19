// Licensed under the Any Distance Source-Available License
//
//  PoweredByHipstaView.swift
//  ADAC
//
//  Created by Daniel Kuntz on 5/11/21.
//

import UIKit
import PureLayout
import SafariServices

final class PoweredByHipstaView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)

        let divider = UIView()
        divider.backgroundColor = UIColor(white: 1, alpha: 0.2)
        divider.layer.cornerRadius = 1
        addSubview(divider)

        let logoImageView = UIImageView(image: UIImage(named: "powered_by_hipstamatic_big"))
        addSubview(logoImageView)

        let button = ScalingPressButton()
        button.backgroundColor = UIColor.hipstaYellow
        button.layer.cornerCurve = .continuous
        button.layer.cornerRadius = 10
        button.setTitle("Learn More", for: .normal)
        button.setTitleColor(.black, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        button.addTarget(self, action: #selector(learnMoreTapped), for: .touchUpInside)
        addSubview(button)

        divider.autoPinEdge(toSuperviewEdge: .leading)
        divider.autoSetDimension(.width, toSize: 2)
        divider.autoPinEdge(toSuperviewEdge: .top, withInset: 24)
        divider.autoPinEdge(toSuperviewEdge: .bottom)
        divider.autoAlignAxis(toSuperviewAxis: .horizontal)

        logoImageView.autoPinEdge(.leading, to: .trailing, of: divider, withOffset: 34)
        logoImageView.autoAlignAxis(.horizontal, toSameAxisOf: divider)

        button.autoSetDimensions(to: CGSize(width: 140, height: 46))
        button.autoAlignAxis(.horizontal, toSameAxisOf: divider)
        button.autoPinEdge(.leading, to: .trailing, of: logoImageView, withOffset: 28)
        button.autoPinEdge(toSuperviewEdge: .trailing, withInset: 28)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func learnMoreTapped() {
        Analytics.logEvent("Tap Learn More", "Filters Submenu", .buttonTap)
        let url = URL(string: "https://apps.apple.com/app/apple-store/id1450672436?pt=290258&ct=AnyDistanceFilterBar&mt=8")!
        let vc = SFSafariViewController(url: url)
        UIApplication.shared.topViewController?.present(vc, animated: true, completion: nil)
    }
}
