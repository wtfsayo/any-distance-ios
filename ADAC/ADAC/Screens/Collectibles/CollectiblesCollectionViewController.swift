// Licensed under the Any Distance Source-Available License
//
//  CollectiblesCollectionViewController.swift
//  ADAC
//
//  Created by Daniel Kuntz on 1/5/21.
//

import UIKit
import Combine
import AuthenticationServices

/// Collection view controller that shows a list of all collectibles organized by section, earned
/// and unearned. Includes found items and medals.
final class CollectiblesCollectionViewController: UICollectionViewController, UICollectionViewDelegateFlowLayout {

    // MARK: - Variables

    let screenName = "Collectibles"
    private let generator = UIImpactFeedbackGenerator(style: .medium)

    fileprivate var sections: [CollectibleSection] = []
    fileprivate var subscribers: Set<AnyCancellable> = []
    fileprivate var shouldReload: Bool = false

    // MARK: - Constants

    let cellsPerRow: CGFloat = 4
    let leftRightMargin: CGFloat = 15
    let cellSpacing: CGFloat = 18

    // MARK: - Setup

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationController?.navigationBar.setValue(true, forKey: "hidesShadow")
        extendedLayoutIncludesOpaqueBars = true

        collectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 20, right: 0)
        collectionView.scrollIndicatorInsets = UIEdgeInsets(top: 0, left: 0, bottom: 20, right: 0)
        collectionView.register(SectionHeader.self,
                                forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                                withReuseIdentifier: "header")

        collectionView.refreshControl = UIRefreshControl()
        collectionView.refreshControl?.addTarget(self, action: #selector(pullNewData), for: .valueChanged)

        let image = UIImage(systemName: "xmark.circle.fill",
                            withConfiguration: UIImage.SymbolConfiguration(font: .systemFont(ofSize: 15,
                                                                                             weight: .semibold)))!
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: image,
                                                            style: .plain,
                                                            target: self,
                                                            action: #selector(closeTapped))

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(reloadCollectibles),
                                               name: Notification.goalTypeChanged.name,
                                               object: nil)

        let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout
        layout?.sectionHeadersPinToVisibleBounds = true

        ReloadPublishers.activitiesTableViewReloaded
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.shouldReload = true
            }.store(in: &subscribers)

        ReloadPublishers.collectibleGranted
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.shouldReload = true
            }.store(in: &subscribers)

        reloadCollectibles()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tabBarController?.tabBar.shadowImage = UIImage(named: "tabbar_shadow")
        if shouldReload {
            print("reloading")
            reloadCollectibles()
            shouldReload = false
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Analytics.logEvent(screenName, screenName, .screenViewed)
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    @objc func pullNewData() {
        Task {
            await CollectibleLoader.shared.loadCollectibles()
            if ADUser.current.hasRegistered {
                await UserManager.shared.fetchCurrentUser()
            }
            DispatchQueue.main.async {
                self.reloadCollectibles()
                self.collectionView.refreshControl?.endRefreshing()
            }
        }
    }

    private func name(forSection section: Int) -> String {
        return sections.sorted(by: { $0.sortOrder < $1.sortOrder })[safe: section]?.name ?? ""
    }

    private func collectibles(forSection section: Int) -> [AggregateCollectible] {
        return sections.sorted(by: { $0.sortOrder < $1.sortOrder })[safe: section]?.collectibles ?? []
    }

    private func collectible(atIndexPath indexPath: IndexPath) -> AggregateCollectible? {
        return collectibles(forSection: indexPath.section)[safe: indexPath.item]
    }

    @objc func reloadCollectibles() {
        sections = []

        func addCollectible(_ collectible: Collectible, forSectionName name: String, earned: Bool) {
            let aggregate = AggregateCollectible(collectible: collectible, count: earned ? 1 : 0)

            if let idx = sections.firstIndex(where: { $0.name == name }) {
                for (i, aggregate) in sections[idx].collectibles.enumerated() {
                    if aggregate.collectible.type == collectible.type {
                        sections[idx].collectibles[i].count += 1
                        sections[idx].collectibles[i].collectible = collectible
                        return
                    }
                }

                sections[idx].addCollectible(collectible: aggregate)
            } else {
                let section = CollectibleSection(name: name, sortOrder: collectible.sortOrder, collectibles: [aggregate])
                sections.append(section)
            }
        }

        for collectible in Collectible.all {
            addCollectible(collectible, forSectionName: collectible.sectionName, earned: false)
        }

        for collectible in ADUser.current.visibleCollectibles {
            addCollectible(collectible, forSectionName: collectible.sectionName, earned: true)
        }

        collectionView.reloadData()
    }

    override func collectionView(_ collectionView: UICollectionView,
                                 cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let collectiblesForType = collectibles(forSection: indexPath.section)
        guard let aggregateCollectible = collectiblesForType[safe: indexPath.item] else {
            return UICollectionViewCell()
        }

        switch aggregateCollectible.collectible.itemType {
        case .medal:
            if let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CollectibleCollectionViewCell.reuseId,
                                                             for: indexPath) as? CollectibleCollectionViewCell {
                cell.setAggregateCollectible(aggregateCollectible)
                return cell
            }
        case .foundItem:
            if let cell = collectionView.dequeueReusableCell(withReuseIdentifier: Collectible3DCollectionViewCell.reuseId,
                                                             for: indexPath) as? Collectible3DCollectionViewCell {
                cell.setAggregateCollectible(aggregateCollectible)
                return cell
            }
        }

        return UICollectionViewCell()
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)

        if let aggregateCollectible = collectible(atIndexPath: indexPath) {
            generator.impactOccurred()
            performSegue(withIdentifier: "collectiblesToCollectibleDetail", sender: aggregateCollectible)
            Analytics.logEvent("Collectible Tapped", screenName, .buttonTap,
                               withParameters: ["collectible": aggregateCollectible.collectible.type.rawValue])
        }
    }
    
    func presentCollectible(collectibleTypeRawValue: String) {
        guard let section = sections.first(where: { $0.collectibles.contains(where: { $0.collectible.type.rawValue == collectibleTypeRawValue })}),
        let aggregateCollectible = section.collectibles.first(where: { $0.collectible.type.rawValue == collectibleTypeRawValue }) else {
            return
        }
        
        performSegue(withIdentifier: "collectiblesToCollectibleDetail", sender: aggregateCollectible)
        Analytics.logEvent("Collectible Opened", screenName, .buttonTap,
                           withParameters: ["collectible": aggregateCollectible.collectible.type.rawValue])
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {

        let idxLower = Int(indexPath.row / 4) * 4
        let idxUpper = idxLower + 4
        let cellSize = collectibleCellSize()
        let expandedCellSize = collectibleCellSize(expanded: true)
        var maxHeightInRow: CGFloat = cellSize.height

        for i in idxLower..<idxUpper {
            let idx = IndexPath(item: i, section: indexPath.section)
            if let collectible = collectible(atIndexPath: idx) {
                maxHeightInRow = max(collectible.count <= 1 ? cellSize.height : expandedCellSize.height, maxHeightInRow)
            }
        }

        return CGSize(width: cellSize.width, height: maxHeightInRow)
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        let cellWidth = collectibleCellSize().width
        return (view.bounds.width - (4.0 * cellWidth) - (2.0 * leftRightMargin)) / 3.0
    }

    func collectibleCellSize(expanded: Bool = false) -> CGSize {
        let width = (view.bounds.width - (leftRightMargin * 2) - (cellSpacing * (cellsPerRow - 1))) / cellsPerRow
        let height = width * 1.53 + (expanded ? 27 : 0)
        return CGSize(width: width, height: height)
    }

    override func collectionView(_ collectionView: UICollectionView,
                                 viewForSupplementaryElementOfKind kind: String,
                                 at indexPath: IndexPath) -> UICollectionReusableView {
        if kind == UICollectionView.elementKindSectionHeader {
            let header = collectionView.dequeueReusableSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader,
                                                                         withReuseIdentifier: "header",
                                                                         for: indexPath) as? SectionHeader
            let title = name(forSection: indexPath.section)
            header?.headerView.setTitle(title)
            return header ?? UICollectionReusableView()
        }

        return UICollectionReusableView()
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        referenceSizeForHeaderInSection section: Int) -> CGSize {
        return CGSize(width: view.bounds.width, height: 60)
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return collectibles(forSection: section).count
    }

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return sections.count
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "collectiblesToCollectibleDetail",
           let detailVC = segue.destination as? CollectibleDetailViewController,
           let aggregateCollectible = sender as? AggregateCollectible {
            detailVC.collectible = aggregateCollectible.collectible
            detailVC.collectibleEarned = aggregateCollectible.count > 0
        }
    }
}

