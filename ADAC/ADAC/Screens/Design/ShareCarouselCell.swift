// Licensed under the Any Distance Source-Available License
//
//  ShareCarouselCell.swift
//  ADAC
//
//  Created by Daniel Kuntz on 12/31/20.
//

import UIKit
import AVFoundation
import ScalingCarousel
import Combine

/// ScalingCarouselCell subclass for a carousel cell in ShareViewController. Contains an image view and video
/// view that can load from either a local asset or URL
final class ShareCarouselCell: ScalingCarouselCell {

    // MARK: - Reuse ID

    static let reuseId = "carouselCell"

    // MARK: - Outlets

    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var videoView: UIView!
    @IBOutlet weak var progressView: UIProgressView?

    // MARK: - Variables

    private var player: AVPlayerLooper?
    private var queuePlayer: AVQueuePlayer?
    private(set) var playerLayer: AVPlayerLayer?
    private var subscribers: Set<AnyCancellable> = []

    // MARK: - Setup

    override func awakeFromNib() {
        super.awakeFromNib()
        
        progressView?.tintColor = UIColor.adOrangeLighter

        backgroundColor = .clear
        contentView.backgroundColor = .clear
        imageView.layer.minificationFilter = .trilinear
        imageView.layer.minificationFilterBias = 0.05
        imageView.layer.cornerRadius = 16
        imageView.layer.cornerCurve = .continuous

        videoView.layer.cornerRadius = 16
        videoView.layer.cornerCurve = .continuous

        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification).sink { [weak self] _ in
            self?.queuePlayer?.play()
        }.store(in: &subscribers)
    }

    func setImage(withUrl url: URL) {
        imageView.contentMode = .scaleAspectFill
        imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor,
                                          multiplier: 1).isActive = true
        imageView.sd_setImageWithFade(url: url, options: []) { image in
            self.setNeedsLayout()
            self.layoutIfNeeded()
        }
    }

    func setImage(_ image: UIImage?) {
        imageView.image = image
        var imageRatio = (imageView.image?.size.height ?? 1) / (imageView.image?.size.width ?? 1)
        if imageRatio.isNaN {
            imageRatio = 1
        }
        imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor,
                                          multiplier: imageRatio).isActive = true
        mainView.layer.masksToBounds = true
        setNeedsLayout()
        layoutIfNeeded()
    }

    func setVideo(withUrl url: URL?, play: Bool = true) {
        guard let url = url else {
            return
        }

        playerLayer?.removeFromSuperlayer()
        queuePlayer?.pause()

        let asset = AVAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        queuePlayer = AVQueuePlayer(playerItem: playerItem)
        player = AVPlayerLooper(player: queuePlayer!, templateItem: playerItem)

        playerLayer = AVPlayerLayer(player: queuePlayer)
        playerLayer?.frame = videoView.bounds
        playerLayer?.videoGravity = .resizeAspect
        videoView.layer.addSublayer(playerLayer!)
        videoView.layer.masksToBounds = true

        let size = asset.tracks(withMediaType: .video).first?.naturalSize
        let videoRatio = (size?.height ?? 1) / (size?.width ?? 1)
        if !videoRatio.isNaN {
            videoView.heightAnchor.constraint(equalTo: videoView.widthAnchor,
                                              multiplier: videoRatio).isActive = true
        }

        queuePlayer?.volume = 0
        if play {
            queuePlayer?.play()
        }

        setNeedsLayout()
        layoutIfNeeded()
    }

    func rewindAndPlay() {
        queuePlayer?.seek(to: .zero)
        queuePlayer?.play()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = videoView.bounds
    }
}
