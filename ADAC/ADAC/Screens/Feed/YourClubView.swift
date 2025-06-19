// Licensed under the Any Distance Source-Available License
//
//  YourClubView.swift
//  ADAC
//
//  Created by Daniel Kuntz on 2/23/23.
//

import SwiftUI
import OneSignal
import Combine

/// View that shows club stats
struct ClubStats: View {
    struct Item {
        var stat: String
        var label: String
    }

    var stats: [Item]
    var fontScale: CGFloat = 1.0

    var body: some View {
        HStack {
            ForEach(stats.enumerated().map { $0 }, id: \.element.label) { idx, stat in
                VStack(spacing: 0.0) {
                    Text(stat.stat)
                        .font(Font.custom("NeueMatic Compressed", size: 80.0 * fontScale))
                        .kerning(3)
                        .foregroundColor(.white)
                    Text(stat.label)
                        .font(.system(size: 12.0 * fontScale, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                }

                if idx < stats.count - 1 {
                    Spacer()
                }
            }
        }
    }
}

/// Button that starts an activity
struct StartActivityButton: View {
    let screenName: String

    var body: some View {
        Button {
            ADTabBar.current?.startActivity()
            Analytics.logEvent("Start activity empty state tapped", screenName, .buttonTap)
        } label: {
            RoundedWhiteButtonLabel(text: "Start Activity")
                .frame(width: 124.0, height: 36.0)
        }
    }
}

/// Empty state view that shows when the user is registered for Active Clubs but doesn't have any friends
struct NoFriendsEmptyState: View {
    @Binding var showingFriendManager: Bool

    private let screenName = "Your Club Feed"

    var body: some View {
        VStack(spacing: 16) {
            Image("no-friends-state-hero")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .padding([.leading, .trailing])

            Text("Any Distance is better with friends! Let's build out your Active Club.")
                .font(.system(size: 15))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            HStack(spacing: 14) {
                Button {
                    showingFriendManager = true
                    Analytics.logEvent("Invite friends tapped", YourClubViewModel.screenName, .buttonTap)
                } label: {
                    RoundedWhiteButtonLabel(text: "Invite friends")
                }

                Button {
                    UIApplication.shared.topViewController?
                        .openUrl(withString: Links.howActiveClubsWorks.absoluteString)
                    Analytics.logEvent("How it works tapped", YourClubViewModel.screenName, .buttonTap)
                } label: {
                    RoundedWhiteButtonLabel(text: "How it works")
                }
            }
            .frame(height: 40)
        }
        .padding([.leading, .trailing], 40)
        .padding(.top, (UIScreen.main.bounds.height - 460) / 4.0)
    }
}

/// Empty state view that shows when the user isn't registered for Active Clubs
struct NotRegisterdEmptyState: View {
    private let screenName = "Your Club Feed"

    private func showOnboarding() {
        let vc = OnboardingViewController()
        vc.model.state = .signIn
        vc.modalPresentationStyle = .overFullScreen
        UIView.animate(withDuration: 0.2) {
            UIApplication.shared.topWindow?.alpha = 0.0
        } completion: { _ in
            UIApplication.shared.topWindow?.rootViewController = vc
            UIView.animate(withDuration: 0.2) {
                UIApplication.shared.topWindow?.alpha = 1.0
            }
        }
    }

    var body: some View {
        VStack(spacing: 16.0) {
            LoopingVideoView(videoUrl: Bundle.main.url(forResource: "onboarding-slide-1", withExtension: "mp4")!,
                             videoGravity: .resizeAspect)
            .blendMode(.lighten)
            .offset(y: -25)

            VStack(spacing: 16.0) {
                Text("Join Active Clubs to share activities with your friends and save your achievements & goals.")
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                ADWhiteButton(title: "Join Active Clubs") {
                    showOnboarding()
                    Analytics.logEvent("Join Active Clubs tapped", YourClubViewModel.screenName, .buttonTap)
                }
                .frame(height: 45)

                PrivacyAndTerms()
            }
            .offset(y: -175)
        }
        .padding([.leading, .trailing], 40)
    }
}

/// Wrapper around PostCellWithUsername that scales and blurs as it scrolls within a ScrollView
struct ScalingPostCellWithUsername: View {
    @ObservedObject var model: PostCellModel
    @State var frame: CGRect = .zero

    var position: CGFloat {
        return frame.minY
    }

    var offset: CGFloat {
        return 1.2 * (1.0 - (-1.0 * (position / 500)).clamped(to: 0...0.2) * position)
    }

    var blur: CGFloat {
        return 5.0 * (1.0 - ((position + 200.0) / 100.0)).clamped(to: 0...100.0)
    }

    var opacity: CGFloat {
        return ((position + 500.0) / 500.0)
    }

    var body: some View {
        PostCellWithUsername(model: model)
            .offset(y: offset)
            .blur(radius: blur)
            .opacity(opacity)
            .background {
                GeometryReader { geometry in
                    Color.clear
                        .preference(key: CGRectPreferenceKey.self,
                                    value: geometry.frame(in: .named("scroll")))
                }
            }
            .onPreferenceChange(CGRectPreferenceKey.self) { value in
                self.frame = value
            }
    }
}

/// Screen that shows the Active Clubs friends feed.
struct YourClubView: View {
    @ObservedObject var model: YourClubViewModel
    @State var showingFriendManager: Bool = false
    @State var scrollViewOffset: CGFloat = 0.0
    @State var isRefreshing: Bool = false
    @State var showingAllPastClubStats: Bool = false

    var addFriendsButton: some View {
        VStack {
            HStack {
                let blur = (10.0 * (-scrollViewOffset / 110)).clamped(to: 0...10.0)

                Spacer()
                Button {
                    showingFriendManager = true
                    Analytics.logEvent("Friends tapped", YourClubViewModel.screenName, .buttonTap)
                } label: {
                    if ADUser.current.receivedRequests.isEmpty {
                        HStack {
                            Text("Friends")
                            Image(systemName: .personCropCircleBadgePlus)
                                .font(.system(size: 22))
                        }
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .medium))
                        .frame(width: 200, height: 200)
                        .contentShape(Rectangle())
                    } else {
                        HStack {
                            Text("Friends")
                                .foregroundColor(.white)
                                .font(.system(size: 16, weight: .medium))
                            ZStack {
                                RoundedRectangle(cornerRadius: 11.0)
                                    .frame(width: ADUser.current.receivedRequests.count < 10 ? 22.0 : 28.0,
                                           height: 22.0)
                                    .foregroundColor(.adOrangeLighter)
                                Text(String(ADUser.current.receivedRequests.count))
                                    .font(.system(size: ADUser.current.receivedRequests.count < 10 ? 15.5 : 13.5,
                                                  weight: .semibold))
                                    .foregroundColor(.black)
                                    .offset(y: 0.25)
                                ZStack {
                                    Circle()
                                        .fill(Color.black)
                                    Image(systemName: .plusCircleFill)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .foregroundColor(.white)
                                }
                                .frame(width: 12.5, height: 12.5)
                                .offset(x: ADUser.current.receivedRequests.count < 10 ? -10.0 : -13.0,
                                        y: 5.5)
                            }
                        }
                        .frame(width: 200, height: 200)
                        .contentShape(Rectangle())
                    }
                }
                .opacity(1.0 - (blur * 0.1))
                .blur(radius: blur)
            }
            .padding(.leading, 20)
            .padding(.top, -30)
            .padding(.trailing, -45)

            Spacer()
        }
    }

