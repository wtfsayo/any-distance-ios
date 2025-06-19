// Licensed under the Any Distance Source-Available License
//
//  RouteARView.swift
//  ADAC
//
//  Created by Daniel Kuntz on 2/17/22.
//

import ARKit
import SceneKit

final class RouteARView: GestureARView {
    var routeRenderer: Route3DRenderer!
    var coordinates: [CLLocation] = []
    
    private let parentNode = SCNNode()
    private(set) var routeType: ARRouteType = .route

    override var nodeToMove: SCNNode? {
        return parentNode
    }

    override var shadowImageScale: CGFloat {
        return 1
    }

    override var distanceToGround: Float {
        guard let node = nodeToMove else {
            return 0.1
        }

        if routeType == .fullLayout {
            return node.scale.x * 500
        }
        
        return node.scale.x * 100
    }

    override func getShadowImage(_ completion: @escaping (UIImage?) -> Void) {
        RouteImageRenderer.renderRouteShadowImage(coordinates: coordinates, completion: completion)
    }

    func renderLine(withCoordinates coords: [CLLocation], canvas: LayoutCanvas?, palette: Palette) {
        coordinates = coords
        routeRenderer = Route3DRenderer(view: self, isTransparent: false)
        routeRenderer.renderLine(withCoordinates: coords)
        routeRenderer.adjustPlaneTransparencyForAR()
        delegate = self

        // fixes crash with `routeCenterNode` not getting initialized if we
        // failed to render
        guard let routeCenterNode = routeRenderer.routeScene?.centerNode else { return }
        
        routeCenterNode.removeFromParentNode()
        scene.rootNode.addChildNode(parentNode)
        parentNode.addChildNode(routeCenterNode)
        let scale = 0.004
        parentNode.scale = SCNVector3(scale, scale, scale)
        parentNode.position.y -= 1.0
        parentNode.position.z -= 1.5
        addShadow()
        nodeToMove?.opacity = 0
        routeRenderer.setPalette(palette)

        guard let nodeToMove = nodeToMove,
              let canvas = canvas else {
            return
        }

        CanvasShareImageGenerator.renderBackgroundAndOverlay(canvas) { canvasImage in
            CanvasShareImageGenerator.renderStats(canvas) { statsImage in
                let routeSize = CGFloat(max(nodeToMove.boundingBox.max.z - nodeToMove.boundingBox.min.z,
                                            nodeToMove.boundingBox.max.x - nodeToMove.boundingBox.min.x)) * 0.8
                let canvasSize = CGSize(width: routeSize,
                                        height: routeSize * (canvasImage.size.height / canvasImage.size.width))

                let wRotation: Float = (-1.0 * Float.pi / 3)

                let canvasStatsNode = SCNNode()
                canvasStatsNode.name = "canvas_stats"
                nodeToMove.addChildNode(canvasStatsNode)
                let scale = 1.75
                canvasStatsNode.scale = SCNVector3(scale, scale, scale)
                
                // Canvas
                
                let canvasMaterial = SCNMaterial()
                canvasMaterial.diffuse.contents = canvasImage
                canvasMaterial.isDoubleSided = true

                let canvasPlane = SCNPlane(width: canvasSize.width, height: canvasSize.height)
                canvasPlane.materials = [canvasMaterial]
                canvasPlane.cornerRadius = 16.0

                let canvasNode = SCNNode(geometry: canvasPlane)
                canvasNode.position = SCNVector3(x: 0, y: -100, z: 0)
                canvasNode.rotation = SCNVector4(1, 0, 0, wRotation)
                canvasNode.name = "canvas"
                canvasStatsNode.addChildNode(canvasNode)
                canvasNode.opacity = 0.0

                // Stats

                let statsMaterial = SCNMaterial()
                statsMaterial.diffuse.contents = statsImage
                statsMaterial.isDoubleSided = true

                let statsPlane = SCNPlane(width: canvasSize.width, height: canvasSize.height)
                statsPlane.materials = [statsMaterial]

                let statsNode = SCNNode(geometry: statsPlane)
                statsNode.position = SCNVector3(x: 0, y: -50, z: 35)
                statsNode.rotation = SCNVector4(1, 0, 0, wRotation)
                statsNode.scale = SCNVector3(0.95, 0.95, 0.95)
                statsNode.name = "stats"
                canvasStatsNode.addChildNode(statsNode)
                statsNode.opacity = 0.0

                // Counter-spin animation

                let spin = CABasicAnimation(keyPath: "rotation")
                spin.fromValue = NSValue(scnVector4: SCNVector4(x: 0, y: 1, z: 0, w: 0))
                spin.toValue = NSValue(scnVector4: SCNVector4(x: 0, y: 1, z: 0, w: -2 * .pi))
                spin.duration = 20
                spin.repeatCount = .infinity
                spin.usesSceneTimeBase = false
                canvasStatsNode.addAnimation(spin, forKey: "rotation")

                // Shadow

                let shadowMaterial = SCNMaterial()
                shadowMaterial.diffuse.contents = UIImage(named: "canvas_shadow")

                let shadowPlane = SCNPlane(width: canvasSize.width, height: canvasSize.height)
                shadowPlane.materials = [shadowMaterial]

                let shadowNode = SCNNode(geometry: shadowPlane)
                shadowNode.position = SCNVector3(x: 0, y: -0.99 * self.distanceToGround / nodeToMove.scale.x, z: 0)
                shadowNode.rotation = SCNVector4(1, 0, 0, -1 * Double.pi / 2)
                shadowNode.name = "canvas_shadow"
                shadowNode.opacity = 0
                canvasStatsNode.addChildNode(shadowNode)
            }
        }
    }

