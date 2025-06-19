// Licensed under the Any Distance Source-Available License
//
//  GoalTableViewCell.swift
//  ADAC
//
//  Created by Daniel Kuntz on 2/20/21.
//

import UIKit
import Combine

/// Table view cell for a goal in AllGoalsViewController
final class GoalTableViewCell: UITableViewCell {

    // MARK: - Constants

    static let reuseId = "goalCell"

    // MARK: - Outlets

    @IBOutlet weak var distanceLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var progressIndicator: CircularGoalProgressIndicator!
    @IBOutlet weak var activityTypeImageView: UIImageView!
    @IBOutlet weak var roundedView: ContinuousCornerView!

    // MARK: - Variables

    private var subscribers: Set<AnyCancellable> = []

    // MARK: - Setup

    override func awakeFromNib() {
        super.awakeFromNib()
        progressIndicator.style = .small
    }

    func setGoal(_ goal: Goal) {
        subscribers.removeAll()
        update(for: goal)

        goal.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.update(for: goal)
            }.store(in: &subscribers)
    }

    private func update(for goal: Goal) {
        let currentDistance = goal.distanceInSelectedUnit
        let targetDistance = goal.targetDistanceInSelectedUnit

        let unitString = goal.unit.abbreviation.uppercased()
        distanceLabel.text = String(currentDistance) + " / " +
        String(Int(targetDistance.rounded())) + unitString
        dateLabel.text = "By " + goal.formattedDate
        progressIndicator.progress = CGFloat(currentDistance / targetDistance)
        activityTypeImageView.image = goal.activityType.glyph

        roundedView.backgroundColor = goal.isCompleted ? UIColor(realRed: 23, green: 23, blue: 23) :
        UIColor(realRed: 37, green: 37, blue: 37)
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        UIView.animate(withDuration: 0.2) {
            self.alpha = highlighted ? 0.6 : 1
            self.transform = highlighted ? CGAffineTransform(scaleX: 0.95, y: 0.95) : .identity
        }
    }
}
