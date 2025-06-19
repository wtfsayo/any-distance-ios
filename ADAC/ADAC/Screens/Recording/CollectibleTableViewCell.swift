// Licensed under the Any Distance Source-Available License
//
//  CollectibleTableViewCell.swift
//  ADAC
//
//  Created by Daniel Kuntz on 5/20/22.
//

import UIKit
import ScalingCarousel

protocol CollectibleTableViewCellDelegate: AnyObject {
    func didSelectCollectible(_ collectible: Collectible)
}

class CollectibleTableViewCell: UITableViewCell {

    // MARK: - Reuse ID

    static let reuseId: String = "collectibleCell"

    // MARK: - Outlets

    @IBOutlet weak var carousel: ScalingCarouselView!
    @IBOutlet weak var pageControl: PillPageControl!

    // MARK: - Variables

    private(set) var collectibles: [Collectible] = []
    private var collectiblesWereEarned: Bool = true
    private let inset: CGFloat = 15
    weak var delegate: CollectibleTableViewCellDelegate?

    // MARK: - Setup

    override func awakeFromNib() {
        super.awakeFromNib()
        pageControl.pillWidth = 32
        pageControl.pillSpacing = 8
        pageControl.pillHeight = 4
        carousel.register(UINib(nibName: "ActivitiesCollectibleCarouselCell", bundle: nil),
                          forCellWithReuseIdentifier: ActivitiesCollectibleCarouselCell.reuseId)
        carousel.allowsSelection = true
    }

    override func prepareForReuse() {
        for cell in carousel.visibleCells {
            cell.prepareForReuse()
        }
    }

    func setCollectibles(_ collectibles: [Collectible], earned: Bool = true) {
        self.collectibles = collectibles.sorted(by: { $0.itemType.sortOrder < $1.itemType.sortOrder })
        self.collectiblesWereEarned = earned
        pageControl.numberOfPages = collectibles.count
        pageControl.isHidden = collectibles.count == 1
        pageControl.pageIdx = 0
        carousel.inset = collectibles.count == 1 ? inset : inset * 2
        carousel.reloadData()

        if collectibles.count > 1 {
            carousel.contentOffset.x = inset
        }
    }
}

extension CollectibleTableViewCell: UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        return collectibles.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ActivitiesCollectibleCarouselCell.reuseId,
                                                         for: indexPath) as? ActivitiesCollectibleCarouselCell {
            cell.setCollectible(collectibles[indexPath.item], earned: collectiblesWereEarned)
            cell.setNeedsLayout()
            cell.layoutIfNeeded()
            return cell
        }

        return UICollectionViewCell()
    }

    func collectionView(_ collectionView: UICollectionView, didHighlightItemAt indexPath: IndexPath) {
        let cell = collectionView.cellForItem(at: indexPath)
        UIView.animate(withDuration: 0.2) {
            cell?.alpha = 0.6
            cell?.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }
    }

    func collectionView(_ collectionView: UICollectionView, didUnhighlightItemAt indexPath: IndexPath) {
        let cell = collectionView.cellForItem(at: indexPath)
        UIView.animate(withDuration: 0.2) {
            cell?.alpha = 1
            cell?.transform = .identity
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView.contentSize.width > (scrollView.bounds.width + inset) && collectibles.count > 1 else {
            return
        }

        let range = inset...(scrollView.contentSize.width - scrollView.bounds.width - inset)
        let curOffset = scrollView.contentOffset.x
        scrollView.contentOffset.x = curOffset.clamped(to: range)

        let pageIdx = CGFloat(collectibles.count - 1) * (scrollView.contentOffset.x - range.lowerBound) / (range.upperBound - range.lowerBound)
        pageControl.pageIdx = pageIdx
    }
}
