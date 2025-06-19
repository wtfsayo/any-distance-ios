// Licensed under the Any Distance Source-Available License
//
//  Route3DVideoRenderer.swift
//  ADAC
//
//  Created by Daniel Kuntz on 10/9/21.
//

import UIKit
import SceneKit
import Accelerate
import CoreMedia
import CoreGraphics
import Combine

final class Route3DVideoRenderer {
    
    static private var disposables = Set<AnyCancellable>()
    
    static func renderRouteVideo(for canvas: LayoutCanvas,
                                 activity: Activity,
                                 design: ActivityDesign,
                                 baseImage: UIImage,
                                 cancel: @escaping (() -> Bool),
                                 progress: @escaping (Float) -> Void,
                                 completion: @escaping (URL?) -> Void) {
        let isFullscreen = design.cutoutShape == .fullScreen
        let finalSize = CGSize(width: baseImage.size.width,
                               height: baseImage.size.width * 1920.0 / 1080.0)
        let multiplier = finalSize.width / baseImage.size.width
        let originalRouteFrame = canvas.route3DView.frame
        var sceneFrame = canvas.graphContainer.convert(originalRouteFrame, to: canvas.view)
        let zoom = canvas.route3DView.renderer.zoom
        var originY = finalSize.height - (baseImage.size.height * multiplier)
        if isFullscreen {
            originY += 30.0
        }
        let finalOrigin = originY
        sceneFrame.origin.y += 40.0
        let finalSceneFrame = sceneFrame

        Task {
            UIGraphicsBeginImageContextWithOptions(finalSize, true, 1)
            baseImage.draw(in: CGRect(x: 0,
                                      y: finalOrigin,
                                      width: finalSize.width,
                                      height: baseImage.size.height * multiplier))
            let resizedBaseImage = UIGraphicsGetImageFromCurrentImageContext()!
            UIGraphicsEndImageContext()
            
            guard let coordinates = try? await activity.coordinates else {
                completion(nil)
                return
            }
            
            guard var routeScene = RouteScene.routeScene(from: coordinates, forExport: true) else {
                return
            }
            
            // TODO: figure out a better way
            routeScene.zoom = zoom
            routeScene.palette = design.palette

            let renderer = RouteVideoRenderer(with: routeScene)

            disposables.removeAll()
            renderer.$progress
                .receive(on: DispatchQueue.main)
                .sink { p in
                    progress(p)
                }.store(in: &disposables)

            try? renderer.prepareForExport(with: resizedBaseImage.size, filename: "render_route")
            
            let url = await renderer.export(with: resizedBaseImage,
                                            sceneFrame: finalSceneFrame)
            
            completion(url)
        }
    }

    private static func makeFinalImage(fromBackground background: UIImage, route: UIImage, routeFrame: CGRect) -> CGImage {
        UIGraphicsBeginImageContextWithOptions(background.size, true, 1)
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        UIGraphicsGetCurrentContext()?.setFillColorSpace(colorSpace)
        background.draw(at: .zero)
        route.draw(in: routeFrame)
        let newImage = UIGraphicsGetCurrentContext()?.makeImage()
        UIGraphicsEndImageContext()
        return newImage!
    }
}