    var curvedText: some View {
        ZStack {
            let curvedTextScale = (scrollViewOffset * 0.005).clamped(to: 1.0...2.0)
            let longNameScale = ADUser.current.firstName.count >= 10 ? 0.7 : 1.0
            let curvedTextBlur = (10.0 * (-scrollViewOffset / 310)).clamped(to: 0...10.0)
            let curvedTextOffset = -0.8 * scrollViewOffset

            CurvedTextAnimationView(text: "\(ADUser.current.firstName.uppercased())'S ACTIVE CLUB",
                                    radius: 130)
                .scaleEffect(x: longNameScale, y: longNameScale, anchor: .top)
                .frame(height: 430)
                .maxWidth(.infinity)
                .mask {
                    VStack {
                        Rectangle()
                            .frame(height: 100)
                        Spacer()
                    }
                }
                .padding(.bottom, -390)
                .scaleEffect(x: curvedTextScale, y: curvedTextScale, anchor: .top)
                .blur(radius: (curvedTextScale - 1) * 10)
                .blur(radius: curvedTextBlur)
                .offset(y: curvedTextOffset)
                .opacity(1.0 - (curvedTextBlur * 0.1))
        }
    }

    var profileImageView: some View {
        ZStack {
            let blur = (10.0 * (-scrollViewOffset / 350)).clamped(to: 0...10.0)
            let offset = -0.7 * scrollViewOffset

            UserProfileImageView(user: .current,
                                 showsLoadingIndicator: true,
                                 width: 50)
            .padding(.bottom, 8)
            .blur(radius: blur)
            .offset(y: offset)
            .opacity(1.0 - (blur * 0.1))
        }
    }

