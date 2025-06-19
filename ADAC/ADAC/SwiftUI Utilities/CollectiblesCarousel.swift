// Licensed under the Any Distance Source-Available License
//
//  CollectiblesCarousel.swift
//  ADAC
//
//  Created by Daniel Kuntz on 1/20/23.
//

import SwiftUI

struct CollectiblesCarousel: UIViewRepresentable {
    var screenName: String?
    var collectibles: [Collectible] = []
    var areCurrentUsersCollectibles: Bool = true

    func makeUIView(context: Context) -> CollectibleTableViewCell {
        if let cell = Bundle.main.loadNibNamed("CollectibleTableViewCell", owner: nil)?[0] as? CollectibleTableViewCell {
            cell.setCollectibles(collectibles, earned: areCurrentUsersCollectibles)
            cell.delegate = context.coordinator
            context.coordinator.cell = cell
            let tapGR = UITapGestureRecognizer(target: context.coordinator,
                                               action: #selector(Coordinator.carouselTapped(_:)))
            tapGR.cancelsTouchesInView = false
            cell.addGestureRecognizer(tapGR)
            return cell
        }

        return CollectibleTableViewCell()
    }

    func updateUIView(_ uiView: CollectibleTableViewCell, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(carousel: self)
    }

    final class Coordinator: NSObject, CollectibleTableViewCellDelegate {
        var carousel: CollectiblesCarousel
        var cell: CollectibleTableViewCell?
        private var generator = UIImpactFeedbackGenerator(style: .medium)

        init(carousel: CollectiblesCarousel) {
            self.carousel = carousel
        }

        func didSelectCollectible(_ collectible: Collectible) {
            if let screenName = carousel.screenName {
                Analytics.logEvent("Collectible Tapped", screenName, .buttonTap,
                                   withParameters: ["collectible": collectible.type.rawValue])
            }

            if let vc = UIStoryboard(name: "Collectibles",
                                     bundle: nil).instantiateViewController(withIdentifier: "collectibleDetail") as? CollectibleDetailViewController {
                if let earnedCollectible = ADUser.current.collectibles.first(where: { $0.type.rawValue == collectible.type.rawValue }) {
                    vc.collectible = earnedCollectible
                    vc.collectibleEarned = true
                } else {
                    vc.collectible = collectible
                    vc.collectibleEarned = false
                }
                UIApplication.shared.topmostViewController?.present(vc, animated: true)
                generator.impactOccurred()
            }
        }

        @objc func carouselTapped(_ gr: UITapGestureRecognizer) {
            guard let cell = cell else {
                return
            }

            let collectible = cell.collectibles[Int(cell.pageControl.pageIdx.rounded())]
            let location = gr.location(in: cell)
            if collectible.itemType == .medal &&
               carousel.areCurrentUsersCollectibles &&
               location.y <= 42.0 &&
               location.x >= 250.0 {
                Analytics.logEvent("Wear Medal Tapped", carousel.screenName ?? "Collectible Cell", .buttonTap)
                let arViewController = ARMedalViewController(collectible, delegate: nil)
                UIApplication.shared.topViewController?.present(arViewController, animated: true, completion: nil)
            } else {
                didSelectCollectible(collectible)
            }
        }
    }
}
