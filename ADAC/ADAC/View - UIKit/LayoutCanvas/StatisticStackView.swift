// Licensed under the Any Distance Source-Available License
//
//  StatisticStackView.swift
//  StatisticStackView
//
//  Created by Daniel Kuntz on 8/3/21.
//

import UIKit
import PureLayout

final class StatisticStackView: UIStackView {

    // MARK: - Variables

    private(set) var statisticViews: [StatisticType: StatisticView] = [:]
    private var heightConstraint: NSLayoutConstraint!
    private var visibleStatisticsCount = 4
    private var statisticSpacing: CGFloat = 14.0
    private var hasAddedStatisticViews: Bool = false

    // MARK: - Setup

    override func awakeFromNib() {
        super.awakeFromNib()

        alignment = .fill
        distribution = .equalSpacing
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        heightConstraint = constraints.first(where: {
            $0.firstAttribute == .height && $0.relation == .equal
        })!
    }

    private func addStatisticViews(for activity: Activity) {
        let stats = StatisticType.possibleStats(for: activity)

        for type in stats {
            let view = StatisticView()
            view.alpha = 0.0
            view.isHidden = true
            addArrangedSubview(view)

            statisticViews[type] = view
        }

        hasAddedStatisticViews = true
    }

    // MARK: - Public Functions

    func setStatistics(fromActivity activity: Activity) {
        if !hasAddedStatisticViews {
            addStatisticViews(for: activity)
        }

        statisticViews[.distance]?.set(mainLabelText: "\(activity.distanceInUserSelectedUnit.rounded(toPlaces: 1))",
                                       secondaryLabelText: ADUser.current.distanceUnit.fullName.uppercased(),
                                       superscriptLabelText: "")

        statisticViews[.time]?.set(mainLabelText: activity.movingTime.timeFormatted(),
                                   secondaryLabelText: (activity.movingTime) >= 3600 ? "HOURS" : "MINUTES",
                                   superscriptLabelText: "")

        statisticViews[.elevationGain]?.set(mainLabelText: "\(activity.elevationGainInUserSelectedUnit.rounded(toPlaces: 1))",
                                            secondaryLabelText: "ELEVATION GAIN",
                                            superscriptLabelText: ADUser.current.distanceUnit == .miles ? "FT" : "M")

        statisticViews[.activeCal]?.set(mainLabelText: "\(Int(activity.activeCalories.rounded()))",
                                        secondaryLabelText: "ACTIVE CAL",
                                        superscriptLabelText: "KCAL")

        let unit = ADUser.current.distanceUnit.abbreviation.uppercased()
        if activity.activityType.shouldShowSpeedInsteadOfPace {
            statisticViews[.pace]?.set(mainLabelText: "\(activity.averageSpeedInUserSelectedUnit.rounded(toPlaces: 1))",
                                       secondaryLabelText: "AVERAGE SPEED",
                                       superscriptLabelText: ADUser.current.distanceUnit.speedAbbreviation.uppercased())
        } else {
            statisticViews[.pace]?.set(mainLabelText: activity.paceInUserSelectedUnit.timeFormatted(),
                                       secondaryLabelText: "PACE",
                                       superscriptLabelText: "/" + unit)
        }
    }

    func setStatistics(fromStepCount stepCount: DailyStepCount) {
        if !hasAddedStatisticViews {
            addStatisticViews(for: stepCount)
        }

        statisticViews[.stepCount]?.set(mainLabelText: stepCount.formattedCount,
                                        secondaryLabelText: "STEPS",
                                        superscriptLabelText: "")

        
        Task {
            if let distance = await stepCount.distanceForStartDate {
                statisticViews[.distance]?.set(mainLabelText: "\(distance.rounded(toPlaces: 1))",
                                               secondaryLabelText: ADUser.current.distanceUnit.fullName.uppercased(),
                                               superscriptLabelText: "")
            }
        }
    }

    func toggleStatistic(_ type: StatisticType, on: Bool? = nil, animated: Bool = true) {
        let enabled: Bool = {
            if let on = on {
                return on
            }

            return statisticViews[type]?.isHidden ?? true
        }()
        
        let containerHeight = (arrangedSubviews.first as? StatisticView)?.finalContentHeight ?? 53.0
        let animationsBlock = {
            self.statisticViews[type]?.isHidden = !enabled
            self.statisticViews[type]?.alpha = enabled ? 1.0 : 0.0
            self.visibleStatisticsCount = self.arrangedSubviews.reduce(0, { $0 + ($1.isHidden ? 0 : 1) })
            self.layoutIfNeeded()

            let newHeight = CGFloat(self.visibleStatisticsCount) * containerHeight + CGFloat(self.visibleStatisticsCount - 1) * self.statisticSpacing
            self.heightConstraint.constant = newHeight
            self.superview?.layoutIfNeeded()
        }

        if animated {
            UIView.animate(withDuration: 0.3,
                           delay: 0.0,
                           options: [.curveEaseInOut, .beginFromCurrentState],
                           animations: animationsBlock,
                           completion: nil)
        } else {
            animationsBlock()
        }
    }

    func setFont(_ font: ADFont) {
        for view in statisticViews.values {
            view.font = font
        }
    }

    func setStatisticAlignment(_ alignment: StatisticAlignment, animated: Bool = true) {
        for view in statisticViews.values {
            view.setAlignment(alignment: alignment, animated: animated)
        }
    }

    func setPalette(_ palette: Palette, animated: Bool = true) {
        for view in statisticViews.values {
            view.setPalette(palette, animated: animated)
        }
    }

    func statisticEnabled(_ statistic: StatisticType) -> Bool {
        return !(statisticViews[statistic]?.isHidden ?? true)
    }
}