    var clubDescriptionText: some View {
        ZStack {
            let blur = (10.0 * (-scrollViewOffset / 390)).clamped(to: 0...10.0)
            let offset = -0.6 * scrollViewOffset

            let string: String = {
                if model.clubStats.postCount == 0 {
                    return "You can be the first to rack up some activity for your club this week."
                } else if PostManager.shared.currentUserHasPostedThisWeek {
                    switch model.clubStats.activityLevel {
                    case 1:
                        return "Your club has had a strong week.\nGreat to see you moving."
                    case 2:
                        return "Wow, impressive stats this week!\nKeep contributing!"
                    default:
                        return "Your club has been busy this week. Nice work on contributing!"
                    }
                } else {
                    return "Your club has been busy this week! Post an activity to unlock your friends' posts."
                }
            }()

            Text(string)
                .multilineTextAlignment(.center)
                .font(.system(size: 14, weight: .medium))
                .padding([.leading, .trailing], 80)
                .blur(radius: blur)
                .offset(y: offset)
                .opacity(1.0 - (blur * 0.1))
        }
    }

    var clubStats: some View {
        ZStack {
            let blur = (10.0 * (-scrollViewOffset / 450)).clamped(to: 0...10.0)
            let offset = -0.5 * scrollViewOffset

            ClubStats(stats: [
                ClubStats.Item(stat: model.clubStats.formattedTotalDistance,
                               label: ADUser.current.distanceUnit.abbreviation.uppercased()),
                ClubStats.Item(stat: model.clubStats.formattedTime, label: "MINUTES"),
                ClubStats.Item(stat: model.clubStats.formattedElevationGain,
                               label: "\(ADUser.current.distanceUnit == .miles ? "FT" : "M") EL GAIN"),
                ClubStats.Item(stat: "\(model.medals.count)", label: "MEDALS")
            ], fontScale: 0.93)
            .padding([.leading, .trailing], 40)
            .blur(radius: blur)
            .offset(y: offset)
            .opacity(1.0 - (blur * 0.1))
        }
    }

