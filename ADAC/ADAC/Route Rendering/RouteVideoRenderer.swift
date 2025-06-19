// Licensed under the Any Distance Source-Available License
//
//  RouteVideoRenderer.swift
//  SceneKitOffscreen
//
//  Created by Jarod Luebbert on 6/8/22.
//  Copyright © 2022 Any Distance. All rights reserved.
//

import Foundation
import Combine
import MetalPetal
import Sentry

fileprivate extension CGAffineTransform {
    var scale: Double {
        get {
            return sqrt(Double(a * a + c * c))
        }
    }
}

class RouteVideoRenderer {
    
    static var defaultDevice: MTLDevice = MTLCreateSystemDefaultDevice()!
    
    private let routeScene: RouteScene
    private let imageRenderer = PixelBufferPoolBackedImageRenderer()
    private let renderContext: MTIContext
    private let sceneRenderer: MTISCNSceneRenderer
    private var videoWriter: VideoWriter?
    
    @Published var progress: Float = 0.0
    
    init(with routeScene: RouteScene) {
        self.routeScene = routeScene
        renderContext = try! MTIContext(device: Self.defaultDevice)
        sceneRenderer = MTISCNSceneRenderer(device: Self.defaultDevice)
        sceneRenderer.antialiasingMode = .multisampling4X
        sceneRenderer.scene = routeScene.scene
    }
    
    func snapshot(at time: TimeInterval, viewport: CGRect) -> MTIImage {
        var sceneImage = sceneRenderer.snapshot(atTime: time,
                                                viewport: viewport,
                                                pixelFormat: .unspecified,
                                                isOpaque: false)
            .unpremultiplyingAlpha()
        sceneImage = MTILinearToSRGBToneCurveFilter.image(byProcessingImage: sceneImage)
        return sceneImage
    }
    
    func prepareForExport(with videoSize: CGSize, filename: String) throws {
        guard videoWriter == nil else { return }
        videoWriter = try VideoWriter(videoName: "\(filename).mp4", with: videoSize)
        videoWriter?.startSession(at: .zero)
    }
    
    func export(with backgroundImage: UIImage, sceneFrame: CGRect) async -> URL? {
        var currentTime: TimeInterval = 0.0
        
        progress = 0.0
        
        guard let backgroundImageCG = backgroundImage.cgImage else { return nil }
        
        let imageRect = CGRect(x: 0.0, y: 0.0, width: backgroundImage.size.width, height: backgroundImage.size.height)
        
        guard let videoWriter = videoWriter else {
            print("not prepared for export")
            return nil
        }
        
        let filter = MultilayerCompositingFilter()
        filter.outputPixelFormat = .bgra8Unorm
        var mtiBgImage = MTIImage(cgImage: backgroundImageCG)
        filter.inputBackgroundImage = mtiBgImage
                
        let scale = imageRect.size.width / sceneFrame.size.width
        let scaledSceneFrame = sceneFrame
            .applying(CGAffineTransform.init(scaleX: scale, y: scale))
        let viewport = CGRect(origin: .zero, size: sceneFrame.size)
            .applying(CGAffineTransform.init(scaleX: scale, y: scale))

        routeScene.restartTextAnimation()
        while currentTime < routeScene.animationDuration {
            let routeImage = snapshot(at: currentTime,
                                      viewport: viewport)
            filter.layers = [
                MultilayerCompositingFilter.Layer(content: routeImage)
                    .frame(scaledSceneFrame, layoutUnit: .pixel),
            ]
            
            guard let outputImage = filter.outputImage else { return nil }

            do {
                let renderOutput = try self.imageRenderer.render(outputImage,
                                                                 using: renderContext,
                                                                 sRGB: false)
                videoWriter.append(buffer: renderOutput, at: CMTimeMakeWithSeconds(currentTime, preferredTimescale: 30000))
            } catch {
                SentrySDK.capture(error: error)
            }
            
            progress = Float(currentTime / self.routeScene.animationDuration)
            
            currentTime += (1.0 / 30.0)
        }
        
        progress = 1.0
        
        let url = await videoWriter.endSession()
        
        imageRenderer.finish()
        
        self.videoWriter = nil
        
        return url
    }
    
}
