// Licensed under the Any Distance Source-Available License
//
//  Route3DView.swift
//  ADAC
//
//  Created by Daniel Kuntz on 7/20/21.
//

import UIKit
import SwiftUI
import SceneKit
import SCNLine
import CoreLocation
import ARKit
import MetalPetal
import MetalKit

class Route3DRenderer: NSObject, SCNSceneRendererDelegate {
    private(set) weak var view: SCNView?

    private(set) var routeScene: RouteScene?
    private(set) var hasRendered: Bool = false
    private var palette: Palette = .dark
    private var sceneStartTime: TimeInterval?
    private var latestTime: TimeInterval = 0
    private var restart: Bool = false
    private(set) var zoom: CGFloat = 1
    
    var pausedForVideo: Bool = false

    init(view: SCNView, isTransparent: Bool = true) {
        self.view = view

        super.init()
        
        if isTransparent {
            view.backgroundColor = .clear
        }
    }
    
    deinit {
        view?.delegate = nil
        view = nil
    }
    
    // MARK: Rendering
    
    func renderLine(withCoordinates coords: [CLLocation]) {
        guard !hasRendered, !coords.isEmpty else {
            return
        }
        
        routeScene = RouteScene.routeScene(from: coords, forExport: false)

        guard let routeScene = routeScene else {
            return
        }

        view?.scene = routeScene.scene
        view?.layer.minificationFilter = .trilinear
        view?.layer.minificationFilterBias = 0.08
        view?.isPlaying = true
        view?.delegate = self
        
        hasRendered = true
        setPalette(self.palette)
        restartAnimation()
    }

    func setPalette(_ palette: Palette) {
        self.palette = palette

        routeScene?.palette = palette
    }

    func adjustPlaneTransparencyForAR() {
        guard let routeScene = routeScene else {
            return
        }

        for plane in routeScene.planeNodes {
            plane.geometry?.firstMaterial?.diffuse.contents = UIColor.white
            plane.geometry?.firstMaterial?.blendMode = .alpha
            plane.geometry?.firstMaterial?.readsFromDepthBuffer = false
        }
    }

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        guard var routeScene = routeScene else {
            return
        }

        // if startTime is nil assign time to it
        sceneStartTime = sceneStartTime ?? time
        latestTime = time
        
        if restart {
            sceneStartTime = latestTime
            routeScene.restartTextAnimation()
            restart = false
        }
        
        guard let view = view else { return }

        if view.isPlaying, let startTime = sceneStartTime {
            if pausedForVideo {
                routeScene.dotNode.isHidden = true
                routeScene.dotAnimationNode.isHidden = true
                view.sceneTime = 4
            } else {
                routeScene.dotNode.isHidden = false
                routeScene.dotAnimationNode.isHidden = false
                view.sceneTime = time - startTime
            }
        }

        routeScene.zoom = zoom
    }
    
    func renderer(_ renderer: SCNSceneRenderer, willRenderScene scene: SCNScene, atTime time: TimeInterval) {
    }
    
    // MARK: animations
    
    func restartAnimation() {
        guard hasRendered else {
            return
        }

        restart = true
    }

    func setZoom(_ zoom: CGFloat) {
        self.zoom = zoom
        
        guard let view = view else { return }

        if !view.isPlaying && hasRendered {
            routeScene?.zoom = zoom
        }
    }

}

struct Route3DViewRepresentable: UIViewRepresentable {
    var coords: [CLLocation]
    var palette: Palette
    var zoom: CGFloat

    func makeUIView(context: Context) -> Route3DView {
        let route3DView = Route3DView(frame: .zero)
        return route3DView
    }

    func updateUIView(_ uiView: Route3DView, context: Context) {
        uiView.renderLine(withCoordinates: coords)
        uiView.setPalette(palette)
        uiView.setZoom(zoom)
    }
}

final class Route3DView: SCNView, SCNSceneRendererDelegate {
    var renderer: Route3DRenderer!

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        renderer = Route3DRenderer(view: self)
    }

    override init(frame: CGRect, options: [String : Any]? = nil) {
        super.init(frame: frame, options: options)
        renderer = Route3DRenderer(view: self)
    }

    func renderLine(withCoordinates coords: [CLLocation]) {
        renderer.renderLine(withCoordinates: coords)
    }

    func setPalette(_ palette: Palette) {
        renderer.setPalette(palette)
    }

    func restartAnimation() {
        renderer.restartAnimation()
    }

    func setZoom(_ zoom: CGFloat) {
        renderer.setZoom(zoom)
    }
}

extension SCNMatrix4 {
    static func * (_ matrix1: SCNMatrix4, _ matrix2: SCNMatrix4) -> SCNMatrix4 {
        return SCNMatrix4Mult(matrix1, matrix2)
    }
}

extension SCNNode {
    static func lineNode(from: SCNVector3, to: SCNVector3, radius: CGFloat = 0.25) -> SCNNode {
        let vector = to - from
        let height = vector.length()
        let cylinder = SCNCylinder(radius: radius, height: CGFloat(height))
        cylinder.radialSegmentCount = 3
        let node = SCNNode(geometry: cylinder)
        node.position = (to + from) / 2
        node.eulerAngles = SCNVector3.lineEulerAngles(vector: vector)
        return node
    }

    static func planeNode(corners: [SCNVector3]) -> SCNNode {
        let indices: [Int32] = [0, 1, 2,
                                1, 2, 3]

        let textureCoordinates = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 1, y: 0),
            CGPoint(x: 0, y: 1),
            CGPoint(x: 1, y: 1)
        ]

        let vertexSource = SCNGeometrySource(vertices: corners)
        let uvSource = SCNGeometrySource(textureCoordinates: textureCoordinates)
        let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        let geometry = SCNGeometry(sources: [vertexSource, uvSource], elements: [element])

        let node = SCNNode(geometry: geometry)
        return node
    }
}

extension SCNVector3 {
    static func lineEulerAngles(vector: SCNVector3) -> SCNVector3 {
        let height = vector.length()
        let lxz = sqrtf(vector.x * vector.x + vector.z * vector.z)
        let pitchB = vector.y < 0 ? Float.pi - asinf(lxz/height) : asinf(lxz/height)
        let pitch = vector.z == 0 ? pitchB : sign(vector.z) * pitchB

        var yaw: Float = 0
        if vector.x != 0 || vector.z != 0 {
            let inner = vector.x / (height * sinf(pitch))
            if inner > 1 || inner < -1 {
                yaw = Float.pi / 2
            } else {
                yaw = asinf(inner)
            }
        }
        return SCNVector3(CGFloat(pitch), CGFloat(yaw), 0)
    }
}

extension Double {
    func map(fromRange: ClosedRange<Double>, toRange: ClosedRange<Double>) -> Double {
        let p = (self - fromRange.lowerBound) / (fromRange.upperBound - fromRange.lowerBound)
        return toRange.lowerBound + (p * (toRange.upperBound - toRange.lowerBound))
    }
}
