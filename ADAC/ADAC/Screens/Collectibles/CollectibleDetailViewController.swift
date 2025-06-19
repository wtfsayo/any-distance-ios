// Licensed under the Any Distance Source-Available License
//
//  CollectibleDetailViewController.swift
//  ADAC
//
//  Created by Daniel Kuntz on 2/4/21.
//

import UIKit
import ScalingCarousel
import SwiftRichString

/// UIViewController that shows a 3D model and details about the given collectible, along with a share
/// button or AR button where appropriate.
final class CollectibleDetailViewController: VisualGeneratingViewController {

    // MARK: - Outlets

    @IBOutlet weak var infoButton: UIButton!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var carousel: ScalingCarouselView!
    @IBOutlet weak var pageControl: PillPageControl!
    @IBOutlet weak var badge: UIView!
    @IBOutlet weak var badgeImage: UIImageView!
    @IBOutlet weak var collectibleTypeLabel: UILabel!
    @IBOutlet weak var collectibleDescriptionLabel: UILabel!
    @IBOutlet weak var blurbLabel: UILabel!
    @IBOutlet weak var confettiView: ConfettiView!
    @IBOutlet weak var shareButton: ContinuousCornerButton!
    @IBOutlet weak var wearMedalButton: UIButton!
    @IBOutlet weak var ctaButton: ContinuousCornerButton!
    @IBOutlet weak var viewInARButton: UIButton!

    // MARK: - Variables

    var collectible: Collectible?
    var collectibleEarned: Bool = true
    var ctaUrlString: String?
    private var isShareCancelled: Bool = false

    weak var arAddToPostDelegate: CollectibleAddToPostDelegate?

    let screenName = "Collectible-Detail"

    var collectible3DView: Collectible3DView? {
        if let cell = carousel.cellForItem(at: IndexPath(item: 0, section: 0)) as? CollectibleCarouselCell {
            return cell.collectible3DView
        }
        return nil
    }

    var pageTimer: Timer?
    var curPage: Int = 0