    var medalCarousel: some View {
        ZStack {
            let medalWidth: CGFloat = 38
            let medalSpacing: CGFloat = 8

            if !model.medals.isEmpty {
                let blur = (10.0 * (-scrollViewOffset / 490)).clamped(to: 0...10.0)
                let offset = -0.4 * scrollViewOffset
                HorizontalImageRow(imageSize: CGSize(width: medalWidth, height: medalWidth * 1.525),
                                   imageSpacing: medalSpacing,
                                   collectibles: model.uniquedMedals,
                                   alwaysAnimate: false,
                                   centered: true) { collectible in
                    let vc = UIHostingController(rootView: CollectiblePostsDetailView(collectible: collectible))
                    UIApplication.shared.topViewController?.present(vc, animated: true)
                    Analytics.logEvent("Collectible tapped", YourClubViewModel.screenName, .buttonTap)
                }
                .frame(height: medalWidth * 1.525)
                .frame(width: UIScreen.main.bounds.width)
                .mask {
                    HStack(spacing: 0) {
                        Image("layout_gradient_left")
                            .resizable(resizingMode: .stretch)
                            .frame(width: UIScreen.main.bounds.width * 0.1,
                                   height: medalWidth * 1.525)
                        Color.black
                        Image("layout_gradient_right")
                            .resizable(resizingMode: .stretch)
                            .frame(width: UIScreen.main.bounds.width * 0.1,
                                   height: medalWidth * 1.525)
                    }
                }
                .padding([.top, .bottom], 16)
                .blur(radius: blur)
                .offset(y: offset)
                .opacity(1.0 - (blur * 0.1))
            } else {
                Spacer()
                    .frame(height: 16)
            }
        }
    }

    var mostRecentActivity: some View {
        ZStack {
            let blur = (10.0 * (-scrollViewOffset / 540)).clamped(to: 0...10.0)
            let offset = -0.3 * scrollViewOffset

            if let latestActivity = model.latestPostableActivity {
                ActivityCell(activity: latestActivity,
                             showNewActivityLabel: true) {
                    Analytics.logEvent("New activity tapped", YourClubViewModel.screenName, .buttonTap)
                    UIApplication.shared.topViewController?.showPostDraft(for: latestActivity)
                }
                .padding([.top, .bottom], 8)
                .blur(radius: blur)
                .offset(y: offset)
                .opacity(1.0 - (blur * 0.1))
                .modifier(BlurOpacityTransition(speed: 1.6))
            } else {
                EmptyView()
            }
        }
    }

    var body: some View {
        ZStack {
            GradientAnimationView(pageIdx: model.clubStats.activityLevel)
                .mask {
                    VStack(spacing: 0) {
                        Image("layout_top_gradient")
                            .resizable(resizingMode: .stretch)
                            .frame(height: UIScreen.main.bounds.height / 2.0)
                        Spacer()
                    }
                }
                .transition(.opacity.animation(.easeInOut(duration: 1.0)))
                .ignoresSafeArea()

            if ADUser.current.hasRegistered {
                RefreshableScrollView(offset: $scrollViewOffset,
                                      isRefreshing: $isRefreshing) {
                    Spacer()
                        .frame(height: 20)
                    curvedText
                    profileImageView

                    if ADUser.current.friendIDs.isEmpty || NSUbiquitousKeyValueStore.default.overrideShowNoFriendsEmptyState {
                        NoFriendsEmptyState(showingFriendManager: $showingFriendManager)
                    } else {
                        clubDescriptionText
                        clubStats
                        medalCarousel
                        mostRecentActivity

                        if model.postCellModels.isEmpty && !model.isLoading {
                            VStack {
                                AndiEmptyState(text: "Let's go! Any Distance counts.",
                                               type: .fly)
                                StartActivityButton(screenName: YourClubViewModel.screenName)
                            }
                            .padding(.top, 30)
                            .modifier(BlurOpacityTransition(speed: 1.5))

                            LazyVStack {
                                ForEach(model.pastClubStatsDataModels,
                                        id: \.clubStats.startDate.timeIntervalSince1970) { model in
                                    PastClubStatsCell(model: model)
                                }
                            }
                        } else {
                            LazyVStack {
                                ForEach(model.postCellModels, id: \.post.id) { model in
                                    ScalingPostCellWithUsername(model: model)
                                        .modifier(BlurOpacityTransition(speed: 1.5))
                                }

                                if !model.pastClubStatsDataModels.isEmpty {
                                    SectionHeaderText(text: "Previous Weeks")
                                        .padding(.top, 16)
                                    ForEach(model.pastClubStatsDataModels.prefix(3),
                                            id: \.clubStats.startDate.timeIntervalSince1970) { model in
                                        PastClubStatsCell(model: model)
                                    }

                                    if model.pastClubStatsDataModels.count > 3 {
                                        Button {
                                            showingAllPastClubStats = true
                                        } label: {
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                    .fill(Color.white)
                                                Text("See More")
                                                    .font(.system(size: 17, weight: .medium))
                                                    .foregroundColor(.black)
                                            }
                                            .frame(height: 45)
                                        }
                                    }
                                }
                            }
                            .padding([.leading, .trailing], 20)
                        }
                    }

                    Spacer()
                        .frame(height: 60)
                }
                .mask {
                    ZStack {
                        let safeAreaTop = UIScreen.main.safeAreaInsets.top
                        VStack(spacing: 0) {
                            Image("layout_gradient")
                                .resizable(resizingMode: .stretch)
                                .frame(width: UIScreen.main.bounds.width, height: safeAreaTop)
                            Color.black
                        }
                        .ignoresSafeArea()
                    }
                }

                addFriendsButton
                    .ignoresSafeArea()
            } else {
                NotRegisterdEmptyState()
            }
        }
        .sheet(isPresented: $showingFriendManager) {
            FriendManagerView()
                .sheetBackground(Color.black)
        }
        .sheet(isPresented: $showingAllPastClubStats) {
            PastClubStatsView(pastClubStatsDataModels: model.pastClubStatsDataModels)
        }
        .onAppear {
            Analytics.logEvent(YourClubViewModel.screenName, YourClubViewModel.screenName, .screenViewed)
        }
        .onChange(of: isRefreshing) { newValue in
            if newValue == true {
                Task(priority: .userInitiated) {
                    await model.loadPosts()
                    await MainActor.run {
                        self.isRefreshing = false
                    }
                }
            }
        }
    }
}

