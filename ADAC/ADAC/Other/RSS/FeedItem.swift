// Licensed under the Any Distance Source-Available License
//
//  FeedItem.swift
//  ADAC
//
//  Created by Daniel Kuntz on 4/12/21.
//

import Foundation

final class FeedItem: Codable, ActivityTableViewDataClass {
    var sortDate: Date
    var title: String
    var link: URL
    var coverImageURL: URL

    var isSuperDistanceOnly: Bool {
        return link.absoluteString.contains("super-distance")
    }

    init(sortDate: Date?, title: String?, link: URL?, coverImageURL: URL?) {
        self.link = link ?? URL(string: "http://anydistance.club")!
        // Set sortDate to the end of the day for the RSS date so it always appears at the top of
        // that day's list of activities.
        if let sortDate = sortDate {
            let components = Calendar.current.dateComponents([.day, .month, .year], from: sortDate)
            let dateFromComponents = Calendar.current.date(from: components)
            self.sortDate = dateFromComponents?.addingTimeInterval((60*60*24)-1) ?? Date()
        } else {
            self.sortDate = Date()
        }
        self.title = title ?? ""
        self.coverImageURL = coverImageURL ?? URL(string: "https://anydistance.club/img/any-distance-wordmark.png")!
    }
}
