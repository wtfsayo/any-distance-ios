// Licensed under the Any Distance Source-Available License
//
//  RSSParser.swift
//  ADAC
//
//  Created by Daniel Kuntz on 4/12/21.
//

import Foundation
import FeedKit

final class RSSParser {

    // MARK: - Singleton

    static let shared = RSSParser()

    // MARK: - Constants

    let feedUrl: URL = URL(string: "https://anydistance.exposure.co/feed.rss")!

    // MARK: - Variables

    private(set) var feedItems: [FeedItem] = NSUbiquitousKeyValueStore.default.feedItems {
        didSet {
            NSUbiquitousKeyValueStore.default.feedItems = feedItems
        }
    }

    // MARK: - Get Feed Items
    
    func latestFeedItems() async throws -> [FeedItem] {
        let parser = FeedParser(URL: feedUrl)

        let items: [FeedItem] = try await withCheckedThrowingContinuation { continuation in
            parser.parseAsync(queue: DispatchQueue.global(qos: .userInitiated)) { (result) in
                switch result {
                case .success(let feed):
                    var newFeedItems: [FeedItem] = []
                    if let rss = feed.rssFeed, let items = rss.items {
                        for item in items {
                            guard let imageUrlLowerBound = item.description?.range(of: "http")?.lowerBound else {
                                continue
                            }
                            
                            guard let imageUrlUpperBound = item.description?[imageUrlLowerBound...].firstIndex(of: ";") else {
                                continue
                            }
                            
                            let imageUrlString = String(item.description?[imageUrlLowerBound..<imageUrlUpperBound] ?? "")
                            guard let imageUrl = URL(string: imageUrlString) else {
                                continue
                            }
                            
                            guard let link = item.link, let linkURL = URL(string: link) else {
                                continue
                            }
                            
                            let feedItem = FeedItem(sortDate: item.pubDate, title: item.title, link: linkURL, coverImageURL: imageUrl)
                            newFeedItems.append(feedItem)
                        }
                    }
                    
                    continuation.resume(returning: newFeedItems)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }

        if !iAPManager.shared.hasSuperDistanceFeatures {
            self.feedItems = items.filter { !$0.isSuperDistanceOnly }
        } else {
            self.feedItems = items
        }
        
        return items
    }

}
