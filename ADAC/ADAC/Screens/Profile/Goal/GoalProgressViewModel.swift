// Licensed under the Any Distance Source-Available License
//
//  GoalProgressViewModel.swift
//  ADAC
//
//  Created by Daniel Kuntz on 7/9/23.
//

import SwiftUI
import SwiftUIX
import Combine

class GoalProgressViewModel: NSObject, ObservableObject {
    @ObservedObject var goal: Goal

    @Published var data: [Float] = []
    @Published var xLabels: [(idx: Int, string: String)] = []
    @Published var fullDataCount: Int = 0
    @Published var dataMaxValue: Float = 0
    @Published var weeklyAverage: Float?
    @Published var weeklyAverageUnit: String?
    @Published var goalState: GoalState = .onTrack

    var distancePerWeekToStayOnTrack: Int {
        let target = goal.targetDistanceInSelectedUnit
        let current = goal.distanceInSelectedUnit
        return Int(((target - current) / Float(goal.endDate.timeIntervalSince(Date()) / 86400.0 / 7.0)).rounded())
    }

    private var observers: Set<AnyCancellable> = []

    init(goal: Goal) {
        self.goal = goal
        super.init()

        self.goal.objectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.objectWillChange.send()
                    self?.load()
                }
            }.store(in: &observers)

        self.load()
    }

    func load() {
        if goal.markAsCompletedIfNecessary() {
            UserManager.shared.updateCurrentUser()
        }

        Task(priority: .userInitiated) {
            do {
                let field = \Activity.distance
                let store = HealthKitActivitiesStore.shared
                let (weeklyAvg, data) = try await store.getHistoricalData(for: goal, field: field)
                let convertedData = data.map { UnitConverter.meters($0, toUnit: goal.unit) }

                let startDate = Calendar.current.startOfDay(for: goal.startDate)
                let endDate = Calendar.current.startOfDay(for: goal.endDate)

                await MainActor.run {
                    self.fullDataCount = Int((endDate.timeIntervalSince(startDate) / 86400.0).rounded(.up))
                    self.data = convertedData
                    self.dataMaxValue = max(convertedData.last ?? 0, goal.targetDistanceInSelectedUnit)

                    self.weeklyAverage = UnitConverter.meters(weeklyAvg, toUnit: goal.unit)
                    self.weeklyAverageUnit = goal.unit.abbreviation

                    let curProgress = convertedData.last ?? 0.0
                    let onTrackProgress = goal.targetDistanceInSelectedUnit * Float(Calendar.current.startOfDay(for: Date()).timeIntervalSince(startDate) / (endDate.timeIntervalSince(startDate)))

                    if Date() >= goal.endDate,
                       let completionDistanceMeters = goal.completionDistanceMeters {
                        if completionDistanceMeters < goal.distanceMeters {
                            self.goalState = .missed
                        } else {
                            self.goalState = .completed
                        }
                    } else if onTrackProgress == 0.0 {
                        self.goalState = .onTrack
                    } else {
                        switch curProgress / onTrackProgress {
                        case 0..<0.8:
                            self.goalState = .notOnTrack
                        case 0.8..<1.0:
                            self.goalState = .almostOnTrack
                        default:
                            self.goalState = .onTrack
                        }
                    }

                    var labels: [(idx: Int, string: String)] = []
                    for i in 0...4 {
                        let idx = Int((Float(i) / 4.0) * Float(fullDataCount-1))
                        let date = Calendar.current.date(byAdding: .day, value: idx, to: startDate)!
                        labels.append((idx: idx, string: date.formatted(withFormat: "MMM d")))
                    }
                    self.xLabels = labels
                }
            }
        }
    }
}

extension GoalProgressViewModel {
    enum GoalState: String {
        case onTrack = "On Track"
        case almostOnTrack = "Almost On Track"
        case notOnTrack = "Not On Track"
        case completed = "Completed"
        case missed = "Missed"

        func message(with distanceString: String) -> String {
            switch self {
            case .onTrack:
                return "Looks like you are on track!\nKeep going for at least \(distanceString) per week to hit your goal."
            case .almostOnTrack:
                return "Almost there!\nAim for \(distanceString) per week to hit your goal."
            case .notOnTrack:
                return "Pick up the pace!\nYou'll need \(distanceString) per week to hit your goal."
            case .completed:
                return "Great job! You completed your goal."
            case .missed:
                return "So close! Try setting an easier goal next time."
            }
        }

        var symbolName: SFSymbolName {
            switch self {
            case .onTrack:
                return .arrowUpRightCircleFill
            case .almostOnTrack:
                return .arrowRightToLineCircleFill
            case .notOnTrack:
                return .arrowDownRightCircleFill
            case .completed:
                return .checkmarkCircleFill
            case .missed:
                return .xmarkCircleFill
            }
        }

        var color: Color {
            switch self {
            case .onTrack:
                return .goalGreen
            case .almostOnTrack:
                return .adYellow
            case .notOnTrack:
                return .goalOrange
            case .completed:
                return .goalGreen
            case .missed:
                return Color(uiColor: RecordingGoalType.time.lighterColor)
            }
        }
    }
}
