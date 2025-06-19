// Licensed under the Any Distance Source-Available License
//
//  LaunchViewController.swift
//  ADAC
//
//  Created by Daniel Kuntz on 11/14/22.
//

import UIKit
import PureLayout
import AVFoundation

/// UIViewController that plays the launch video with tap to skip
class LaunchViewController: UIViewController {

    // MARK: - Variables

    private var videoView: UIView?
    private var player: AVPlayer?
    private(set) var item: AVPlayerItem?
    private(set) var playerLayer: AVPlayerLayer?

    // MARK: - Constants

    let videoUrl = Bundle.main.url(forResource: "launch", withExtension: "mp4")!

    // MARK: - Setup

    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            self.animateDismiss()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        playerLayer?.frame = videoView?.bounds ?? .zero
    }

    func setup() {
        let asset = AVAsset(url: videoUrl)
        item = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: item)

        playerLayer = AVPlayerLayer(player: player)
        playerLayer?.videoGravity = .resizeAspectFill
        playerLayer?.frame = view.window?.windowScene?.screen.bounds ?? .zero

        videoView = UIView()
        videoView?.backgroundColor = .black
        view.addSubview(videoView!)
        videoView?.autoPinEdgesToSuperviewEdges()
        videoView?.layer.addSublayer(playerLayer!)

        player?.isMuted = true
        player?.play()

        let tapGR = UITapGestureRecognizer(target: self, action: #selector(animateDismiss))
        view.addGestureRecognizer(tapGR)
    }

    @objc private func animateDismiss() {
        UIView.animate(withDuration: 0.2) {
            self.view.alpha = 0.0
        } completion: { _ in
            self.dismiss(animated: false)
        }
    }
}

extension UIViewController {
    func showLaunchSequence() {
        let launchVC = LaunchViewController()
        launchVC.modalPresentationStyle = .overFullScreen
        present(launchVC, animated: false)
    }
}
