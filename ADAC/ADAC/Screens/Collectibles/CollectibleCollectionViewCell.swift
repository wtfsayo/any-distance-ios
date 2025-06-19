// Licensed under the Any Distance Source-Available License
//
//  CollectibleCollectionViewCell.swift
//  ADAC
//
//  Created by Daniel Kuntz on 5/31/22.
//

import UIKit

/// UICollectionViewCell for CollectiblesCollectionViewController. Contains an image view and video
/// view depending on the collectible asset type.
class CollectibleCollectionViewCell: UICollectionViewCell {
    static var reuseId: String {
        return "collectibleCell"
    }

    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var videoView: LoopingVideoUIView!
    @IBOutlet weak var countLabel: UILabel!
    @IBOutlet weak var countView: UIView!
    var grayLayer: CALayer?

    fileprivate var assetLoadTask: Task<(), Never>?
    private var assetType: AssetType = .image

    enum AssetType {
        case video
        case image
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.2) {
                self.alpha = self.isHighlighted ? 0.6 : 1
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.95, y: 0.95) : .identity
            }
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        imageView.layer.minificationFilter = .trilinear
        imageView.layer.minificationFilterBias = -1

        grayLayer = CALayer()
        grayLayer?.frame = imageView.bounds
        grayLayer?.compositingFilter = "colorBlendMode"
        grayLayer?.backgroundColor = UIColor.black.cgColor
        imageView.layer.addSublayer(grayLayer!)

        videoView.playerLayer?.videoGravity = .resizeAspect
    }

    func setAggregateCollectible(_ aggregateCollectible: AggregateCollectible) {
        let earned = aggregateCollectible.count > 0

        switch aggregateCollectible.collectible.type {
        case .remote(let collectible):
            if let videoUrl = collectible.previewVideoUrl ?? collectible.videoUrl {
                setVideo(withUrl: videoUrl)
            } else if let medalUrl = collectible.medalImageUrl {
                asyncSetImage(withUrl: medalUrl)
            }
        default:
            asyncSetImage(withUrl: aggregateCollectible.collectible.medalImageUrl)
        }

        countLabel.text = "\(aggregateCollectible.count)"
        countView.isHidden = aggregateCollectible.count <= 1

        if !earned {
            imageView.alpha = 0.25
            videoView.alpha = 0.6
            grayLayer?.isHidden = false
        } else {
            imageView.alpha = 1
            videoView.alpha = 1
            grayLayer?.isHidden = true
        }
    }

    func asyncSetImage(withUrl url: URL?) {
        assetType = .image
        videoView.clearVideo()
        videoView.isHidden = true
        imageView.isHidden = false
        assetLoadTask?.cancel()

        imageView.sd_setImageWithFade(url: url,
                                      placeholderImage: UIImage(named: "medal_placeholder"),
                                      options: [.retryFailed],
                                      completion: nil)
    }

    func setVideo(withUrl url: URL) {
        assetType = .video
        imageView.isHidden = true
        videoView.isHidden = false

        if videoView.videoUrl == url {
            return
        }

        assetLoadTask?.cancel()
        assetLoadTask = Task(priority: .userInitiated) {
            let localUrl = await CollectibleDataCache.loadItem(atUrl: url)
            if let localUrl = localUrl, !Task.isCancelled, self.assetType == .video {
                DispatchQueue.main.async {
                    self.videoView.setVideoUrlAndPlay(url: localUrl)
                }
            }
        }
    }
}

/// UICollectionViewCell that contains a Collectible3DView for found items.
final class Collectible3DCollectionViewCell: UICollectionViewCell {
    static var reuseId: String {
        return "collectible3DCell"
    }

    @IBOutlet weak var scnView: Collectible3DView!
    @IBOutlet weak var countLabel: UILabel!
    @IBOutlet weak var countView: UIView!

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.2) {
                self.alpha = self.isHighlighted ? 0.6 : 1
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.95, y: 0.95) : .identity
            }
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        scnView.isUserInteractionEnabled = false
        scnView.backgroundColor = .clear
    }

    func setAggregateCollectible(_ aggregateCollectible: AggregateCollectible) {
        let earned = aggregateCollectible.count > 0
        scnView.setupForReusableView(withCollectible: aggregateCollectible.collectible, earned: earned)
        countLabel.text = "\(aggregateCollectible.count)"
        countView.isHidden = aggregateCollectible.count <= 1
    }
}