    // MARK: - Setup

    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
        resetPageTimer()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        collectible3DView?.isPlaying = false
    }

    func resetPageTimer() {
        pageTimer?.invalidate()
        pageTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.incrementPage()
        }
    }

    @objc func incrementPage() {
        curPage = (curPage + 1) % carousel.numberOfItems(inSection: 0)
        carousel.scrollToItem(at: IndexPath(item: curPage, section: 0), at: .centeredHorizontally, animated: true)
    }

    func setup() {
        guard let collectible = collectible else {
            return
        }

//        collectibleEarned = true

        Analytics.logEvent(screenName, screenName, .screenViewed,
                           withParameters: ["collectible": collectible.type.rawValue])

        pageControl.pillWidth = 32
        pageControl.pillSpacing = 8
        pageControl.pillHeight = 4

        carousel.reloadData()
        carousel?.isPagingEnabled = true
        carousel.inset = 10

        confettiView.colors = collectible.type.confettiColors
        badge.layer.cornerCurve = .continuous

        switch collectible.type {
        case .special(let specialType):
            guard specialType.hasCtaButton else {
                break
            }

            ctaButton.isHidden = false
            ctaButton.setTitle(specialType.ctaLabelTitle, for: .normal)
            ctaButton.setTitleColor(specialType.ctaButtonLabelColor, for: .normal)
            ctaButton.backgroundColor = specialType.ctaButtonBackgroundColor
            ctaUrlString = specialType.ctaUrl?.absoluteString
        case .remote(let collectible):
            guard collectible.hasCtaButton else {
                break
            }

            ctaButton.isHidden = false
            ctaButton.setTitle(collectible.ctaLabelTitle, for: .normal)
            ctaButton.setTitleColor(collectible.ctaButtonLabelColor, for: .normal)
            ctaButton.backgroundColor = collectible.ctaButtonBackgroundColor
            ctaUrlString = collectible.ctaUrl?.absoluteString
        default: break
        }

        switch collectible.itemType {
        case .medal:
            viewInARButton.isHidden = true
        case .foundItem:
            wearMedalButton.isHidden = true
        }

        if collectibleEarned {
            setAttributedBlurbLabelText(collectible.type.blurb)
            badge.backgroundColor = collectible.itemType.backgroundColor
            badgeImage.image = collectible.itemType.badgeImage
            badgeImage.tintColor = collectible.itemType.badegeImageColor
        } else {
            setAttributedBlurbLabelText(collectible.type.hintBlurb)
            shareButton.isEnabled = false
            shareButton.alpha = 0.5
            ctaButton.isEnabled = false
            ctaButton.alpha = 0.5
            ctaButton.backgroundColor = .white
            ctaButton.setTitleColor(.black, for: .normal)
            viewInARButton.isHidden = true
            wearMedalButton.isHidden = true
            badge.backgroundColor = .adOrangeLighter
            badgeImage.image = UIImage(named: "glyph_lock_tiny")
        }

        infoButton.isHidden = true
        titleLabel.text = collectible.itemType.description
        collectibleTypeLabel.text = collectible.typeDescription
        collectibleDescriptionLabel.text = collectible.description.uppercased()
        pageControl.numberOfPages = collectionView(carousel, numberOfItemsInSection: 0)
        if collectionView(carousel, numberOfItemsInSection: 0) == 1 {
            pageControl.isHidden = true
        }

        if let subtitle = collectible.subtitle {
            subtitleLabel.isHidden = false
            subtitleLabel.text = subtitle
        }

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(appBecameActive),
                                               name: UIApplication.didBecomeActiveNotification,
                                               object: nil)
    }

    func setAttributedBlurbLabelText(_ string: String) {
        let normal = Style { $0.font = UIFont.systemFont(ofSize: 15) }
        let bold = Style { $0.font = UIFont.systemFont(ofSize: 15, weight: .bold) }
        let group = StyleXML(base: normal, ["b": bold])
        blurbLabel.attributedText = string.set(style: group)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if collectibleEarned {
            confettiView.startConfetti()
        }
        collectible3DView?.isPlaying = true
    }

    @objc func appBecameActive() {
    }

    override func cancelTapped() {
        super.cancelTapped()
        isShareCancelled = true
    }

    // MARK: - Actions

    @IBAction func infoTapped(_ sender: Any) {
        openUrl(withString: Links.adWebsite.absoluteString)
    }

    @IBAction func doneTapped(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }

    @IBAction func shareCollectibleTapped(_ sender: Any) {
        Analytics.logEvent("Share Tapped", screenName, .buttonTap,
                           withParameters: ["collectible": collectible?.type.rawValue ?? ""])

        setProgress(0, animated: false)
        isShareCancelled = false
        showActivityIndicator()

        pageTimer?.invalidate()
        curPage = 0
        carousel.scrollToItem(at: IndexPath(item: curPage, section: 0), at: .centeredHorizontally, animated: false)

        guard let collectible3DView = collectible3DView else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.shareCollectibleTapped(self)
            }
            return
        }

        Collectible3DShareVideoGenerator.renderVideos(forMedalView: collectible3DView) { [weak self] in
            return self?.isShareCancelled ?? true
        } progress: { [weak self] progress in
            self?.setProgress(progress, animated: true)
        } completion: { [weak self] videos in
            self?.hideActivityIndicator()
            if let vc = UIStoryboard(name: "Activities", bundle: nil).instantiateViewController(withIdentifier: "shareVC") as? ShareViewController {
                vc.videos = videos
                vc.title = "Share Collectible"
                self?.present(vc, animated: true, completion: nil)
            }
        }
    }
    
    @IBAction func ctaButtonTapped(_ sender: Any) {
        if let string = ctaUrlString, let collectible = collectible {
            Analytics.logEvent("CTA Button Tapped", screenName, .buttonTap,
                               withParameters: ["collectible": collectible.type.rawValue,
                                                "url" : string])
            openUrl(withString: string)
        }
    }

    @IBAction func arTapped(_ sender: Any) {
        if let collectible = collectible {
            if collectible.itemType == .medal {
                Analytics.logEvent("Wear Medal Tapped", screenName, .buttonTap)
                let arViewController = ARMedalViewController(collectible,
                                                             delegate: arAddToPostDelegate == nil ? nil : self)
                self.present(arViewController, animated: true, completion: nil)
            } else {
                Analytics.logEvent("View Collectible in AR Tapped", screenName, .buttonTap)
                let arViewController = ARCollectibleViewController(collectible,
                                                                   delegate: arAddToPostDelegate == nil ? nil : self)
                self.present(arViewController, animated: true, completion: nil)
            }
        }
    }
}

