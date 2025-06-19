// Licensed under the Any Distance Source-Available License
//
//  CollectibleCollectionViewCell.swift
//  ADAC
//
//  Created by Daniel Kuntz on 5/20/22.
//

import UIKit
import ScalingCarousel

class ActivitiesCollectibleCarouselCell: ScalingCarouselCell {

    // MARK: - Reuse ID

    static let reuseId: String = "activitiesCollectibleCarouselCell"

    // MARK: - Outlets

    @IBOutlet weak var mediaContainer: UIView!
    @IBOutlet weak var collectible3dView: Collectible3DView!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var confettiView: ConfettiView!

    @IBOutlet weak var collectibleDataContainer: UIView!
    @IBOutlet weak var topSubtitleLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var bottomSubtitleLabel: UILabel!
    @IBOutlet weak var wearMedalButton: UIButton!

    @IBOutlet weak var rewardDataContainer: UIView!
    @IBOutlet weak var rewardLockIcon: UIImageView!
    @IBOutlet weak var rewardLockLabel: UILabel!
    @IBOutlet weak var rewardTitleLabel: UILabel!
    @IBOutlet weak var rewardInviteLabel: UILabel!
    @IBOutlet weak var rewardProgressView: RewardProgressIndicator!
    @IBOutlet weak var rewardRedeemButton: UIButton!

    // MARK: - Variables

    private var collectible: Collectible?

    // MARK: - Setup

    override func awakeFromNib() {
        super.awakeFromNib()

        wearMedalButton.layer.cornerCurve = .continuous
        wearMedalButton.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMinYCorner]
        rewardRedeemButton.layer.cornerCurve = .continuous
        rewardRedeemButton.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMinYCorner]
        mainView.layer.cornerCurve = .continuous
        mainView.layer.masksToBounds = true

        imageView.layer.minificationFilter = .trilinear
        imageView.layer.minificationFilterBias = 0.05

        confettiView.layer.cornerRadius = 13
        confettiView.layer.masksToBounds = true
        confettiView.layer.cornerCurve = .continuous
    }

    override func prepareForReuse() {
        self.collectible = nil
    }

    func setCollectible(_ collectible: Collectible, earned: Bool = true) {
        guard collectible != self.collectible else {
            return
        }

        self.collectible = collectible

        confettiView.stopConfetti()
        confettiView.colors = collectible.type.confettiColors
        confettiView.style = .small
        confettiView.startConfetti(beginAtTimeZero: false)

        self.imageView.sd_cancelCurrentImageLoad()

        switch collectible.itemType {
        case .medal:
            self.imageView.isHidden = false
            self.imageView.sd_setImageWithFade(url: collectible.medalImageUrl,
                                               placeholderImage: UIImage(named: "medal_placeholder"),
                                               options: [.retryFailed])
            self.collectible3dView.isHidden = true
            self.collectible3dView.cleanup()
            self.wearMedalButton.isHidden = !earned
        case .foundItem:
            self.imageView.isHidden = true
            self.collectible3dView.isHidden = false
            self.collectible3dView.setupForReusableView(withCollectible: collectible)
            self.wearMedalButton.isHidden = true
        }

        collectibleDataContainer.isHidden = false
        rewardDataContainer.isHidden = true
        topSubtitleLabel.text = collectible.itemType.description
        titleLabel.text = collectible.description
        confettiView.isHidden = false
        mediaContainer.alpha = 1.0

        switch collectible.type {
        case .remote(let remote):
            bottomSubtitleLabel.text = remote.subtitle
        default:
            bottomSubtitleLabel.text = nil
        }
    }

    @IBAction func wearMedalTapped(_ sender: Any) {}
}
