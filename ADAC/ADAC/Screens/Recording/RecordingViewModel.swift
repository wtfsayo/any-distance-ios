// Licensed under the Any Distance Source-Available License
//
//  RecordingViewModel.swift
//  ADAC
//
//  Created by Daniel Kuntz on 6/20/23.
//

import SwiftUI
import MapKit
import Reachability
import Combine
import MessageUI
import Sentry

class RecordingViewModel: ObservableObject {
    static var mostRecentlySelectedRouteType: GraphType = .route2d

    @ObservedObject var recorder: ActivityRecorder
    @ObservedObject private(set) var howWeCalculatePopupModel: HowWeCalculatePopupModel
    @ObservedObject var post: Post
    @Published var postIsReactable: Bool = false
    @Published var postCommentDraftText: String = ""
    @Published var isPosting: Bool = false
    @Published var currentMediaUploadIndices: [Int] = []
    @Published var visibleMapRect: MKMapRect?
    @Published var hasScrolledToFirstLocation: Bool = false
    @Published var hasTappedStart: Bool = false
    @Published var hasRenderedMap: Bool = false
    @Published var deletingActivity: Bool = false
    @Published var showingDeleteErrorAlert: Bool = false
    @Published var deleteError: Error?
    @Published private(set) var networkConnected: Bool = true
    @Published var routeImage: UIImage?
    @Published var finishedRouteType: RouteType = .map {
        didSet {
            switch finishedRouteType {
            case .map, .photoWith2DRoute:
                RecordingViewModel.mostRecentlySelectedRouteType = .route2d
            case .threeD:
                RecordingViewModel.mostRecentlySelectedRouteType = .route3d
            }

            if finishedRouteType != oldValue && finishedRouteType != .map {
                hasRenderedMap = false
            }
        }
    }

    private(set) var messageComposeDelegate = RecordingMessageDelegate()
    private let reachability = try! Reachability()
    private var observers: Set<AnyCancellable> = []

    var screenName: String {
        if recorder.state == .saved {
            if !ADUser.current.hasRegistered {
                return "Saved Activity"
            } else if isViewingLivePost {
                return "Live Post"
            } else {
                return "Draft Post"
            }
        } else {
            return "Tracking"
        }
    }

    var showDistanceStats: Bool {
        if recorder.state == .saved {
            return recorder.activityType.isDistanceBased
        } else {
            return recorder.activityType.showsRoute && !recorder.activityType.shouldPromptToAddDistance
        }
    }

    var isViewingLivePost: Bool {
        return recorder.state == .saved && !post.isDraft
    }

    func cacheDraftedPost() {
        if post.isDraft {
            PostCache.shared.cache(post: post, sendCachedPublisher: false)
        }
    }

    func postToActiveClub() {
        isPosting = true
        Task {
            do {
                defer {
                    post.isEditing = false
                }

                post.collectibleRawValues = recorder.graphDataSource?.collectibles.map { $0.type.rawValue }
                post.setMetadata()
                if post.id.isEmpty {
                    let postParams: [String: Any] = ["mediaUrlCount": post.mediaUrls.count,
                                                     "activityType": post.activityType.rawValue,
                                                     "hiddenStatsCount": post.hiddenStatTypes.count]

                    if post.isWithinThisActiveClubWeek {
                        Analytics.logEvent("Post to Active Club", screenName, .buttonTap, withParameters: postParams)
                    } else {
                        Analytics.logEvent("Post to Profile", screenName, .buttonTap, withParameters: postParams)
                    }
                    try await PostManager.shared.createPost(post)
                    await MainActor.run {
                        self.recorder = ActivityRecorder(post: post)
                        self.recorder.objectWillChange.send()
                    }
                } else {
                    Analytics.logEvent("Update Post", screenName, .buttonTap)
                    try await PostManager.shared.updatePost(post)
                    await MainActor.run {
                        self.recorder = ActivityRecorder(post: post)
                        self.recorder.objectWillChange.send()
                    }
                }

                await MainActor.run {
                    let title = post.isWithinThisActiveClubWeek ? "Posted to your active club!" : "Posted to your profile!"
                    UIApplication.shared.topViewController?.showSuccessToast(withTitle: title,
                                                                             image: UIImage(systemName: "square.and.arrow.up.circle.fill"),
                                                                             description: "Tap to share to Instagram",
                                                                             bottomInset: 20.0) {
                        self.showDesigner()
                    }
                    isPosting = false
                    ReloadPublishers.activityPosted.send()
                }
            } catch {
                await MainActor.run {
                    isPosting = false
                    UIApplication.shared.topViewController?.showFailureToast(with: error)
                }
            }
        }
    }

    func react(with type: PostReactionType) {
        guard isViewingLivePost else {
            return
        }

        Analytics.logEvent("Post react", screenName, .buttonTap)
        Task(priority: .userInitiated) {
            do {
                try await PostManager.shared.createReaction(on: post, with: type)
            } catch {
                DispatchQueue.main.async {
                    UIApplication.shared.topViewController?.showFailureToast(with: error)
                }
            }
        }
    }