/// Header text for sections in CollectiblesCollectionViewController.
fileprivate final class SectionHeader: UICollectionReusableView {
    var headerView: TableViewHeader!

    override init(frame: CGRect) {
        super.init(frame: frame)

        headerView = TableViewHeader(title: "")
        addSubview(headerView)
        headerView.autoPinEdgesToSuperviewEdges()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}

/// Struct representing a section of collectibles.
fileprivate struct CollectibleSection {
    var name: String
    var sortOrder: Int
    var collectibles: [AggregateCollectible]

    mutating func addCollectible(collectible: AggregateCollectible) {
        collectibles.append(collectible)

        if self.name == "Special" {
            collectibles.sort(by: { $0.collectible.dateEarned > $1.collectible.dateEarned })
        } else if self.name != "Activities" && self.name != "Total Distance" {
            collectibles.sort(by: { $0.collectible.type.rawValueWithoutType < $1.collectible.type.rawValueWithoutType })
        }
    }
}

/// Struct representing a collectible that has been earned multiple times.
struct AggregateCollectible {
    var collectible: Collectible
    var count: Int
}

/// Convenience extension to get a list of all Collectibles regardless of earned state.
extension Collectible {
    static var all: [Collectible] {
        var array: [Collectible] = []

        for special in SpecialMedal.allCases {
            let date = special.date?.endDate() ?? Date(timeIntervalSince1970: 0)
            if Date() < date {
                let collectible = Collectible(type: CollectibleType.special(special), dateEarned: date)
                array.append(collectible)
            }
        }

        for location in CityMedal.allCases {
            let collectible = Collectible(type: CollectibleType.location(location), dateEarned: Date())
            array.append(collectible)
        }

        for state in StateMedal.allCases {
            let collectible = Collectible(type: CollectibleType.locationstate(state), dateEarned: Date())
            array.append(collectible)
        }

        for medalNumber in 1..<15 {
            let collectible = Collectible(type: CollectibleType.goal(medalNumber), dateEarned: Date())
            array.append(collectible)
        }

        for remote in CollectibleLoader.shared.remoteCollectibles.values where remote.isVisibleBeforeBeingEarned {
            // If we're past the end date, don't show it in the list.
            if let endDate = remote.endDate, endDate < Date() {
                continue
            }

            // If the Collectible requires SD and we're not subscribed, don't show it in the list.
            if remote.superDistanceRequired && !iAPManager.shared.hasSuperDistanceFeatures {
                continue
            }

            // If they opted out of collaborations, don't show it in the list.
            if remote.sectionName == "Collaborations" && !NSUbiquitousKeyValueStore.default.shouldShowCollaborationCollectibles {
                continue
            }
            
            let collectible = Collectible(type: .remote(remote), dateEarned: Date())
            array.append(collectible)
        }

        let distances = DistanceMedal.allCases.filter {
            ($0.associatedUnit ?? ADUser.current.distanceUnit) == ADUser.current.distanceUnit
        }

        for distance in distances {
            if distance.unitlessDistance <= DistanceMedal.activityCollectibleMaximumDistance {
                let activityCollectible = Collectible(type: CollectibleType.activity(distance), dateEarned: Date())
                array.append(activityCollectible)
            } else if distance.unitlessDistance >= DistanceMedal.totalDistanceCollectibleMinimumDistance {
                let totalDistanceCollectible = Collectible(type: CollectibleType.totalDistance(distance), dateEarned: Date())
                array.append(totalDistanceCollectible)
            }
        }

        return array
    }
}
