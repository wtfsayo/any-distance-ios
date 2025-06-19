// Licensed under the Any Distance Source-Available License
//
//  GestureARView.swift
//  ADAC
//
//  Created by Daniel Kuntz on 2/22/22.
//

import ARKit
import PureLayout

class GestureARView: ARSCNView, ADARView {
    private(set) var coachingOverlay = ARCoachingOverlayView(frame: .zero)
    private var panStartPoint: CGPoint = .zero
    private var moveStartPoint: SCNVector3?
    private var nodeStartPoint: SCNVector3?
    private var startScale: Float = 0
    private var startRotation: Float = 0
    private var prevAnchor: ARAnchor?

    var generator: UIImpactFeedbackGenerator = UIImpactFeedbackGenerator(style: .light)
    var hasPlaced: Bool = false

    private var panGR: UIPanGestureRecognizer!
    private var pinchGR: UIPinchGestureRecognizer!
    private var rotationGR: UIRotationGestureRecognizer!

    var nodeToMove: SCNNode? {
        return nil
    }

    var distanceToGround: Float {
        return 0.1
    }

    var shadowImageScale: CGFloat {
        return 1
    }

    func worldTrackingConfiguration() -> ARConfiguration {
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        config.environmentTexturing = .automatic
        return config
    }

    override func willMove(toSuperview newSuperview: UIView?) {
        super.willMove(toSuperview: newSuperview)

        guard newSuperview != nil else {
            return
        }

        panGR = UIPanGestureRecognizer(target: self, action: #selector(viewPanned(_:)))
        panGR.delegate = self
        addGestureRecognizer(panGR)

        pinchGR = UIPinchGestureRecognizer(target: self, action: #selector(viewPinched(_:)))
        pinchGR.delegate = self
        addGestureRecognizer(pinchGR)

        rotationGR = UIRotationGestureRecognizer(target: self, action: #selector(viewRotated(_:)))
        rotationGR.delegate = self
        addGestureRecognizer(rotationGR)

        addSubview(coachingOverlay)
        coachingOverlay.autoPinEdgesToSuperviewEdges()
        coachingOverlay.goal = .horizontalPlane
        coachingOverlay.activatesAutomatically = true
        coachingOverlay.session = session

        pointOfView?.camera?.motionBlurIntensity = 0
        pointOfView?.camera?.wantsHDR = false

        if let transform = nodeToMove?.simdWorldTransform {
            let anchor = ARAnchor(transform: transform)
            session.add(anchor: anchor)
        }

        delegate = self
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        coachingOverlay.setActive(true, animated: false)
    }

    func reset() {
        panStartPoint = .zero
        moveStartPoint = nil
        nodeStartPoint = nil
        startScale = 0
        startRotation = 0
        prevAnchor = nil
        hasPlaced = false
    }

    func getShadowImage(_ completion: @escaping (UIImage?) -> Void) {
        completion(nil)
    }

    func addShadow() {
        getShadowImage { [weak self] shadowImage in
            guard let self = self,
                  let nodeToMove = self.nodeToMove,
                  let shadowImage = shadowImage else {
                return
            }

            let floorMaterial = SCNMaterial()
            floorMaterial.diffuse.contents = shadowImage

            let nodeSize = CGFloat(max(nodeToMove.boundingBox.max.z - nodeToMove.boundingBox.min.z,
                                       nodeToMove.boundingBox.max.x - nodeToMove.boundingBox.min.x)) * self.shadowImageScale
            let floorPlane = SCNPlane(width: nodeSize, height: nodeSize)
            floorPlane.materials = [floorMaterial]

            let floorNode = SCNNode(geometry: floorPlane)
            floorNode.position = SCNVector3(x: 0, y: -1 * self.distanceToGround / nodeToMove.scale.x, z: 0)
            floorNode.rotation = SCNVector4(1, 0, 0, -1 * Double.pi / 2)
            floorNode.name = "shadow"
            nodeToMove.addChildNode(floorNode)
        }
    }

    func getShadowNode() -> SCNNode? {
        return scene.rootNode.childNode(withName: "shadow", recursively: true)
    }

    @objc func viewPanned(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            generator.impactOccurred()
            panStartPoint = recognizer.location(in: self)
        case .changed:
            let translation = recognizer.translation(in: self)
            let panPoint = CGPoint(x: translation.x + panStartPoint.x,
                                   y: translation.y + panStartPoint.y)
            updateNodePosition(forPanPoint: panPoint)
        case .ended, .failed, .cancelled:
            moveStartPoint = nil
            nodeStartPoint = nil
            break
        default: break
        }
    }

    private func updateNodePosition(forPanPoint panPoint: CGPoint) {
        guard let node = nodeToMove else {
            return
        }

        let query = raycastQuery(from: panPoint, allowing: .estimatedPlane, alignment: .horizontal)!
        let results = session.raycast(query)

        if let result = results.first {
            var newPos: SCNVector3 {
                if let moveStartPoint = moveStartPoint,
                   let nodeStartPoint = nodeStartPoint {
                    return SCNVector3(x: nodeStartPoint.x + (result.worldTransform.columns.3.x - moveStartPoint.x),
                                      y: result.worldTransform.columns.3.y + distanceToGround,
                                      z: nodeStartPoint.z + (result.worldTransform.columns.3.z - moveStartPoint.z))
                }

                moveStartPoint = SCNVector3(result.worldTransform.columns.3.x,
                                            result.worldTransform.columns.3.y + distanceToGround,
                                            result.worldTransform.columns.3.z)
                nodeStartPoint = node.position
                return node.position
            }

            let action = SCNAction.move(to: newPos, duration: 0.1)
            node.runAction(action)
        }
    }

    @objc func viewPinched(_ recognizer: UIPinchGestureRecognizer) {
        print("pinched")
        guard let node = nodeToMove else {
            return
        }

        print("past")
        switch recognizer.state {
        case .began:
            startScale = node.scale.x
            if rotationGR.state != .changed {
                generator.impactOccurred()
            }
        case .changed:
            let curScale = startScale * Float(recognizer.scale)
            let floorY = node.position.y - distanceToGround
            node.scale = SCNVector3(curScale, curScale, curScale)
            node.position.y = floorY + distanceToGround
            getShadowNode()?.position = SCNVector3(x: 0, y: -1 * distanceToGround / node.scale.x, z: 0)
            break
        case .ended, .failed, .cancelled:
            break
        default: break
        }
    }

    @objc func viewRotated(_ recognizer: UIRotationGestureRecognizer) {
        guard let node = nodeToMove else {
            return
        }

        switch recognizer.state {
        case .began:
            startRotation = node.rotation.w
            if pinchGR.state != .changed {
                generator.impactOccurred()
            }
        case .changed:
            let curRotation = startRotation - Float(recognizer.rotation)
            node.rotation = SCNVector4(0, 1, 0, curRotation)
        case .ended, .failed, .cancelled:
            break
        default: break
        }
    }
}

extension GestureARView: ARSCNViewDelegate {
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard anchor is ARPlaneAnchor,
              !hasPlaced,
              let nodeToMove = nodeToMove else {
            return
        }
        
        guard let cam = session.currentFrame?.camera else {
            return
        }
        
        hasPlaced = true
        let camPos = SCNVector3.positionFrom(matrix: cam.transform)
        let anchorPos = SCNVector3.positionFrom(matrix: anchor.transform)
        let distanceToCam = camPos.distance(to: anchorPos)

        let scale = 0.4 * distanceToCam / nodeToMove.boundingSphere.radius
        nodeToMove.scale = SCNVector3(scale, scale, scale)
        nodeToMove.position = SCNVector3(x: anchorPos.x,
                                         y: anchorPos.y + distanceToGround,
                                         z: anchorPos.z)
        getShadowNode()?.position = SCNVector3(x: 0, y: -1 * distanceToGround / scale, z: 0)
        nodeToMove.opacity = 1

        generator.impactOccurred()
        coachingOverlay.setActive(false, animated: true)
    }
}

extension GestureARView: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if (gestureRecognizer is UIPinchGestureRecognizer && otherGestureRecognizer is UIRotationGestureRecognizer) ||
           (gestureRecognizer is UIRotationGestureRecognizer && otherGestureRecognizer is UIPinchGestureRecognizer) {
            return true
        }

        return false
    }
}

