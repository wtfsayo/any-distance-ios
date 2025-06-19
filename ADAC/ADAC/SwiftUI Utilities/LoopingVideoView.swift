// Licensed under the Any Distance Source-Available License
//
//  LoopingVideoView.swift
//  ADAC
//
//  Created by Daniel Kuntz on 12/14/21.
//

import UIKit
import PureLayout
import SwiftUI
import AVFoundation

struct LoopingVideoView: UIViewRepresentable {
    let videoUrl: URL?
    var isPlaying: Bool = true
    var videoGravity: AVLayerVideoGravity = .resizeAspectFill

    func makeUIView(context: Context) -> UIView {
        let view = LoopingVideoUIView(videoUrl: videoUrl)
        view.videoGravity = videoGravity
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if isPlaying {
            (uiView as? LoopingVideoUIView)?.queuePlayer?.play()
        } else {
            (uiView as? LoopingVideoUIView)?.queuePlayer?.pause()
        }
    }
}

final class LoopingVideoUIView: UIView {
    var videoGravity: AVLayerVideoGravity = .resizeAspectFill
    private var videoView: UIView?
    private var player: AVPlayerLooper?
    private var observerToken: Any?
    private(set) var queuePlayer: AVQueuePlayer?
    private(set) var item: AVPlayerItem?
    private(set) var playerLayer: AVPlayerLayer?

    var videoUrl: URL? {
        didSet {
            setupVideo()
        }
    }

    init(videoUrl: URL?) {
        self.videoUrl = videoUrl
        super.init(frame: .zero)
    }

    func setVideoUrlAndPlay(url: URL) {
        self.videoUrl = url
        setupVideo()
    }

    func clearVideo() {
        videoView?.removeFromSuperview()
        queuePlayer?.pause()
        videoUrl = nil
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func willMove(toSuperview newSuperview: UIView?) {
        setupVideo()
    }

    private func setupVideo() {
        guard let videoUrl = videoUrl else {
            return
        }

        let asset = AVAsset(url: videoUrl)
        item = AVPlayerItem(asset: asset)

        if let token = observerToken {
            queuePlayer?.removeTimeObserver(token)
            observerToken = nil
        }

        queuePlayer = AVQueuePlayer(playerItem: item!)
        player = AVPlayerLooper(player: queuePlayer!, templateItem: item!)

        let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))

        // Keep the reference to remove
        self.observerToken = queuePlayer?.addPeriodicTimeObserver(forInterval: interval,
                                                                  queue: DispatchQueue.main) { [weak self] time in
            guard let self = self else {
                return
            }
            
            if self.videoView?.alpha == 0.0 {
                UIView.animate(withDuration: 0.3, delay: 0.7) {
                    self.videoView?.alpha = 1.0
                }
            }
        }

        playerLayer = AVPlayerLayer(player: queuePlayer)
        playerLayer?.videoGravity = videoGravity
        playerLayer?.frame = superview?.bounds ?? .zero

        videoView?.removeFromSuperview()
        videoView = UIView()
        videoView?.alpha = 0.0
        addSubview(videoView!)
        videoView?.autoPinEdgesToSuperviewEdges()
        videoView?.layer.addSublayer(playerLayer!)

        queuePlayer?.isMuted = true
        queuePlayer?.play()

        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification,
                                               object: nil,
                                               queue: .main) { [weak self] _ in
            self?.queuePlayer?.play()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let roundedBounds = CGRect(x: 0, y: 0, width: self.bounds.width.rounded(), height: self.bounds.height.rounded())
        if playerLayer?.frame != roundedBounds {
            playerLayer?.frame = roundedBounds
        }
    }
}
