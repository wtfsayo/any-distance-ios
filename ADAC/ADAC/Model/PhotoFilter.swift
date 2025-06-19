// Licensed under the Any Distance Source-Available License
//
//  PhotoFilter.swift
//  ADAC
//
//  Created by Daniel Kuntz on 5/7/21.
//

import UIKit
//import HipstaKit

/// NOTE: Any Distance used HipstaKit by Hipstamatic for photo filters. Since that's closed source, we can't include it here.
/// Reach out to Lucas Buick (lucas@hipstamatic.com) for HipstaKit licensing options.

enum PhotoFilter: String, CaseIterable, Codable {
    case none = "noFilter" // legacy name

    case film_ad_daydream
    case film_ad_sprocket
    case film_bw3
    case lens_ad_claire
    case lens_beard
    case lens_ad_pena
    case film_bwp
    case lens_ad_jack
    case lens_ad_muir

//    case film_aodx
//    case film_eagle
//    case film_poncey
//    case lens_hekla
//    case lens_ranger

//    var effect: HKEffect? {
//        guard let url = Bundle.main.url(forResource: rawValue, withExtension: "hipstaGear"),
//              let effect = try? HKEffect(url: url) else {
//            return nil
//        }
//
//        return effect
//    }

    var displayName: String {
        switch self {
        case .none:
            return "No Effect"
        case .film_ad_sprocket:
            return "Sprocket"
        case .lens_ad_claire:
            return "Vienna"
        case .lens_beard:
            return "Coleford"
        case .lens_ad_pena:
            return "Wynwood"
        case .film_bwp:
            return "Edgewood"
        case .film_bw3:
            return "Long Island"
        case .film_ad_daydream:
            return "Daydream"
        case .lens_ad_jack:
            return "Telegraph"
        case .lens_ad_muir:
            return "Sequoia"
        }
    }

    var icon: UIImage? {
        switch self {
        case .none:
            return nil
        case .film_ad_sprocket:
            return UIImage(named: "sprocket")
        case .lens_ad_claire:
            return UIImage(named: "vienna")
        case .lens_beard:
            return UIImage(named: "coleford")
        case .lens_ad_pena:
            return UIImage(named: "wynwood")
        case .film_bwp:
            return UIImage(named: "edgewood")
        case .film_bw3:
            return UIImage(named: "long_island")
        case .film_ad_daydream:
            return UIImage(named: "daydream")
        case .lens_ad_jack:
            return UIImage(named: "telegraph")
        case .lens_ad_muir:
            return UIImage(named: "sequoia")
        }
    }

//    func applied(to image: UIImage) async throws -> UIImage? {
//        guard self != .none, let effect = effect else {
//            return nil
//        }
//        
//        let filteredImage: UIImage = try await withCheckedThrowingContinuation { continuation in
//            let originalOrientation = image.imageOrientation
//            HKADImageProcessor.shared.process(image: image, effect: effect) { result in
//                switch result {
//                case .success(let image):
//                    if let cgImage = image.cgImage {
//                        let correctedOrientationImage = UIImage(cgImage: cgImage,
//                                                                scale: image.scale,
//                                                                orientation: originalOrientation)
//                        continuation.resume(returning: correctedOrientationImage)
//                    } else {
//                        continuation.resume(returning: image)
//                    }
//                case .failure(let error):
//                    continuation.resume(throwing: error)
//                }
//            }
//        }
//        
//        return filteredImage
//    }
}
