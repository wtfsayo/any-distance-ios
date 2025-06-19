// Licensed under the Any Distance Source-Available License
//
//  WearableMedalARView.swift
//  ADAC
//
//  Created by Daniel Kuntz on 12/12/22.
//

import ARKit
import SceneKit
import Vision

enum MedalARViewMode {
    case place
    case wear

    var displayName: String {
        switch self {
        case .place:
            return "Place"
        case .wear:
            return "Wear"
        }
    }
}

final class WearableMedalARView: CollectibleARSCNView {
    private var wearableMedalContainerNode: SCNNode?
    private var wearableMedalNode: SCNNode?
    private var occlusionNode: SCNNode?
    private var hasLoadedWearableMedal: Bool = false

    var mode: MedalARViewMode = .wear {
        didSet {
            switch mode {
            case .wear:
                loadWearableMedal()
                itemNode?.opacity = 0
                wearableMedalNode?.opacity = 1
            case .place:
                itemNode?.opacity = 1
                wearableMedalNode?.opacity = 0
            }

            self.session.run(self.worldTrackingConfiguration(),
                             options: [.resetTracking, .removeExistingAnchors])
        }
    }

    override func worldTrackingConfiguration() -> ARConfiguration {
        switch mode {
        case .wear:
            let config = ARFaceTrackingConfiguration()
            config.maximumNumberOfTrackedFaces = 1
            config.isLightEstimationEnabled = true
            return config
        case .place:
            return super.worldTrackingConfiguration()
        }
    }

    override func viewPanned(_ recognizer: UIPanGestureRecognizer) {
        switch self.mode {
        case .wear:
            break
        case .place:
            super.viewPanned(recognizer)
        }
    }

    override func viewPinched(_ recognizer: UIPinchGestureRecognizer) {
        switch self.mode {
        case .wear:
            break
        case .place:
            super.viewPinched(recognizer)
        }
    }

    override func viewRotated(_ recognizer: UIRotationGestureRecognizer) {
        switch self.mode {
        case .wear:
            break
        case .place:
            super.viewRotated(recognizer)
        }
    }

    override func initialSceneLoaded() {
        mode = .wear
    }

    private func loadWearableMedal() {
        guard wearableMedalNode == nil else {
            return
        }

        if let medalUsdzUrl = Bundle.main.url(forResource: "medal-wearable", withExtension: "usdz") {
            Task {
                if let scene = await SceneLoader.loadScene(atUrl: medalUsdzUrl) {
                    DispatchQueue.main.async {
                        self.addWearableMedal(scene)
                    }
                }
            }
        }
    }

