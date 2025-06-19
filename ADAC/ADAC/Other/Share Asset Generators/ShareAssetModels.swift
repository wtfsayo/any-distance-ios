// Licensed under the Any Distance Source-Available License
//
//  ShareAssetModels.swift
//  ADAC
//
//  Created by Daniel Kuntz on 2/16/22.
//

import UIKit

final class ShareVideos {
    var noWatermarkInstagramStoryUrl: URL? = nil
    let instagramStoryUrl: URL
    @Published var squareUrl: URL? = nil
    @Published var squareVideoProgress: Float = 0.0
    private let willRenderSquareVideo: Bool
    
    init(instagramStoryUrl: URL, willRenderSquareVideo: Bool) {
        self.instagramStoryUrl = instagramStoryUrl
        self.willRenderSquareVideo = willRenderSquareVideo
    }

    func videoUrl(forPageIdx idx: Int) -> URL? {
        if let squareUrl = squareUrl {
            return [instagramStoryUrl, squareUrl][idx]
        }
        return idx == 0 ? instagramStoryUrl : nil
    }

    var numberOfItems: Int {
        return willRenderSquareVideo ? 2 : 1
    }
}

struct ShareImages {
    var base: UIImage
    var instagramStory: UIImage
    var instagramFeed: UIImage
    var twitter: UIImage

    func image(forPageIdx idx: Int) -> UIImage {
        return [instagramStory, twitter, instagramFeed][idx]
    }
}
