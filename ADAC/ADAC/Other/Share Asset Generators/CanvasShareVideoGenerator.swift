// Licensed under the Any Distance Source-Available License
//
//  ShareVideoGenerator.swift
//  ADAC
//
//  Created by Daniel Kuntz on 3/12/21.
//

import UIKit
import AVFoundation
import AVKit
import Photos
import SwiftUI

final class CanvasShareVideoGenerator {
    static func renderVideos(for canvas: LayoutCanvas,
                             activity: Activity,
                             design: ActivityDesign,
                             cancel: @escaping (() -> Bool),
                             progress: @escaping ((Float) -> Void),
                             completion: @escaping ((ShareVideos) -> Void)) {
        if design.graphType == .route3d && design.media != .video {
            renderVideosWith3DRoute(for: canvas,
                                    activity: activity,
                                    design: design,
                                    cancel: cancel,
                                    progress: progress,
                                    completion: completion)
        } else {
            renderVideosWith2DRoute(forCanvas: canvas,
                                    with: design,
                                    cancel: cancel,
                                    progress: progress,
                                    completion: completion)
        }
    }

    private static func renderVideosWith2DRoute(forCanvas canvas: LayoutCanvas,
                                                with design: ActivityDesign,
                                                cancel: @escaping (() -> Bool),
                                                progress: @escaping ((Float) -> Void),
                                                completion: @escaping ((ShareVideos) -> Void)) {
        CanvasShareImageGenerator.renderInstaStoryBaseImage(canvas, include3DRoute: design.graphType == .route3d) { (baseImage) in
            progress(0.2)
            if cancel() { return }

            self.renderInstagramStoryVideo(forCanvas: canvas, with: design, cancel: cancel, withBaseImage: baseImage) { (p) in
                progress(0.2 + p * 0.3)
            } completion: { (instaStoryUrl) in
                if cancel() { return }

                let videos = ShareVideos(instagramStoryUrl: instaStoryUrl,
                                         willRenderSquareVideo: true)
                FFMpegUtils.renderSquareVideo(withInstagramStoryVideoUrl: instaStoryUrl,
                                              layoutIsFullScreen: design.cutoutShape == .fullScreen,
                                              cancel: cancel) { (p) in
                    videos.squareVideoProgress = p
                } completion: { squareUrl in
                    if cancel() { return }
                    
                    videos.squareUrl = squareUrl
                }
                DispatchQueue.main.async {
                    completion(videos)
                }
            }
        }
    }

    private static func renderVideosWith3DRoute(for canvas: LayoutCanvas,
                                                activity: Activity,
                                                design: ActivityDesign,
                                                cancel: @escaping (() -> Bool),
                                                progress: @escaping ((Float) -> Void),
                                                completion: @escaping ((ShareVideos) -> Void)) {
        CanvasShareImageGenerator.renderInstaStoryBaseImage(canvas) { baseImage in
            progress(0.1)
            if cancel() { return }

            Route3DVideoRenderer.renderRouteVideo(for: canvas,
                                                  activity: activity,
                                                  design: design,
                                                  baseImage: baseImage,
                                                  cancel: cancel) { p in
                progress(0.1 + p * 0.9)
            } completion: { instaStoryUrl in
                if cancel() { return }
                
                guard let instaStoryUrl = instaStoryUrl else { return }
                
                let videos = ShareVideos(instagramStoryUrl: instaStoryUrl,
                                         willRenderSquareVideo: true)

                FFMpegUtils.renderSquareVideo(withInstagramStoryVideoUrl: instaStoryUrl,
                                        layoutIsFullScreen: design.cutoutShape == .fullScreen,
                                        cancel: cancel) { p in
                    videos.squareVideoProgress = p
                } completion: { squareUrl in
                    if cancel() { return }

                    videos.squareUrl = squareUrl
                }
                
                DispatchQueue.main.async {
                    completion(videos)
                }
            }
        }
    }