/// Model for YourClubView
class YourClubViewModel: NSObject, ObservableObject {
    weak var controller: YourClubViewController?
    @Published var posts: [Post] = []
    @Published var postCellModels: [PostCellModel] = []
    @Published var clubStats: ClubStatsData = ClubStatsData(postCount: 0)
    @Published var isLoading: Bool = false
    @Published var medals: [Collectible] = []
    @Published var uniquedMedals: [Collectible] = []
    @Published var latestPostableActivity: Activity?
    @Published var pastClubStatsDataModels: [PastClubStatsCellModel] = []
    private var subscribers: Set<AnyCancellable> = []

    static let screenName = "Your Club Feed"

    private var postStartDate: Date {
        return Calendar.current.nextDate(after: Date(),
                                         matching: DateComponents(weekday: 1),
                                         matchingPolicy: .strict,
                                         direction: .backward) ?? Date()
    }

    init(controller: YourClubViewController) {
        super.init()
        self.controller = controller
        self.loadCachedPosts()
        self.loadLatestActivity()

        Task(priority: .userInitiated) {
            await self.loadPosts()
        }

        NotificationCenter.default
            .publisher(for: UIApplication.didBecomeActiveNotification)
            .receive(on: DispatchQueue.main)
            .dropFirst(1)
            .sink { [weak self] _ in
                self?.loadLatestActivity(queryForNew: true)
            }
            .store(in: &subscribers)

        ReloadPublishers.activityPosted
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else {
                    return
                }

                Task(priority: .userInitiated) {
                    print("reload your club")
                    self.loadLatestActivity()
                    await self.loadPosts()
                }
            }
            .store(in: &subscribers)

        PostCache.shared.postCachedPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else {
                    return
                }

