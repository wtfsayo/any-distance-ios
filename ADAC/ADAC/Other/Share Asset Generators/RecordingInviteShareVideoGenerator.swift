// Licensed under the Any Distance Source-Available License
//
//  RecordingInviteShareVideoGenerator.swift
//  ADAC
//
//  Created by Daniel Kuntz on 9/9/22.
//

import UIKit
import AVFoundation
import AVKit

final class RecordingInviteShareVideoGenerator {
    static func renderVideos(withCode code: String,
                             cancel: @escaping (() -> Bool),
                             progress: @escaping ((Float) -> Void),
                             completion: @escaping ((ShareVideos) -> Void)) {
        Task(priority: .userInitiated) {
            let codeImage = image(fromText: code)
            let codeImageUrl = FileManager.default.temporaryDirectory.appendingPathComponent("code.png")
            if let data = codeImage.pngData() {
                try? data.write(to: codeImageUrl)
            }
            let bgUrl = Bundle.main.url(forResource: "activity-tracking-invite-share",
                                        withExtension: "mp4")!
            let outputTwitterUrl = FileManager.default.temporaryDirectory.appendingPathComponent("code-twitter.mp4")
            FileManager.default.removeItemIfExists(atUrl: outputTwitterUrl)

            let command = "-i \(bgUrl) -i \(codeImageUrl) -filter_complex overlay=x=(main_w-overlay_w)/2:y=(main_h*0.71) -q:v 1 \(outputTwitterUrl)"

            FFMpegUtils.render(withCommand: command, destinationUrl: outputTwitterUrl, frameCount: 210, cancel: cancel) { p1 in
                progress(p1 * 0.25)
            } completion: { outputTwitterUrl in
                let outputInstaUrl = FileManager.default.temporaryDirectory.appendingPathComponent("code-insta.mp4")
                FileManager.default.removeItemIfExists(atUrl: outputInstaUrl)

                let cropCommand = "-i \(outputTwitterUrl) -filter:v crop=562:900:169:0 -q:v 1 \(outputInstaUrl)"

                FFMpegUtils.render(withCommand: cropCommand, destinationUrl: outputInstaUrl, frameCount: 210, cancel: cancel) { p2 in
                    progress(0.5 + (p2 * 0.25))
                } completion: { outputInstaUrl in
                    let videos = ShareVideos(instagramStoryUrl: outputInstaUrl, willRenderSquareVideo: true)
                    videos.squareUrl = outputTwitterUrl
                    completion(videos)
                }
            }
        }
    }

    private static func image(fromText text: String) -> UIImage {
        let font = UIFont.monospacedSystemFont(ofSize: 20,
                                               weight: .regular)
        let size = NSString(string: text)
            .size(withAttributes: [.font : font])
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            NSString(string: text).draw(at: .zero,
                                        withAttributes: [.font: font,
                                                         .foregroundColor: UIColor.adOrangeLighter])
        }
    }
}
