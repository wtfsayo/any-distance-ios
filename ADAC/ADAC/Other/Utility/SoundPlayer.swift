// Licensed under the Any Distance Source-Available License
//
//  SoundPlayer.swift
//  ADAC
//
//  Created by Daniel Kuntz on 9/14/22.
//

import Foundation
import AVFoundation

class SoundPlayer: NSObject {
    static let shared = SoundPlayer()

    private var players: [AVAudioPlayer] = []

    func playRandomAndiStart() {
        playSound(withName: "andi-start-\(Int.random(in: 1...3))")
    }

    func playAndiCountdown(with step: Int) {
        playSound(withName: "andi-\(step)")
    }

    func playRandomAndiGo() {
        playSound(withName: "andi-go-\(Int.random(in: 1...3))")
    }

    private func playSound(withName name: String) {
        if let player = try? AVAudioPlayer(contentsOf: Bundle.main.url(forResource: name,
                                                                       withExtension: "mp3")!) {
            player.delegate = self
            players.append(player)
            player.play()
        }
    }
}

extension SoundPlayer: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        players.removeAll(where: { $0 === player })
    }
}