                self.loadCachedPosts()
                self.loadLatestActivity()
            }
            .store(in: &subscribers)

        ActivitiesData.shared.activitiesReloadedPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.loadLatestActivity()
            }
            .store(in: &subscribers)

        ADUser.current.$distanceUnit
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &subscribers)
    }

    func loadCachedPosts() {
        Task(priority: .userInitiated) {
            let posts = PostCache.shared.friendPosts(withStartDate: PostManager.shared.thisWeekPostStartDate)
            await MainActor.run {
                self.posts = posts
                self.postCellModels = self.posts.map { PostCellModel(post: $0, screenName: YourClubViewModel.screenName) }
            }
        }
    }

    func loadPosts() async {
        await MainActor.run {
            isLoading = true
        }

        do {
            _ = try await withThrowingTaskGroup(of: Bool.self) { group in
                group.addTask {
                    let newPosts = try await PostManager.shared.getFriendPosts(startDate: PostManager.shared.thisWeekPostStartDate)
                    DispatchQueue.main.async {
                        self.posts = newPosts
                        self.postCellModels = newPosts.map { PostCellModel(post: $0, screenName: YourClubViewModel.screenName) }
                    }
                    return true
                }

                group.addTask {
                    let clubStats = try await ClubStatsManager.shared.getClubStats(startDate: PostManager.shared.thisWeekPostStartDate)
                    DispatchQueue.main.async {
                        self.clubStats = clubStats
                        self.medals = clubStats.medals
                        self.uniquedMedals = clubStats.uniquedMedals
                    }
                    return true
                }

                group.addTask {
                    let pastClubStatsData = await ClubStatsManager.shared.getPastClubStatsData()
                    DispatchQueue.main.async {
                        self.pastClubStatsDataModels = pastClubStatsData.map { PastClubStatsCellModel(clubStatsData: $0) }
                    }
                    return true
                }

                for try await _ in group {}

                await MainActor.run {
                    isLoading = false
                }

                return true
            }
        } catch {}
    }

    func loadLatestActivity(queryForNew: Bool = false) {
        Task(priority: .userInitiated) {
            if queryForNew {
                await ActivitiesData.shared.load()
            }

            let activity = ActivitiesData.shared.activities
                .first(where: { activityIdentifiable in
                    let activity = activityIdentifiable.activity
                    return !(activity is DailyStepCount) &&
                    activity.activityType != .stepCount &&
                    !PostCache.shared.livePostExists(for: activity) &&
                    activity.startDate >= PostManager.shared.thisWeekPostStartDate
                })?.activity
            DispatchQueue.main.async {
                self.latestPostableActivity = activity
            }
        }
    }
}

/// Convenience ClubStatsData extension that determines activity level to set the page in GradientAnimationView
extension ClubStatsData {
    var activityLevel: Int {
        let distanceMiles = UnitConverter.metersToMiles(self.totalDistanceMeters ?? 0.0)
        switch distanceMiles {
        case 0..<100.0:
            return 0
        case 100..<150.0:
            return 1
        default:
            return 2
        }
    }
}

/// Convenience ClubStatsData extension that formats the stats
extension ClubStatsData {
    var formattedTotalDistance: String {
        guard let totalDistanceMeters = self.totalDistanceMeters else {
            return "-"
        }

        let converedDistance = UnitConverter.meters(totalDistanceMeters,
                                                    toUnit: ADUser.current.distanceUnit)
        return String(Int(converedDistance.rounded()))
    }

    var formattedTime: String {
        guard let totalMovingTime = self.totalMovingTime else {
            return "-"
        }

        let minutes = totalMovingTime / 60.0
        if minutes < 1000 {
            return String(Int(minutes.rounded()))
        } else {
            return String((minutes / 1000.0).rounded(toPlaces: 1)) + "K"
        }
    }

    var formattedElevationGain: String {
        guard let totalElevGainMeters = self.totalElevGainMeters else {
            return "-"
        }

        let convertedGain = (ADUser.current.distanceUnit == .miles) ? totalElevGainMeters * 3.28 : totalElevGainMeters
        if convertedGain < 1000 {
            return String(Int(convertedGain.rounded()))
        } else {
            return String((convertedGain / 1000.0).rounded(toPlaces: 1)) + "K"
        }
    }
}

struct YourClubView_Previews: PreviewProvider {
    static var previews: some View {
        YourClubView(model: YourClubViewModel(controller: YourClubViewController()))
    }
}
