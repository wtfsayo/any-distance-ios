// Licensed under the Any Distance Source-Available License
//
//  GoalProgressView.swift
//  ADAC
//
//  Created by Daniel Kuntz on 7/8/23.
//

import SwiftUI

fileprivate struct PostsAndActivities: View {
    struct PostOrActivity {
        var postModel: PostCellModel?
        var activity: Activity?

        var id: String {
            if let postModel = postModel {
                return postModel.post.id
            }
            return activity?.id ?? UUID().uuidString
        }

        var sortDate: Date {
            if let postModel = postModel {
                return postModel.post.creationDate
            }
            return activity?.startDate ?? Date()
        }
    }

    @ObservedObject var goal: Goal
    @State var cellData: [PostOrActivity] = []

    private func load() {
        let userPosts: [PostCellModel] = PostCache.shared.posts(forUserID: ADUser.current.id)
            .filter { post in
                post.activityType == goal.activityType &&
                post.activityStartDateUTC > goal.startDate &&
                post.activityEndDateUTC < goal.endDate
            }
            .map { PostCellModel(post: $0, screenName: "") }

        let activites: [Activity] = ActivitiesData.shared.activities
            .map { $0.activity }
            .filter { activity in
                activity.activityType == goal.activityType &&
                activity.startDate > goal.startDate &&
                activity.endDate < goal.endDate &&
                !userPosts.contains(where: { $0.post.localHealthKitID == activity.id })
            }

        var newCellData: [PostOrActivity] = []
        newCellData.append(contentsOf: activites.map { PostOrActivity(activity: $0) })
        newCellData.append(contentsOf: userPosts.map { PostOrActivity(postModel: $0) })
        newCellData.sort(by: { $0.sortDate > $1.sortDate })
        cellData = newCellData
    }

    var body: some View {
        LazyVStack(alignment: .center, spacing: 12) {
            ForEach(cellData, id: \.id) { data in
                if let postModel = data.postModel {
                    PostCell(model: postModel)
                        .padding([.leading, .trailing], 15)
                        .modifier(BlurOpacityTransition(speed: 1.5))
                } else if let activity = data.activity {
                    let id: String = {
                        guard let activity = data.activity else {
                            return "0"
                        }

                        return activity.id + (activity is CachedActivity ? "_cached" : "")
                    }()

                    ActivityCell(activity: activity) {
                        if activity is DailyStepCount {
                            let storyboard = UIStoryboard(name: "Activities", bundle: nil)
                            guard let vc = storyboard.instantiateViewController(withIdentifier: "design") as? DesignViewController else {
                                return
                            }
                            vc.viewModel = ActivityDesignViewModel(activity: activity)
                            let navigationVC = UINavigationController(rootViewController: vc)
                            navigationVC.modalPresentationStyle = .overFullScreen
                            UIApplication.shared.topViewController?.present(navigationVC, animated: true)
                        } else {
                            UIApplication.shared.topViewController?.showPostDraft(for: activity)
                        }
                    }
                    .id(id)
                    .transition(.opacity.animation(.easeInOut(duration: 0.2)))
                    .border(Color.clear) // fixes a touch down tap target bug with ScalingPressButtonStyle()
                } else {
                    EmptyView()
                }
            }

            Spacer()
                .frame(height: 25)
        }
        .padding(.top, 15)
        .onAppear {
            load()
        }
        .onChange(of: goal) { _ in
            load()
        }
        .onReceive(ActivitiesData.shared.activitiesReloadedPublisher) { _ in
            load()
        }
    }
}