    static func renderInstagramStoryVideo(forCanvas canvas: LayoutCanvas,
                                          with design: ActivityDesign,
                                          cancel: @escaping (() -> Bool),
                                          withBaseImage baseImage: UIImage,
                                          progress: @escaping ((Float) -> Void),
                                          completion: @escaping ((URL) -> Void)) {
        var videoAsset: AVAsset?
        if design.videoMode == .loop {
            videoAsset = design.videoAsset
        } else if design.videoMode == .bounce {
            videoAsset = design.videoAssetWithBounceFromFile
        }

        guard let videoUrlAsset = videoAsset as? AVURLAsset else {
            return
        }

        // Setup mutableComposition from the existing video
        let mutableComposition = AVMutableComposition()
        let videoAssetTrack = videoUrlAsset.tracks(withMediaType: .video).first!

        // Add the video
        let videoCompositionTrack = mutableComposition.addMutableTrack(withMediaType: AVMediaType.video,
                                                                       preferredTrackID: kCMPersistentTrackID_Invalid)
        try! videoCompositionTrack?.insertTimeRange(CMTimeRange(start: CMTime.zero, duration: videoAssetTrack.timeRange.duration),
                                                    of: videoAssetTrack,
                                                    at: CMTime.zero)

        // Add audio
        if let audioAssetTrack = videoUrlAsset.tracks(withMediaType: AVMediaType.audio).first {
            let audioCompositionTrack = mutableComposition.addMutableTrack(withMediaType: .audio,
                                                                           preferredTrackID: kCMPersistentTrackID_Invalid)
            try! audioCompositionTrack?.insertTimeRange(CMTimeRange(start: CMTime.zero, duration: audioAssetTrack.timeRange.duration),
                                                        of: audioAssetTrack, at: CMTime.zero)
        }

        // Layout the video and overlay image
        let renderSize = CGSize(width: 1080.0, height: 1920.0)
        let renderFrame = CGRect(origin: .zero, size: renderSize)
        var videoSize: CGSize = (videoCompositionTrack?.naturalSize)!

        // Correct the transform of the video track.
        let (_, isPortrait) = orientationFromTransform(videoAssetTrack.preferredTransform)
        if !isPortrait {
            // If the video is landscape, we need to apply a transform to get the video to fill the
            // video layer. There is a bug in AVFoundation that scales the video incorrectly if the
            // renderSize is in portrait and the video track is in landscape (wtf).
            let bugFixTransform = CGAffineTransform(scaleX: renderSize.width / videoAssetTrack.naturalSize.width,
                                                    y: renderSize.height / videoAssetTrack.naturalSize.height)
            videoCompositionTrack?.preferredTransform = videoAssetTrack.preferredTransform.concatenating(bugFixTransform)
        } else {
            videoSize = CGSize(width: videoSize.height, height: videoSize.width)

            // If the video is in portrait, just apply the original asset track's preferred transform.
            // We also need to flip the width and height properties of videoSize, since naturalSize
            // does not take orientation into account for some stupid reason.
            let bugFixTransform = CGAffineTransform(scaleX: renderSize.width/videoAssetTrack.naturalSize.height,
                                                    y: renderSize.height/videoAssetTrack.naturalSize.width)

            let tx = videoAssetTrack.preferredTransform.tx - videoSize.width
            let transformTranslate = CGAffineTransform(translationX: -1.0 * tx, y: 0.0)

            videoCompositionTrack?.preferredTransform = videoAssetTrack.preferredTransform.concatenating(bugFixTransform)
                .concatenating(transformTranslate)
        }

        let imageLayer = CALayer()
        imageLayer.contents = baseImage.cgImage
        let imageLayerScaleFactor = renderSize.width / baseImage.size.width
        let imageLayerSize = CGSize(width: renderSize.width, height: baseImage.size.height * imageLayerScaleFactor)
        imageLayer.frame = CGRect(origin: .zero, size: imageLayerSize)
        if design.cutoutShape == .fullScreen {
            imageLayer.frame.origin.y -= 45.0
        }

        let blackBarLayer = CALayer()
        blackBarLayer.backgroundColor = UIColor.black.cgColor

        let blackBarHeight: CGFloat = design.cutoutShape == .fullScreen ? 175.0 : 145.0
        blackBarLayer.frame = CGRect(origin: CGPoint(x: 0.0, y: renderSize.height - blackBarHeight),
                                     size: CGSize(width: renderSize.width, height: blackBarHeight))

        // Calculate the position of the video in the composition based on the position of the video
        // in the canvas. Some math is required because CALayer's coordinate system has a flipped y
        // axis, and because the aspect ratio and final video size is different than that of the canvas.
        let sizeRatio = renderSize.width / canvas.bounds.width
        let videoViewOrigin = CGPoint(x: -1.0 * design.photoOffset.x * sizeRatio,
                                      y: -1.0 * design.photoOffset.y * sizeRatio)
        let videoViewSize = CGSize(width: canvas.cutoutShapeView.videoView.bounds.width * CGFloat(design.photoZoom) * sizeRatio,
                                   height: canvas.cutoutShapeView.videoView.bounds.height * CGFloat(design.photoZoom) * sizeRatio)
        let videoLayerFrameInVideoView = CGSize.aspectFit(aspectRatio: videoSize, boundingSize: videoViewSize)
        let heightDifference = renderSize.height - (canvas.bounds.height * sizeRatio)
        let videoLayerFrame = CGRect(x: videoLayerFrameInVideoView.origin.x + videoViewOrigin.x,
                                     y: renderSize.height - (videoLayerFrameInVideoView.origin.y + videoViewOrigin.y + videoLayerFrameInVideoView.size.height + heightDifference),
                                     width: videoLayerFrameInVideoView.size.width,
                                     height: videoLayerFrameInVideoView.size.height)

        // Add all the layers to the composition
        let videoLayer = CALayer()
        videoLayer.frame = videoLayerFrame

        let animationLayer = CALayer()
        animationLayer.frame = renderFrame
        animationLayer.addSublayer(videoLayer)
        animationLayer.addSublayer(imageLayer)
        animationLayer.addSublayer(blackBarLayer)

        let videoComposition = AVMutableVideoComposition(propertiesOf: (videoCompositionTrack?.asset!)!)
        videoComposition.renderSize = renderSize
        videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer,
                                                                             in: animationLayer)

