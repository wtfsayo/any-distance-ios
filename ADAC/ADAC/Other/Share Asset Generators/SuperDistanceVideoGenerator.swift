// Licensed under the Any Distance Source-Available License
//
//  SuperDistanceVideoGenerator.swift
//  ADAC
//
//  Created by Daniel Kuntz on 2/16/22.
//

import Foundation

class SuperDistanceVideoGenerator {
    static func renderSuperDistanceThankYouVideos(progress: @escaping ((Float) -> Void),
                                                  cancel: @escaping (() -> Bool),
                                                  completion: @escaping ((ShareVideos) -> Void)) {
        guard let baseUrl = Bundle.main.url(forResource: "super-distance-logo", withExtension: "mp4") else {
            return
        }

        renderInstagramStoryVideo(withBaseVideoUrl: baseUrl, cancel: cancel) { p in
            progress(p)
        } completion: { storyUrl in
            if cancel() { return }

            let shareVideos = ShareVideos(instagramStoryUrl: storyUrl,
                                          willRenderSquareVideo: true)
            renderSquareThankYouVideo(withBaseVideoUrl: baseUrl, cancel: cancel) { p in
                shareVideos.squareVideoProgress = p
            } completion: { squareUrl in
                if cancel() { return }
                
                shareVideos.squareUrl = squareUrl
            }
            completion(shareVideos)
        }
    }

    static func renderInstagramStoryVideo(withBaseVideoUrl baseVideoUrl: URL,
                                          cancel: @escaping (() -> Bool),
                                          progress: @escaping ((Float) -> Void),
                                          completion: @escaping ((URL) -> Void)) {
        let filterCommand = "-vf scale=1080:-1,pad=width=iw:height=1920:y=(oh-ih)/2"
        FFMpegUtils.renderVideo(originalVideoUrl: baseVideoUrl,
                                blackBarHeight: 0,
                                videoSize: .zero,
                                outputFilename: "Instagram-Story-Video",
                                customFilterCommand: filterCommand,
                                loop: true,
                                cancel: cancel,
                                progress: progress,
                                completion: completion)
    }

    static func renderSquareThankYouVideo(withBaseVideoUrl baseVideoUrl: URL,
                                          cancel: @escaping (() -> Bool),
                                          progress: @escaping ((Float) -> Void),
                                          completion: @escaping ((URL) -> Void)) {
        let filterCommand = "-vf scale=1080:-1,pad=width=iw:height=1080:y=(oh-ih)/2"
        FFMpegUtils.renderVideo(originalVideoUrl: baseVideoUrl,
                                blackBarHeight: 0,
                                videoSize: .zero,
                                outputFilename: "Square-Video",
                                customFilterCommand: filterCommand,
                                loop: true,
                                cancel: cancel,
                                progress: progress,
                                completion: completion)
    }
}
