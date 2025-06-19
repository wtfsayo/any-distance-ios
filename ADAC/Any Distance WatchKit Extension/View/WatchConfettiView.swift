// Licensed under the Any Distance Source-Available License
//
//  WatchConfettiView.swift
//  Any Distance WatchKit Extension
//
//  Created by Daniel Kuntz on 11/2/22.
//

import WatchKit
import SpriteKit
import SwiftUI

struct WatchConfettiViewRepresentable: WKInterfaceObjectRepresentable {
    typealias WKInterfaceObjectType = WatchConfettiView
    var isPlaying: Bool

    func makeWKInterfaceObject(context: Context) -> WatchConfettiView {
        return WatchConfettiView()
    }

    func updateWKInterfaceObject(_ wkInterfaceObject: WatchConfettiView, context: Context) {
        wkInterfaceObject.buildScene()
        isPlaying ? wkInterfaceObject.startConfetti() : wkInterfaceObject.stopConfetti()
    }
}

class WatchConfettiView: WKInterfaceSKScene {
    private var emitterNode = SKEmitterNode(fileNamed: "confetti.sks")
    private var hasSceneBeenBuilt: Bool = false
    private var isPlaying: Bool = false

    func buildScene() {
        guard !hasSceneBeenBuilt else {
            return
        }
        hasSceneBeenBuilt = true

        let scene = SKScene()
        scene.size = WKInterfaceDevice.current().screenBounds.size
        scene.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        scene.backgroundColor = .clear

        if let emitterNode = emitterNode {
            emitterNode.particleColor = .adOrangeLighter
            emitterNode.position = CGPoint(x: 0, y: scene.size.height * 0.5)
            emitterNode.particleBirthRate = 0.0
            emitterNode.name = "confetti"

            // Send the particles to the scene.
            emitterNode.targetNode = scene
            scene.addChild(emitterNode)
        }
        self.isPaused = false
        self.presentScene(scene)
        emitterNode?.particleBirthRate = 0.0
    }

    func startConfetti() {
        guard !isPlaying else {
            return
        }
        isPlaying = true

        emitterNode?.particleBirthRate = 200
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.emitterNode?.particleBirthRate = 30
        }
    }

    func stopConfetti() {
        isPlaying = false
        emitterNode?.particleBirthRate = 0.0
    }
}