fileprivate struct GoalProgressGraph: View {
    @StateObject var model: GoalProgressViewModel
    @State private var dataSwipeIdx: Int = -1
    @State private var showingOverlay: Bool = false
    var graphLrPadding: CGFloat

    var body: some View {
        VStack {
            ZStack {
                ProgressLineGraph(data: [0.0, model.goal.targetDistanceInSelectedUnit],
                                  dataMaxValue: model.dataMaxValue,
                                  fullDataCount: 2,
                                  strokeStyle: StrokeStyle(lineWidth: 2.0, lineCap: .round, dash: [0.5, 4.0]),
                                  color: Color(white: 0.4),
                                  showVerticalLine: false,
                                  showDot: false,
                                  animateProgress: false,
                                  dataSwipeIdx: .constant(-1))

                ProgressLineGraph(data: model.data,
                                  dataMaxValue: model.dataMaxValue,
                                  fullDataCount: model.fullDataCount,
                                  strokeStyle: StrokeStyle(lineWidth: 3.5, lineCap: .round),
                                  color: model.goalState.color,
                                  showVerticalLine: true,
                                  showDot: true,
                                  animateProgress: true,
                                  dataSwipeIdx: $dataSwipeIdx)
                .id(Int(model.dataMaxValue) + model.fullDataCount)
                .transition(.opacity.animation(.easeInOut(duration: 0.1)))

                let targetData: [Float] = (0..<model.fullDataCount)
                    .map { model.goal.targetDistanceInSelectedUnit * Float($0) / Float(model.fullDataCount-1) }
                ProgressLineGraphSwipeOverlay(field: \.distanceInUserSelectedUnit,
                                              data: model.data,
                                              prevPeriodData: targetData,
                                              dataFormat: { String($0.rounded(toPlaces: 1)) + model.goal.unit.abbreviation },
                                              startDate: model.goal.startDate,
                                              endDate: model.goal.endDate,
                                              prevPeriodStartDate: model.goal.startDate,
                                              prevPeriodEndDate: model.goal.endDate,
                                              alternatePrevPeriodLabel: "Target",
                                              dataSwipeIdx: $dataSwipeIdx,
                                              showingOverlay: $showingOverlay)
                .id(model.data.count)
            }
            .frame(height: 180.0)
            .padding([.leading, .trailing], graphLrPadding)

            ProgressLineGraphXLabels(labelStrings: model.xLabels,
                                     fullDataCount: model.fullDataCount,
                                     lrPadding: graphLrPadding)

            if let weeklyAverage = model.weeklyAverage,
               let weeklyAverageUnit = model.weeklyAverageUnit,
               let firstXLabel = model.xLabels.first {
                HStack {
                    Text(String(weeklyAverage.rounded(toPlaces: 1)) + String(weeklyAverageUnit.uppercased()) + " WEEKLY AVG")
                        .font(.system(size: 12.0, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                        .opacity(0.6)
                        .frame(height: 20.0)
                        .offset(y: 18.0)
                        .offset(x: (-0.5 * firstXLabel.string.width(withConstrainedHeight: .greatestFiniteMagnitude, font: UIFont.monospacedSystemFont(ofSize: 12.0, weight: .medium))) + 4.0)
                        .padding(.leading, graphLrPadding)
                        .transition(.opacity.animation(.easeInOut(duration: 0.1)))
                    Spacer()
                }
                .padding(.top, -16.0)
            }
        }
    }
}

struct GoalProgressView: View {
    @StateObject var model: GoalProgressViewModel
    @State var scrollViewOffset: CGFloat = 0.0
    @Environment(\.presentationMode) var presentationMode
    @State private var startConfetti: Bool = false
    @State private var showingDeleteAlert: Bool = false

    private let graphLrPadding: CGFloat = 25.0

    private func showGoalEdit() {
        guard let editGoalVC = UIStoryboard(name: "Goals", bundle: nil)
            .instantiateViewController(withIdentifier: "editGoal") as? EditGoalViewController else {
            return
        }

        editGoalVC.goal = model.goal
        UIApplication.shared.topViewController?.present(editGoalVC, animated: true)
    }

    var andiVideoURL: URL? = {
        let videoName = "progress-andi-\(Int.random(in: 1...5)).mp4"
        return URL(string: "https://anydistancecounts.s3-us-east-2.amazonaws.com/progress-andi/" + videoName)
    }()

    var body: some View {
        ZStack {
            ReadableScrollView(offset: $scrollViewOffset) {
                VStack(spacing: 20.0) {
                    Spacer()
                        .frame(height: UIScreen.main.safeAreaInsets.top)

                    Spacer()
                        .frame(height: 40.0)

                    HStack(spacing: 16.0) {
                        ZStack {
                            CircularGoalProgressView(style: .medium,
                                                     progress: CGFloat(model.goal.distanceInSelectedUnit / model.goal.targetDistanceInSelectedUnit))
                            .frame(width: 94.0, height: 94.0)
                            Image(model.goal.activityType.glyphName)
                                .resizable()
                                .frame(width: 44.0, height: 44.0)
                        }

                        VStack(alignment: .leading, spacing: 4.0) {
                            let distanceString = String(Int(model.goal.distanceInSelectedUnit.rounded()))
                            let targetString = String(Int(model.goal.targetDistanceInSelectedUnit.rounded()))
                            let totalStringLen = distanceString.count + targetString.count
                            let fontScaleFactor = (6.0 / CGFloat(totalStringLen)).clamped(to: 0.5...1.0)

                            HStack(alignment: .bottom, spacing: 0.0) {
                                Text(distanceString)
                                Text("/")
                                Text(targetString)
                                Text(model.goal.unit.abbreviation.uppercased())
                                    .font(.system(size: 26 * fontScaleFactor, weight: .medium, design: .monospaced))
                                    .padding(.leading, 1.0)
                                    .offset(y: -1.5)
                            }
                            .font(.system(size: 34 * fontScaleFactor, weight: .medium, design: .monospaced))

                            HStack(spacing: 3.0) {
                                Image(systemName: model.goalState.symbolName)
                                    .font(.system(size: 16.0, weight: .medium))
                                    .foregroundColor(model.goalState.color)
                                Text(model.goalState.rawValue)
                                    .font(.system(size: 14.0, weight: .medium))
                                    .foregroundColor(.white)
                            }

                            Group {
                                Text("By " + model.goal.formattedDate)
                                if model.goal.completionDistanceMeters == nil {
                                    Text(model.goal.formattedDaysLeft)
                                }
                            }
                            .font(.system(size: 14.0, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                            .opacity(0.6)
                        }

                        Spacer()
                    }
                    .padding(.leading, 15.0)

                    GoalProgressGraph(model: model, graphLrPadding: graphLrPadding)

                    ZStack {
                        HStack {
                            Spacer()
                            LoopingVideoView(videoUrl: andiVideoURL!, videoGravity: .resizeAspect)
                                .frame(width: 130.0, height: 130.0)
                                .offset(x: 8.0)
                        }

                        VStack(alignment: .leading, spacing: 7.0) {
                            HStack(spacing: 6.0) {
                                Image(systemName: .lightbulbCircleFill)
                                    .font(.system(size: 11.0, weight: .bold))
                                    .offset(y: -0.5)
                                Text("Andi Insights")
                                    .font(.system(size: 11.0, weight: .semibold, design: .monospaced))
                            }
                            .foregroundColor(.white)
                            .opacity(0.5)

                            HStack {
                                let message = model.goalState.message(with: "\(model.distancePerWeekToStayOnTrack) \(model.goal.unit.fullName)")
                                Text(message)
                                    .font(.system(size: 18.0, weight: .medium, design: .rounded))
                                    .layoutPriority(1)
                                Spacer()
                                    .frame(minWidth: 120.0)
                            }
                        }
                    }
                    .padding(.leading, 16.0)
                    .padding(.top, 8.0)

                    PostsAndActivities(goal: model.goal)
                        .padding([.leading, .trailing], -15.0)

                    Spacer()
                }
                .padding([.leading, .trailing], 15.0)
            }
            .mask {
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: UIScreen.main.safeAreaInsets.top)
                    Spacer()
                        .frame(height: 10.0)
                    Image("gradient_bottom_ease_in_out")
                        .renderingMode(.template)
                        .resizable(resizingMode: .stretch)
                        .frame(width: UIScreen.main.bounds.width, height: 50.0)
                        .foregroundColor(.black)
                    Color.black
                        .padding(.bottom, -800)
                }
            }

            VStack {
                Spacer()
                    .frame(height: UIScreen.main.safeAreaInsets.top)

                HStack {
                    if Date() >= model.goal.endDate {
                        Button {
                            showingDeleteAlert = true
                        } label: {
                            Text("Delete")
                                .font(.system(size: 15.0))
                                .foregroundColor(.red)
                                .padding()
                                .contentShape(Rectangle())
                        }
                    } else {
                        Button {
                            showGoalEdit()
                        } label: {
                            Text("Edit")
                                .font(.system(size: 15.0))
                                .padding()
                                .contentShape(Rectangle())
                        }
                    }

                    Spacer()
                    Text(model.goal.activityType.displayName)
                        .font(.presicav(size: 17))
                        .opacity(0.4)
                        .multilineTextAlignment(.center)
                    Spacer()

                    Button {
                        presentationMode.dismiss()
                    } label: {
                        Image(systemName: .xmarkCircleFill)
                            .font(.system(size: 20.0, weight: .medium))
                            .padding()
                            .contentShape(Rectangle())
                    }
                }
                .foregroundColor(.white)

                Spacer()
            }

            ConfettiSwiftUIView(confettiColors: [.adOrange, .adOrangeLighter, .adYellow, .adBrown, .black],
                                isStarted: $startConfetti)
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
        .background(Color.black)
        .alert("Are you sure you want to delete this forever?", isPresented: $showingDeleteAlert) {
            Button("Yes, Delete", role: .destructive) {
                ADUser.current.goals.removeAll(where: { $0 === self.model.goal })
                UserDefaults.appGroup.updateGoalProgress()
                UserManager.shared.updateCurrentUser()
                presentationMode.dismiss()
            }
            Button("No, Cancel", role: .cancel, action: {})
        }
        .onChange(of: model.goalState) { newValue in
            startConfetti = newValue == .completed
        }
    }
}

struct GoalProgressView_Previews: PreviewProvider {
    private static var goal: Goal {
        let goal = Goal(startDate: Date().addingTimeInterval(-1000000),
                        endDate: Date().addingTimeInterval(1000000),
                        activityType: .walk,
                        distanceMeters: 100000,
                        unit: .miles)
        goal.currentDistanceMeters = 60000
        return goal
    }

    static var previews: some View {
        GoalProgressView(model: GoalProgressViewModel(goal: goal))
            .previewDevice("iPhone 14 Pro")
    }
}
