// Licensed under the Any Distance Source-Available License
//
//  Fill.swift
//  ADAC
//
//  Created by Daniel Kuntz on 11/12/21.
//

import UIKit

enum FillCollection: String, CaseIterable {
    case photos, gradients
    
    var fills: [Fill] {
        Fill.allCases.filter { $0.collection == self }
    }
    
    var name: String {
        rawValue.capitalized
    }
}

enum Fill: String, CaseIterable, Codable {
    case deep, emerald, solar, violet
    case being, berry, dayglow, frost, moon, pool, tide
    case clouds, fall, forest, hills, sunset, track, waves
    
    var name: String {
        rawValue.capitalized
    }
    
    var collectionName: String {
        collection.name
    }
    
    var collection: FillCollection {
        switch self {
        case .deep, .emerald, .solar, .violet,
             .being, .berry, .dayglow, .frost, .moon, .pool, .tide:
            return .gradients
        case .clouds, .fall, .forest, .hills, .sunset, .track, .waves:
            return .photos
        }
    }
    
    var image: UIImage? {
        UIImage(named: rawValue.capitalized)
    }
    
    var imageThumbnail: UIImage? {
        UIImage(named: "\(rawValue.capitalized)_thumbnail")
    }
}
