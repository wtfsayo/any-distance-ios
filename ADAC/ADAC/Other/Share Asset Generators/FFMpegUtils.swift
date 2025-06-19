// Licensed under the Any Distance Source-Available License
//
//  FFMpegUtils.swift
//  ADAC
//
//  Created by Daniel Kuntz on 2/16/22.
//

import UIKit
import AVFoundation
import AVKit
import ffmpegkit

class FFMpegUtils {
    static func renderSquareVideo(withInstagramStoryVideoUrl storyVideoUrl: URL,
                                  layoutIsFullScreen: Bool,
                                  cancel: @escaping (() -> Bool),
                                  progress: @escaping ((Float) -> Void),
                                  completion: @escaping ((URL) -> Void)) {
        renderVideo(originalVideoUrl: storyVideoUrl,
                    blackBarHeight: layoutIsFullScreen ? 175 : 165,
                    videoSize: CGSize(width: 1080, height: 1080),
                    outputFilename: "Square-Video",
                    cancel: cancel,
                    progress: progress,
                    completion: completion)
    }

    static func renderFullSquareVideo(withInstagramStoryVideoUrl storyVideoUrl: URL,
                                      cancel: @escaping (() -> Bool),
                                      progress: @escaping ((Float) -> Void),
                                      completion: @escaping ((URL) -> Void)) {
        renderVideo(originalVideoUrl: storyVideoUrl,
                    blackBarHeight: 0,
                    videoSize: CGSize(width: 1080, height: 1080),
                    outputFilename: "Square-Video",
                    cancel: cancel,
                    progress: progress,
                    completion: completion)
    }

    static func renderVideo(originalVideoUrl: URL,
                            blackBarHeight: CGFloat,
                            videoSize: CGSize,
                            outputFilename: String,
                            customFilterCommand: String? = nil,
                            loop: Bool = false,
                            cancel: @escaping (() -> Bool),
                            progress: @escaping ((Float) -> Void),
                            completion: @escaping ((URL) -> Void)) {
        let asset = AVAsset(url: originalVideoUrl)
        let duration = asset.duration
        let durationTime = CMTimeGetSeconds(duration)
        let loopCount: Int = loop ? 4 : 0
        let frameCount = Float(loopCount + 1) * Float(durationTime) * 30.0

        // Setup the output file path for exporting.
        let documentDirectory = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.cachesDirectory,
                                                                    FileManager.SearchPathDomainMask.userDomainMask, true).first!
        let documentDirectoryUrl = URL(fileURLWithPath: documentDirectory)
        let destinationUrl = documentDirectoryUrl.appendingPathComponent("\(outputFilename).mp4")
        FileManager.default.removeItemIfExists(atUrl: destinationUrl)

        let filterCommand = customFilterCommand ?? "-vf crop=iw:ih-\(blackBarHeight):0:\(blackBarHeight),scale=-1:\(videoSize.height),pad=width=\(videoSize.width):height=ih:x=(ow-iw)/2"
        let loopCommand = loop ? "-stream_loop \(loopCount)" : ""
        let command = "\(loopCommand) -i \(originalVideoUrl.path) -q:v 7 \(filterCommand) \(destinationUrl.path)"

        render(withCommand: command,
               destinationUrl: destinationUrl,
               frameCount: frameCount,
               cancel: cancel,
               progress: progress,
               completion: completion)
    }

    static func loopVideo(atUrl url: URL,
                          loopCount: Int,
                          outputFilename: String,
                          cancel: @escaping (() -> Bool),
                          progress: @escaping ((Float) -> Void),
                          completion: @escaping ((URL) -> Void)) {
        let asset = AVAsset(url: url)
        let duration = asset.duration
        let durationTime = CMTimeGetSeconds(duration)
        let frameCount = Float(loopCount+1) * Float(durationTime * 30)

        // Setup the output file path for exporting.
        let documentDirectory = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.cachesDirectory,
                                                                    FileManager.SearchPathDomainMask.userDomainMask, true).first!
        let documentDirectoryUrl = URL(fileURLWithPath: documentDirectory)
        let destinationUrl = documentDirectoryUrl.appendingPathComponent("\(outputFilename).mp4")
        FileManager.default.removeItemIfExists(atUrl: destinationUrl)

        let loopCommand = "-stream_loop \(loopCount)"
        let command = "\(loopCommand) -i \(url.path) -c copy \(destinationUrl.path)"

        render(withCommand: command,
               destinationUrl: destinationUrl,
               frameCount: frameCount,
               cancel: cancel,
               progress: progress,
               completion: completion)
    }

    static func addWatermarkToVideo(atUrl url: URL,
                                    outputFilename: String,
                                    cancel: @escaping (() -> Bool),
                                    progress: @escaping ((Float) -> Void),
                                    completion: @escaping ((URL) -> Void)) {
        let asset = AVAsset(url: url)
        let duration = asset.duration
        let durationTime = CMTimeGetSeconds(duration)
        let frameCount = Float(durationTime) * (asset.tracks.first?.nominalFrameRate ?? 30)

        // Setup the output file path for exporting.
        let documentDirectory = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.cachesDirectory,
                                                                    FileManager.SearchPathDomainMask.userDomainMask, true).first!
        let documentDirectoryUrl = URL(fileURLWithPath: documentDirectory)
        let destinationUrl = documentDirectoryUrl.appendingPathComponent("\(outputFilename).mp4")
        FileManager.default.removeItemIfExists(atUrl: destinationUrl)

        let watermarkPath = Bundle.main.path(forResource: "watermark_v2", ofType: "pic")!
        let command = "-i \(url.path) -i \(watermarkPath) -filter_complex overlay=x=(main_w-overlay_w)/2:y=(main_h-overlay_h)-80 -q:v 5 \(destinationUrl.path)"

        render(withCommand: command,
               destinationUrl: destinationUrl,
               frameCount: frameCount,
               cancel: cancel,
               progress: progress,
               completion: completion)
    }

    static func render(withCommand command: String,
                       destinationUrl: URL,
                       frameCount: Float,
                       cancel: @escaping (() -> Bool),
                       progress: @escaping ((Float) -> Void),
                       completion: @escaping ((URL) -> Void)) {
        FFmpegKit.executeAsync(command, withCompleteCallback: { session in
            guard let session = session else {
                return
            }

            let returnCode = session.getReturnCode()
            let stateString = FFmpegKitConfig.sessionState(toString: session.getState())
            if ReturnCode.isSuccess(returnCode) || stateString == "COMPLETED" {
                DispatchQueue.main.async {
                    completion(destinationUrl)
                }
            } else {
                print("session failed with state: %@", stateString)
            }
        }, withLogCallback: { _ in
        }, withStatisticsCallback: { statistics in
            let frameNumber = Float(statistics?.getVideoFrameNumber() ?? 1)
            DispatchQueue.main.async {
                progress(frameNumber / frameCount)
            }

            if let id = statistics?.getSessionId(), cancel() {
                FFmpegKit.cancel(id)
            }
        }, onDispatchQueue: DispatchQueue.global(qos: .userInteractive))
    }
}