extension CollectibleDetailViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch collectible?.type {
        case .remote(let remote):
            return remote.carouselImageUrls.count + 1
        default:
            return 1
        }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let collectible = collectible else {
            return UICollectionViewCell()
        }

        if indexPath.item == 0,
           let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CollectibleCarouselCell.reuseId, for: indexPath) as? CollectibleCarouselCell {
            cell.setCollectible(collectible, earned: collectibleEarned)
            if self.collectionView(carousel, numberOfItemsInSection: 0) > 1 {
                cell.collectible3DView.isUserInteractionEnabled = false
            }
            return cell
        } else if indexPath.item > 0,
               let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ShareCarouselCell.reuseId, for: indexPath) as? ShareCarouselCell {
            switch collectible.type {
            case .remote(let remote):
                cell.setImage(withUrl: remote.carouselImageUrls[indexPath.item - 1])
            default: break
            }
            return cell
        }

        return UICollectionViewCell()
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard let carousel = carousel else {
            return
        }

        carousel.didScroll()

        let carouselItemWidth = view.frame.width - (carousel.inset * 2)
        let pageIdx = scrollView.contentOffset.x / carouselItemWidth
        pageControl.pageIdx = pageIdx
        curPage = Int(round(pageIdx))

        resetPageTimer()
    }
}

/// A carousel cell within CollectibleDetailViewController. Used to display supplementary images if
/// present in the collectible metadata.
class CollectibleCarouselCell: ScalingCarouselCell {

    // MARK: - Reuse ID

    static let reuseId = "collectibleCarouselCell"

    // MARK: - Outlets

    @IBOutlet weak var assetContainer: UIView!
    @IBOutlet weak var collectible3DView: Collectible3DView!
    @IBOutlet weak var videoView: LoopingVideoUIView!

    // MARK: - Setup

    func setCollectible(_ collectible: Collectible, earned: Bool) {
        switch collectible.type {
        case .remote(let remoteCollectible):
            if let videoUrl = remoteCollectible.videoUrl {
                self.videoView.alpha = 0
                self.collectible3DView.alpha = 0
                Task(priority: .userInitiated) {
                    if let localUrl = await CollectibleDataCache.loadItem(atUrl: videoUrl) {
                        DispatchQueue.main.async {
                            UIView.animate(withDuration: 0.2) {
                                self.videoView.alpha = 1
                            }
                            self.videoView.setVideoUrlAndPlay(url: localUrl)
                        }
                    }
                }
            } else {
                collectible3DView.setup(withCollectible: collectible,
                                        earned: earned,
                                        engraveInitials: earned)
            }
        default:
            collectible3DView.setup(withCollectible: collectible,
                                    earned: earned,
                                    engraveInitials: earned)
        }

        if !earned {
            collectible3DView.isUserInteractionEnabled = false
        }
    }
}

extension CollectibleDetailViewController: CollectibleAddToPostDelegate {
    func addPhotoToPost(_ image: UIImage, forCollectible collectible: Collectible) {
        presentingViewController?.dismiss(animated: true) {
            self.arAddToPostDelegate?.addPhotoToPost(image, forCollectible: collectible)
        }
    }

    func addVideoToPost(withUrl url: URL, forCollectible collectible: Collectible) {
        presentingViewController?.dismiss(animated: true) {
            self.arAddToPostDelegate?.addVideoToPost(withUrl: url, forCollectible: collectible)
        }
    }
}