    func showDesigner() {
        guard let activity = post.activity ?? recorder.finishedWorkout else {
            return
        }

        let storyboard = UIStoryboard(name: "Activities", bundle: nil)
        guard let vc = storyboard.instantiateViewController(withIdentifier: "design") as? DesignViewController else {
            return
        }

        Analytics.logEvent("Share tapped", screenName, .buttonTap)
        vc.viewModel = ActivityDesignViewModel(activity: activity)
        let navigationVC = UINavigationController(rootViewController: vc)
        navigationVC.modalPresentationStyle = .overFullScreen
        UIApplication.shared.topViewController?.present(navigationVC, animated: true)
    }

    func makePostPrivate() {
        Analytics.logEvent("Make private tapped", screenName, .buttonTap)
        Task(priority: .userInitiated) {
            do {
                try await PostManager.shared.deletePost(post)
                await MainActor.run {
                    hasTappedStart = false
                    UIApplication.shared.topViewController?.dismiss(animated: true) {
                        UIApplication.shared.topViewController?.showSuccessToast(withTitle: "Activity made private!",
                                                                                 description: "You can re-post this activity from your profile any time.")
                    }
                }
            } catch {
                UIApplication.shared.topViewController?.showFailureToast(with: error)
            }
        }
    }

    func showProfile(for user: ADUser) {
        let vc = UIHostingController(rootView:
                                        ProfileView(model: ProfileViewModel(user: user),
                                                    presentedInSheet: true)
                                            .background(Color.clear)
        )
        vc.view.backgroundColor = .clear
        vc.view.layer.backgroundColor = UIColor.clear.cgColor
        UIApplication.shared.topViewController?.present(vc, animated: true)
    }

    @discardableResult
    func uploadPostMedia(_ image: UIImage) async throws -> URL {
        Analytics.logEvent("Upload media", screenName, .otherEvent)
        let newUploadIdx = max(post.mediaUrls.count, (currentMediaUploadIndices.max() ?? -1) + 1)
        if newUploadIdx > 3,
           let firstPhotoURL = post.mediaUrls.first {
            deleteMedia(with: firstPhotoURL)
        }

        do {
            currentMediaUploadIndices.append(newUploadIdx)
            let url = try await S3.uploadImage(image, resizeToWidth: 2000.0)

            do {
                post.mediaUrls.append(url)
                currentMediaUploadIndices.removeAll(where: { $0 == newUploadIdx })
                if post.isDraft {
                    cacheDraftedPost()
                } else {
                    try await PostManager.shared.updatePost(post)
                }
                return url
            } catch {
                post.mediaUrls.removeAll(where: { $0.absoluteString == url.absoluteString })
                cacheDraftedPost()
                throw error
            }
        } catch {
            currentMediaUploadIndices.removeAll(where: { $0 == newUploadIdx})
            throw error
        }
    }

    func deleteMedia(with url: URL) {
        Analytics.logEvent("Delete media", screenName, .otherEvent)
        post.mediaUrls.removeAll(where: { $0.absoluteString == url.absoluteString })
        if finishedRouteType == .photoWith2DRoute && post.mediaUrls.isEmpty {
            finishedRouteType = .threeD
        }
        cacheDraftedPost()
        Task(priority: .userInitiated) {
            try? await S3.deleteMedia(withURL: url)
        }
    }

    func postComment() {
        Analytics.logEvent("Post comment", screenName, .otherEvent)
        let body = postCommentDraftText
        postCommentDraftText = ""
        Task {
            do {
                try await PostManager.shared.createComment(on: post, with: body)
            } catch {
                DispatchQueue.main.async {
                    UIApplication.shared.topViewController?.showFailureToast(with: error, bottomInset: 400)
                }
            }
        }
    }

    func deleteComment(with id: PostComment.ID) {
        Analytics.logEvent("Delete comment", screenName, .otherEvent)
        Task {
            do {
                try await PostManager.shared.deleteComment(with: id, on: post)
            } catch {
                DispatchQueue.main.async {
                    UIApplication.shared.topViewController?.showFailureToast(with: error)
                }
            }
        }
    }

    func loadRouteImage() {
        guard routeImage == nil else {
            return
        }

        Task(priority: .userInitiated) {
            routeImage = await self.post.routeImage
        }
    }

