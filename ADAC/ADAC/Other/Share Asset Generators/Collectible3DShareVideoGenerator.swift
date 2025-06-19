// Licensed under the Any Distance Source-Available License
//
//  Collectible3DShareVideoGenerator.swift
//  ADAC
//
//  Created by Daniel Kuntz on 2/14/22.
//

import UIKit
import SceneKit
import Accelerate
import CoreMedia
import CoreGraphics

class Collectible3DShareVideoGenerator {
    static func renderVideos(forMedalView medalView: Collectible3DView,
                             cancel: @escaping (() -> Bool),
                             progress: @escaping ((Float) -> Void),
                             completion: @escaping ((ShareVideos) -> Void)) {
        renderBaseVideo(forMedalView: medalView,
                        cancel: cancel) { p in
            progress(p * 0.5)
        } completion: { baseVideoUrl in
            if cancel() { return }

            FFMpegUtils.loopVideo(atUrl: baseVideoUrl,
                                  loopCount: 1,
                                  outputFilename: "render-medal-loop",
                                  cancel: cancel) { p in
                progress(0.5 + p * 0.25)
            } completion: { loopedBaseVideoUrl in
                let videos = ShareVideos(instagramStoryUrl: loopedBaseVideoUrl,
                                         willRenderSquareVideo: true)
                FFMpegUtils.renderFullSquareVideo(withInstagramStoryVideoUrl: loopedBaseVideoUrl,
                                                  cancel: cancel) { p in
                    videos.squareVideoProgress = p
                } completion: { squareUrl in
                    videos.squareUrl = squareUrl
                }
                completion(videos)
            }
        }
    }

    private static func renderBaseVideo(forMedalView medalView: Collectible3DView,
                                        cancel: @escaping (() -> Bool),
                                        progress: @escaping ((Float) -> Void),
                                        completion: @escaping ((URL) -> Void)) {
        guard let collectible = medalView.collectible else {
            return
        }

        let instaStoryImage = CollectibleShareImageGenerator.make3DBackgroundImage(forCollectible: collectible)
        let medalSize = CGSize(width: 1080, height: 1080 * (medalView.frame.size.height / medalView.frame.size.width))
        let medalFrame = CGRect(x: 0,
                                y: (instaStoryImage.size.height / 2) - (medalSize.height / 1.63),
                                width: medalSize.width,
                                height: medalSize.height)

        DispatchQueue.global(qos: .userInteractive).async {
            medalView.isPlaying = false
            medalView.sceneTime = 0

            let renderSettings = RenderSettings(size: instaStoryImage.size,
                                                fps: 30,
                                                avCodecKey: .h264,
                                                videoFilename: "render-medal",
                                                videoFilenameExt: "mp4")
            let converter = ImageToVideoConverter(renderSettings: renderSettings)
            converter.start()

            var curTime: TimeInterval = 0
            while curTime < 6 {
                if cancel() {
                    converter.finishRendering {}
                    DispatchQueue.main.async {
                        medalView.isPlaying = true
                    }
                    return
                }

                autoreleasepool {
                    if UIApplication.shared.applicationState == .active {
                        let snapshot = medalView.snapshot()
                        medalView.sceneTime = curTime + (1.0 / 30.0)
                        let finalImage = makeFinalImage(fromBackground: instaStoryImage,
                                                        medal: snapshot,
                                                        medalFrame: medalFrame)

                        converter.addImage(image: finalImage,
                                           withPresentationTime: CMTime(seconds: curTime, preferredTimescale: 30000))

                        curTime += 1.0 / 30.0
                    }

                    DispatchQueue.main.async {
                        progress(Float(curTime / 6))
                    }
                }
            }

            converter.finishRendering {
                DispatchQueue.main.async {
                    medalView.isPlaying = true
                    completion(renderSettings.outputURL)
                }
            }
        }
    }

    private static func makeFinalImage(fromBackground background: UIImage,
                                       medal: UIImage,
                                       medalFrame: CGRect) -> CGImage {
        UIGraphicsBeginImageContextWithOptions(background.size, true, 1)
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        UIGraphicsGetCurrentContext()?.setFillColorSpace(colorSpace)
        background.draw(at: .zero)
        medal.draw(in: medalFrame)
        let newImage = UIGraphicsGetCurrentContext()?.makeImage()
        UIGraphicsEndImageContext()
        return newImage!
    }
}
