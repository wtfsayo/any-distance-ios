// Licensed under the Any Distance Source-Available License
//
//  LocationActivityTypeView.swift
//  LocationActivityTypeView
//
//  Created by Daniel Kuntz on 8/3/21.
//

import UIKit
import PureLayout

final class LocationActivityTypeView: UIView {

    private(set) var locationContainer: UIView!
    private(set) var locationLabel: UILabel!
    private(set) var locationImageView: UIImageView!
    private var activityTypeContainer: UIView!
    private var activityTypeHeightConstraint: NSLayoutConstraint!
    private(set) var activityTypeImageView: UIImageView!

    var activityTypeOn: Bool {
        return activityTypeHeightConstraint.constant != 0
    }

    var locationOn: Bool {
        return locationContainer.alpha > 0
    }

    var locationTextEmpty: Bool {
        return (locationLabel.text ?? "").isEmpty
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        locationContainer = UIView()
        locationContainer.backgroundColor = .clear
        addSubview(locationContainer)

        locationLabel = UILabel()
        locationLabel.font = UIFont.presicav(size: 8)
        locationContainer.addSubview(locationLabel)

        locationImageView = UIImageView(image: UIImage(named: "glyph_location"))
        locationImageView.layer.minificationFilter = .trilinear
        locationImageView.layer.minificationFilterBias = 0.05
        locationImageView.contentMode = .scaleAspectFit
        locationImageView.tintColor = .white
        locationContainer.addSubview(locationImageView)

        activityTypeContainer = UIView()
        activityTypeContainer.backgroundColor = .clear
        addSubview(activityTypeContainer)

        activityTypeImageView = UIImageView(image: UIImage(named: "glyph_run"))
        activityTypeImageView.contentMode = .scaleAspectFit
        activityTypeImageView.tintColor = .white
        activityTypeContainer.addSubview(activityTypeImageView)

        locationImageView.autoSetDimension(.width, toSize: 6.5)
        locationImageView.autoPinEdge(toSuperviewEdge: .leading)
        locationImageView.autoPinEdge(.trailing, to: .leading, of: locationLabel, withOffset: -4)
        locationImageView.autoAlignAxis(.horizontal, toSameAxisOf: locationLabel, withOffset: 0.5)
        locationLabel.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .leading)
        locationContainer.autoPinEdge(.trailing, to: .trailing, of: activityTypeContainer, withOffset: -4)

        activityTypeImageView.autoSetDimensions(to: CGSize(width: 19, height: 25))
        activityTypeImageView.autoPinEdge(toSuperviewEdge: .leading)
        activityTypeImageView.autoPinEdge(toSuperviewEdge: .trailing)
        activityTypeImageView.autoAlignAxis(toSuperviewAxis: .horizontal)

        activityTypeContainer.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .top)
        activityTypeContainer.autoPinEdge(.top, to: .bottom, of: locationContainer)
        activityTypeHeightConstraint = activityTypeContainer.autoSetDimension(.height, toSize: 25)
    }

    func setLocationText(_ text: String?) {
        locationLabel.text = text
        layoutLocationLabel()
    }

    func setLocationLabelFont(_ font: ADFont) {
        locationLabel.font = font.tertiaryFont
        layoutLocationLabel()
    }

    func showLocationLabel() {
        UIView.animate(withDuration: 0.2) {
            self.locationContainer.alpha = 1
        }
    }

    func toggleActivityType(on: Bool, animated: Bool) {
        activityTypeHeightConstraint.constant = on ? 25 : 0
        UIView.animate(withDuration: animated ? 0.3 : 0, delay: 0, options: [.curveEaseInOut], animations: {
            self.layoutIfNeeded()
            self.activityTypeImageView.alpha = on ? 1 : 0
        }, completion: nil)
    }

    func toggleLocation(on: Bool, animated: Bool) {
        UIView.animate(withDuration: animated ? 0.2 : 0) {
            self.locationContainer.alpha = on ? 1 : 0
        }
    }

    func setPalette(_ palette: Palette, animated: Bool) {
        activityTypeImageView.image = activityTypeImageView.image?.withRenderingMode(.alwaysTemplate)

        UIView.transition(with: self,
                          duration: animated ? 0.2 : 0,
                          options: [.transitionCrossDissolve],
                          animations: {
            self.locationLabel.textColor = palette.foregroundColor
            self.locationImageView.tintColor = palette.foregroundColor
            self.activityTypeImageView.tintColor = palette.foregroundColor

            if palette.backgroundColor == .black && palette.name != "Dark" {
                self.layer.shadowColor = UIColor.black.cgColor
                self.layer.shadowRadius = 7
                self.layer.shadowOpacity = 0.75
            } else {
                self.layer.shadowColor = UIColor.clear.cgColor
            }
        }, completion: nil)
    }

    private func layoutLocationLabel() {
        var transform = CGAffineTransform.identity
        let labelSize = CGSize(width: locationLabel.intrinsicContentSize.width + 12,
                               height: locationLabel.intrinsicContentSize.height)
        transform = transform.translatedBy(x: labelSize.width / 2, y: -labelSize.height / 2)
        transform = transform.rotated(by: .pi / 2)
        transform = transform.translatedBy(x: -labelSize.width / 2, y: labelSize.height / 2)
        locationContainer.transform = transform
    }
}