    override func addShadow() {
        getShadowImage { [weak self] shadowImage in
            guard let self = self,
                  let routeCenterNode = self.routeRenderer.routeScene?.centerNode,
                  let shadowImage = shadowImage else {
                return
            }

            let floorMaterial = SCNMaterial()
            floorMaterial.diffuse.contents = shadowImage

            let nodeSize = CGFloat(routeCenterNode.boundingSphere.radius) * self.shadowImageScale
            let floorPlane = SCNPlane(width: nodeSize, height: nodeSize)
            floorPlane.materials = [floorMaterial]

            let floorNode = SCNNode(geometry: floorPlane)
            floorNode.position = SCNVector3(x: 0, y: -1 * self.distanceToGround / self.parentNode.scale.x, z: 0)
            floorNode.rotation = SCNVector4(1, 0, 0, -1 * Double.pi / 2)
            let scale = 1.75
            floorNode.scale = SCNVector3(scale, scale, scale)
            floorNode.opacity = 0.8
            floorNode.name = "shadow"
            routeCenterNode.addChildNode(floorNode)
        }
    }

    func setRouteType(_ routeType: ARRouteType) {
        guard let nodeToMove = nodeToMove else {
            return
        }

        let floorY = nodeToMove.position.y - distanceToGround
        let prevRouteType = self.routeType
        self.routeType = routeType

        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.4
        switch routeType {
        case .route:
            scene.rootNode.childNode(withName: "shadow", recursively: true)?.opacity = 1
            scene.rootNode.childNode(withName: "canvas_shadow", recursively: true)?.opacity = 0
            scene.rootNode.childNode(withName: "canvas", recursively: true)?.opacity = 0

            let statsNode = scene.rootNode.childNode(withName: "stats", recursively: true)
            statsNode?.opacity = 0

            if prevRouteType == .fullLayout {
                nodeToMove.scale *= SCNVector3(2, 2, 2)
            }
        case .routePlusStats:
            scene.rootNode.childNode(withName: "shadow", recursively: true)?.opacity = 1
            scene.rootNode.childNode(withName: "canvas_shadow", recursively: true)?.opacity = 0
            scene.rootNode.childNode(withName: "canvas", recursively: true)?.opacity = 0

            let statsNode = scene.rootNode.childNode(withName: "stats", recursively: true)
            statsNode?.opacity = 1
            statsNode?.position = SCNVector3(x: 0, y: 150, z: 0)
            statsNode?.rotation = SCNVector4(1, 0, 0, 0)
            statsNode?.scale = SCNVector3(0.7, 0.7, 0.7)

            let billboardConstraint = SCNBillboardConstraint()
            billboardConstraint.freeAxes = .Y
            statsNode?.constraints = [billboardConstraint]

            if prevRouteType == .fullLayout {
                nodeToMove.scale *= SCNVector3(2, 2, 2)
            }
        case .fullLayout:
            scene.rootNode.childNode(withName: "shadow", recursively: true)?.opacity = 0
            scene.rootNode.childNode(withName: "canvas_shadow", recursively: true)?.opacity = 1
            scene.rootNode.childNode(withName: "canvas", recursively: true)?.opacity = 1
            scene.rootNode.childNode(withName: "stats", recursively: true)?.opacity = 1

            let statsNode = scene.rootNode.childNode(withName: "stats", recursively: true)
            statsNode?.opacity = 1
            statsNode?.position = SCNVector3(x: 0, y: -50, z: 35)
            statsNode?.rotation = SCNVector4(1, 0, 0, (-1.0 * Float.pi / 3))
            statsNode?.scale = SCNVector3(1, 1, 1)
            statsNode?.constraints = []

            if prevRouteType != .fullLayout {
                nodeToMove.scale *= SCNVector3(0.5, 0.5, 0.5)
            }
        }

        nodeToMove.position.y = floorY + distanceToGround
        let shadowPosition = SCNVector3(x: 0, y: -1 * distanceToGround / nodeToMove.scale.x, z: 0)
        getShadowNode()?.position = shadowPosition
        let canvasShadowPosition = SCNVector3(x: 0, y: -0.99 * self.distanceToGround / nodeToMove.scale.x, z: 0)
        scene.rootNode.childNode(withName: "canvas_shadow", recursively: true)?.position = canvasShadowPosition

        SCNTransaction.commit()
    }

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        routeRenderer.renderer(renderer, updateAtTime: time)
    }
}