    func deleteActivity() {
        guard let graphDataSource = recorder.graphDataSource,
              let workout = graphDataSource.recordedWorkout else {
            return
        }

        deletingActivity = true
        Task(priority: .userInitiated) {
            do {
                try await ActivitiesData.shared.deleteActivity(workout)
                ActivitiesData.shared.activitiesReloadedPublisher.send()
                UIApplication.shared.topViewController?.dismiss(animated: true) {
                    let model = ToastView.Model(title: "Activity Deleted",
                                                description: "I guess not *any* distance counts",
                                                image: UIImage(systemName: "checkmark.circle.fill"),
                                                autohide: true,
                                                maxPerSession: 100)
                    let toast = ToastView(model: model,
                                          imageTint: .systemGreen,
                                          borderTint: .systemGreen)
                    let topVC = UIApplication.shared.topViewController
                    topVC?.view.present(toast: toast,
                                        insets: .init(top: 0, left: 0, bottom: 80, right: 0))
                }
            } catch {
                SentrySDK.capture(error: error)
                print(error.localizedDescription)
                deletingActivity = false
                deleteError = error
                showingDeleteErrorAlert = true
            }
        }
    }

    func prepareToStartActivity() {
        if !(CLLocationManager().authorizationStatus == .authorizedWhenInUse ||
             CLLocationManager().authorizationStatus == .authorizedAlways) {
            recorder.moveToLocationPermissionState()
        } else {
            Task {
                try await self.recorder.prepare()
            }
        }
        hasTappedStart = true
    }

    func reset() {
        self.recorder.reset()
        hasTappedStart = false
        hasScrolledToFirstLocation = false
        if !recorder.activityType.showsRoute {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                self.hasScrolledToFirstLocation = true
            }
        }
    }

    func exportPostDebugData() {
        guard let data = try? JSONEncoder().encode(self.post) else {
            return
        }
        let string = String(data: data, encoding: .utf8)
        UIApplication.shared.topViewController?.sendEmail(to: "support@anydistance.club",
                                                          subject: "Post Debug Data",
                                                          message: "",
                                                          attachment: string)
    }

    init(recorder: ActivityRecorder,
         livePost: Post? = nil) {
        self.recorder = recorder
        self.howWeCalculatePopupModel = HowWeCalculatePopupModel()
        self.post = livePost ?? PostCache.shared.draftOrLivePost(for: recorder.finishedWorkout)
        self.postIsReactable = self.post.isReactable
        self.loadRouteImage()

        if let livePost = livePost, recorder.hasCoordinates {
            finishedRouteType = livePost.mediaUrls.isEmpty ? .threeD : .photoWith2DRoute
            Task(priority: .userInitiated) {
                _ = try? await PostManager.shared.getPost(by: livePost.id)
                print("load post")
            }
        }

        if self.post.cityAndState == nil {
            post.loadCityAndState()
        }

        if self.recorder.wasRestoredFromSavedState {
            self.hasTappedStart = true
        }

        self.post.objectWillChange
            .throttle(for: 0.1, scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.objectWillChange.send()
                    self?.postIsReactable = self?.post.isReactable ?? false
                }
            }.store(in: &observers)

        self.recorder.objectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.objectWillChange.send()
                }
            }.store(in: &observers)

        self.recorder.$graphDataSource
            .sink { [weak self] _ in
                guard let self = self else {
                    return
                }

                if let finishedWorkout = recorder.finishedWorkout {
                    let mediaTakenDuringWorkout = post.mediaUrls
                    self.post = PostCache.shared.draftOrLivePost(for: finishedWorkout)
                    self.post.mediaUrls = mediaTakenDuringWorkout
                    self.post.loadCityAndState()
                }
            }.store(in: &observers)

        ADUser.current.$distanceUnit
            .sink { [weak self] unit in
                guard let self = self else {
                    return
                }

                recorder.unit = unit
                recorder.goal.unit = unit
            }.store(in: &observers)

        if !recorder.activityType.showsRoute {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                self.hasScrolledToFirstLocation = true
            }
        }

        reachability.whenReachable = { [weak self] _ in
            self?.networkConnected = true
        }

        reachability.whenUnreachable = { [weak self] _ in
            self?.networkConnected = false
        }

        do {
            try reachability.startNotifier()
        } catch {
            SentrySDK.capture(error: error)
            print("Unable to start reachability notifier.")
        }
    }
}

class RecordingMessageDelegate: NSObject, MFMessageComposeViewControllerDelegate {
    func messageComposeViewController(_ controller: MFMessageComposeViewController,
                                      didFinishWith result: MessageComposeResult) {
        controller.dismiss(animated: true)
    }
}

class HowWeCalculatePopupModel: ObservableObject {
    @Published var statCalculationType: StatisticType = .distance
    @Published var statCalculationInfoVisible: Bool = false

    func showStatCalculation(for type: StatisticType?) {
        guard let type = type else {
            hideStatCalculationInfo()
            return
        }

        if statCalculationInfoVisible {
            hideStatCalculationInfo()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.showStatCalculation(for: type)
            }
        } else {
            statCalculationType = type
            withAnimation(.easeOut(duration: 0.2)) {
                statCalculationInfoVisible = true
            }
        }
    }

    func hideStatCalculationInfo() {
        withAnimation(.easeIn(duration: 0.1)) {
            statCalculationInfoVisible = false
        }
    }
}

enum RouteType: Int {
    case photoWith2DRoute
    case map
    case threeD
}

enum PostFocusedField {
    case title
    case description
    case commentBox
}
