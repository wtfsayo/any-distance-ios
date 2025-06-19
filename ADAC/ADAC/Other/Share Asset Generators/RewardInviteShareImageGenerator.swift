// Licensed under the Any Distance Source-Available License
//
//  RewardInviteShareImageGenerator.swift
//  ADAC
//
//  Created by Daniel Kuntz on 1/23/23.
//

import UIKit

final class RewardInviteShareImageGenerator {
    static func createImage(withCode code: String) async -> UIImage {
        return await withCheckedContinuation { continuation in
            Task(priority: .userInitiated) {
                let codeImage = image(fromText: code)
                let bgImage = UIImage(named: "reward_invite")!
                let renderer = UIGraphicsImageRenderer(size: bgImage.size)
                let image = renderer.image { ctx in
                    bgImage.draw(at: .zero)
                    codeImage.draw(at: CGPoint(x: bgImage.size.width / 2 - codeImage.size.width / 2,
                                               y: 1420))
                }
                continuation.resume(returning: image)
            }
        }
    }

    private static func image(fromText text: String) -> UIImage {
        guard let font = ADFont.mono.primaryFont?.withSize(100) else {
            return UIImage()
        }

        let size = NSString(string: text)
            .size(withAttributes: [.font : font,
                                   .foregroundColor : UIColor.adOrangeLighter])
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            NSString(string: text).draw(at: .zero,
                                        withAttributes: [.font: font,
                                                         .foregroundColor: UIColor.adOrangeLighter])
        }
    }
}