        // Setup the output file path for exporting.
        let documentDirectory = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first!
        let documentDirectoryUrl = URL(fileURLWithPath: documentDirectory)
        let destinationUrl = documentDirectoryUrl.appendingPathComponent("Instagram-Story-Video.mp4")
        FileManager.default.removeItemIfExists(atUrl: destinationUrl)

        // Setup the export session and export the final video.
        let exportSession = AVAssetExportSession(asset: mutableComposition,
                                                 presetName: AVAssetExportPresetHEVCHighestQuality)!
        exportSession.videoComposition = videoComposition
        exportSession.shouldOptimizeForNetworkUse = false
        exportSession.outputURL = destinationUrl
        exportSession.outputFileType = AVFileType.mp4
        exportSession.timeRange = CMTimeRangeMake(start: .zero, duration: mutableComposition.duration)

        let timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { (timer) in
            progress(exportSession.progress)
            if cancel() {
                exportSession.cancelExport()
                timer.invalidate()
            }
        }

        exportSession.exportAsynchronously {
            timer.invalidate()
            DispatchQueue.main.async {
                completion(destinationUrl)
            }
        }
    }

    static func orientationFromTransform(_ transform: CGAffineTransform) -> (orientation: UIImage.Orientation, isPortrait: Bool) {
        var assetOrientation = UIImage.Orientation.up
        var isPortrait = false
        let tfA = transform.a
        let tfB = transform.b
        let tfC = transform.c
        let tfD = transform.d

        if tfA == 0 && tfB == 1.0 && tfC == -1.0 && tfD == 0 {
            assetOrientation = .right
            isPortrait = true
        } else if tfA == 0 && tfB == -1.0 && tfC == 1.0 && tfD == 0 {
            assetOrientation = .left
            isPortrait = true
        } else if tfA == 1.0 && tfB == 0 && tfC == 0 && tfD == 1.0 {
            assetOrientation = .up
        } else if tfA == -1.0 && tfB == 0 && tfC == 0 && tfD == -1.0 {
            assetOrientation = .down
        }
        return (assetOrientation, isPortrait)
    }
}