    private func addWearableMedal(_ loadedScene: SCNScene) {
        #if targetEnvironment(simulator)
        return
        #endif

        guard let collectible = self.collectible,
              wearableMedalNode == nil else {
            return
        }

        autoenablesDefaultLighting = true
        antialiasingMode = .multisampling4X
        wearableMedalNode = loadedScene.rootNode.childNode(withName: "medal", recursively: true)
        wearableMedalContainerNode = SCNNode()
        scene.rootNode.addChildNode(wearableMedalContainerNode!)
        wearableMedalContainerNode?.addChildNode(wearableMedalNode!)

        Task {
            let diffuseTexture = await generateDiffuseTexture(for: collectible)
            let metalnessTexture = await generateMetalnessTexture(for: collectible)

            DispatchQueue.main.async {
                var roughnessTexture = self.exposureAdjustedImage(diffuseTexture)
                if collectible.medalImageHasBlackBackground {
                    let roughnessCIImage = CIImage(cgImage: diffuseTexture.cgImage!)
                    let invertedRoughness = roughnessCIImage
                        .applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: 4])
                        .applyingFilter("CIColorInvert")
                    roughnessTexture = UIImage(ciImage: invertedRoughness).resized(withNewWidth: 1024, imageScale: 1)
                }

                self.wearableMedalNode?.geometry?.materials.first?.diffuse.contents = diffuseTexture
                self.wearableMedalNode?.geometry?.materials.first?.roughness.contents = roughnessTexture
                self.wearableMedalNode?.geometry?.materials.first?.metalness.contents = metalnessTexture
                self.wearableMedalNode?.geometry?.materials.first?.metalness.intensity = 1
                self.wearableMedalNode?.geometry?.materials.first?.emission.contents = diffuseTexture
                self.wearableMedalNode?.geometry?.materials.first?.emission.intensity = 0.15
                self.wearableMedalNode?.geometry?.materials.first?.selfIllumination.contents = diffuseTexture

                let normalTexture = CIImage(cgImage: roughnessTexture.cgImage!).applyingFilter("NormalMap")
                let normalImage = UIImage(ciImage: normalTexture).resized(withNewWidth: 1024, imageScale: 1)
                self.wearableMedalNode?.geometry?.materials.first?.normal.contents = normalImage
            }
        }

        wearableMedalNode?.eulerAngles = SCNVector3(x: .pi / 2, y: 0, z: 0)
        wearableMedalNode?.scale = SCNVector3(0.006, 0.006, 0.006)

        hasLoadedWearableMedal = true
    }

    private func generateDiffuseTexture(for collectible: Collectible) async -> UIImage {
        let medalImage = await collectible.medalImage
        let borderColor = await collectible.medalBorderColor

        let options = UIGraphicsImageRendererFormat()
        options.opaque = true
        options.scale = 1
        let size = CGSize(width: 1024, height: 1024)
        let renderer = UIGraphicsImageRenderer(size: size, format: options)

        return renderer.image { ctx in
            borderColor?.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            let medalImgSize = CGSize(width: 559, height: 830)
            medalImage?.draw(in: CGRect(origin: CGPoint(x: 455, y: 6), size: medalImgSize))

            if let borderColor = borderColor {
                let borderFrame = CGRect(x: 0, y: 897, width: 1024, height: 132)
                borderColor.setFill()
                ctx.fill(borderFrame)
            }
        }
    }

    private func generateMetalnessTexture(for collectible: Collectible) async -> UIImage {
        let medalImage = await collectible.medalImage
        let borderColor = await collectible.medalBorderColor

        let options = UIGraphicsImageRendererFormat()
        options.opaque = false
        options.scale = 1
        let size = CGSize(width: 1024, height: 1024)
        let renderer = UIGraphicsImageRenderer(size: size, format: options)

        return renderer.image { ctx in
            UIColor.black.setFill()
            let borderFrame = CGRect(x: 0, y: 796, width: 1024, height: 228)
            ctx.fill(borderFrame)
            UIImage(named: "wearable-medal-band")?.draw(in: borderFrame)

            borderColor?.setFill()
            ctx.fill(CGRect(origin: .zero, size: CGSize(width: 1024, height: 796)))

            let medalImgSize = CGSize(width: 559, height: 830)
            medalImage?.draw(in: CGRect(origin: CGPoint(x: 455, y: 6), size: medalImgSize))
        }
    }

    private func updateWearableMedalNodePosition(for faceAnchor: ARFaceAnchor, node: SCNNode) {
        if let wearableMedalContainerNode = self.wearableMedalContainerNode,
           wearableMedalContainerNode.parent != scene.rootNode {
            wearableMedalContainerNode.removeFromParentNode()
            scene.rootNode.addChildNode(wearableMedalContainerNode)
        }

        let facePos = SCNVector3.positionFrom(matrix: faceAnchor.transform)
        wearableMedalNode?.position = SCNVector3(x: facePos.x,
                                                 y: facePos.y-0.2,
                                                 z: facePos.z)
        wearableMedalNode?.eulerAngles.y = node.eulerAngles.y
    }
}

extension WearableMedalARView {
    override func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard mode == .wear, hasLoadedWearableMedal else {
            super.renderer(renderer, didAdd: node, for: anchor)
            return
        }

        guard let faceAnchor = anchor as? ARFaceAnchor else {
            return
        }

        hasPlaced = true
        updateWearableMedalNodePosition(for: faceAnchor, node: node)
        wearableMedalNode?.opacity = 1

        generator.impactOccurred()
        coachingOverlay.setActive(false, animated: true)
    }

    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard mode == .wear,
              hasLoadedWearableMedal,
              let faceAnchor = anchor as? ARFaceAnchor else {
            return
        }

        updateWearableMedalNodePosition(for: faceAnchor, node: node)
    }

    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        guard let sceneView = renderer as? ARSCNView,
              anchor is ARFaceAnchor else { return nil }

        let faceGeometry = ARSCNFaceGeometry(device: sceneView.device!)!

        faceGeometry.firstMaterial!.colorBufferWriteMask = []
        occlusionNode = SCNNode(geometry: faceGeometry)
        occlusionNode?.renderingOrder = -1
        return occlusionNode
    }
}
