// Licensed under the Any Distance Source-Available License
//
//  AVPlayer+RepeatMode.swift
//  ADAC
//
//  Created by Daniel Kuntz on 3/20/21.
//

import Foundation
import AVFoundation

private final class RepeatManager: NSObject {
    weak var player: AVPlayer?

    var mode: AVPlayer.RepeatMode = .None

    init(player: AVPlayer) {
        self.player = player

        super.init()

        startObservingCurrentItem(of: player)
        if let playerItem = player.currentItem {
            startObservingNotifications(of: playerItem)
        }
    }

    deinit {
        guard let player = player else {
            return
        }

        stopObservingCurrentItem(of: player)
        if let playerItem = player.currentItem {
            stopObservingNotifications(of: playerItem)
        }
    }

    func startObservingCurrentItem(of player: AVPlayer) {
        player.addObserver(self, forKeyPath: "currentItem", options: [.old, .new], context: nil)
    }

    func stopObservingCurrentItem(of player: AVPlayer) {
        player.removeObserver(self, forKeyPath: "currentItem")
    }

    func startObservingNotifications(of playerItem: AVPlayerItem) {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(RepeatManager.observe(AVPlayerItemDidPlayToEndTimeNotification:)),
                                               name: NSNotification.Name.AVPlayerItemDidPlayToEndTime,
                                               object: playerItem)
    }

    func stopObservingNotifications(of playerItem: AVPlayerItem) {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: playerItem)
    }

    @objc func observe(AVPlayerItemDidPlayToEndTimeNotification notification: NSNotification) {
        guard let player = player,
              let currentItem = player.currentItem,
              currentItem == (notification.object as? AVPlayerItem) else {
            return
        }

        switch (mode, player) {
        case (.All, let queuePlayer as AVQueuePlayer):
            queuePlayer.advanceToNextItem()
            currentItem.seek(to: .zero, completionHandler: nil)
            queuePlayer.insert(currentItem, after: nil)
        case (.One, _), (.All, _):
            currentItem.seek(to: .zero, completionHandler: nil)
        default:
            break
        }
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if (object as? AVPlayer) == player && keyPath == "currentItem" {
            if let oldItem = change?[NSKeyValueChangeKey.oldKey] as? AVPlayerItem {
                stopObservingNotifications(of: oldItem)
            }
            if let newItem = change?[NSKeyValueChangeKey.newKey] as? AVPlayerItem {
                startObservingNotifications(of: newItem)
            }
        }
    }
}

public extension AVPlayer {
    private struct CustomProperties {
        static var repeatManager: RepeatManager? = nil
    }

    private var repeatManager: RepeatManager? {
        get {
            return objc_getAssociatedObject(self, &CustomProperties.repeatManager) as? RepeatManager
        }
        set(value) {
            objc_setAssociatedObject(self, &CustomProperties.repeatManager, value, .OBJC_ASSOCIATION_RETAIN)
        }
    }

    enum RepeatMode {
        case None
        case One
        case All // for AVQueuePlayer
    }

    var repeatMode: RepeatMode {
        get {
            return repeatManager?.mode ?? .None
        }

        set(mode) {
            if repeatManager == nil {
                repeatManager = RepeatManager(player: self)
            }
            repeatManager?.mode = mode

            if mode == .One || mode == .All {
                actionAtItemEnd = .none
            } else {
                actionAtItemEnd = .advance
            }
        }
    }
}
