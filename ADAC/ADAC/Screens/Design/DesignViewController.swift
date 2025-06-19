// Licensed under the Any Distance Source-Available License
//
//  DesignViewController.swift
//  ADAC
//
//  Created by Daniel Kuntz on 12/17/20.
//

import UIKit
import SwiftUI
import PhotosUI
import StoreKit
import MobileCoreServices
import MessageUI
import Combine

/// Screen for designing an activity or step count share template
final class DesignViewController: VisualGeneratingViewController, ARViewControllerDelegate {
    var viewModel: ActivityDesignViewModel!
    
    // MARK: - Outlets
    
    @IBOutlet weak var canvasSizeReference: UIView!
    @IBOutlet weak var canvas: LayoutCanvas!
    @IBOutlet weak var pillView: ContinuousCornerView!
    @IBOutlet weak var pillLabel: UILabel!
    @IBOutlet weak var arButton: UIButton!
    @IBOutlet weak var arButtonHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var canvasSizeReferenceCenterYConstraint: NSLayoutConstraint!
    @IBOutlet weak var canvasCenterYConstraint: NSLayoutConstraint!
    @IBOutlet weak var editorControls: EditorControls!
    @IBOutlet weak var shareLockIcon: UIImageView!
    @IBOutlet weak var shareButton: UIButton!
    
    // MARK: - Variables
    
    let screenName = "Design"
    let generator = UIImpactFeedbackGenerator(style: .medium)
    
    private var disposables = Set<AnyCancellable>()
    
    private var isShareCancelled: Bool = false
    private var shouldAnimateCanvasTransform: Bool = false
    private var subscribers: Set<AnyCancellable> = []
    
    // MARK: - Setup
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
        Analytics.logEvent(screenName, screenName, .screenViewed)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        UIView.animate(withDuration: shouldAnimateCanvasTransform ? 0.2 : 0, delay: 0, options: .curveEaseOut, animations: {
            if self.canvasSizeReference.bounds.width < self.canvas.bounds.width {
                let scale = self.canvasSizeReference.bounds.width / self.canvas.bounds.width
                self.canvas.transform = CGAffineTransform(scaleX: scale, y: scale)
            }
        }, completion: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if viewModel.design.graphType == .route3d {
            canvas.unpause3DRoute()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        /// in rare cases, the scroll view delegate methods don't finish with the correct `contentOffset`,
        /// so we set it here to insure we get the right value after the animations have finished
        viewModel.set(photoZoom: Float(canvas.cutoutShapeView.scrollView.zoomScale))
        viewModel.set(photoOffset: canvas.cutoutShapeView.scrollView.contentOffset)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        canvas.unmuteVideo()
        view.layer.masksToBounds = true
        
        ///
        /// TODO: we have to do this because we're loading the EditorControls
        /// view from a nib, so we can't do proper dependency injection, and there was a race condition
        /// between setting up the menu subviews and binding to the view model
        ///
        editorControls.selectFont(viewModel.design.font)
        editorControls.selectGraphType(viewModel.design.graphType)
        editorControls.selectFill(withName: viewModel.design.fill?.name ?? "No Fill")
        editorControls.selectPalette(withName: viewModel.design.palette.name)
        editorControls.selectLayoutShape(viewModel.design.cutoutShape)
        editorControls.selectFilter(viewModel.design.photoFilter)
        editorControls.selectAlignment(viewModel.design.alignment)
        editorControls.updateStatsButtons(for: viewModel.design)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        if viewModel.design.graphType == .route3d {
            canvas.pause3DRoute()
        }
    }
    
    func setup() {
        view.backgroundColor = .init(white: 0.1, alpha: 1.0)
        
        canvas.delegate = self
        editorControls.delegate = self
        editorControls.viewModel = viewModel
        editorControls.setup(activity: viewModel.activity)
        if let stepCount = viewModel.activity as? DailyStepCount {
            canvas.render(stepCount: stepCount)
        } else {
            canvas.render(activity: viewModel.activity)
        }
        bindViewModel()
        
        Task {
            await viewModel.loadMedia()
        }
        
        Task {
            self.generatingModel.routeImage = try? await viewModel.activity.routeImage()
        }
        
        pillView.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
        
        let tapGR = UILongPressGestureRecognizer(target: self, action: #selector(navigationBarLongPress))
        tapGR.cancelsTouchesInView = false
        navigationController?.navigationBar.addGestureRecognizer(tapGR)

        let appearance = UINavigationBarAppearance()
        appearance.backgroundColor = UIColor(white: 0.05, alpha: 1.0)
        appearance.titleTextAttributes = [.font: UIFont.presicav(size: 17.0) as Any]
        appearance.shadowColor = nil

        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance

        let image = UIImage(systemName: "xmark.circle.fill",
                            withConfiguration: UIImage.SymbolConfiguration(font: .systemFont(ofSize: 17,
                                                                                             weight: .semibold)))!
        navigationItem.leftBarButtonItem = UIBarButtonItem(image: image,
                                                           style: .plain,
                                                           target: self,
                                                           action: #selector(closeTapped))
        navigationController?.navigationBar.tintColor = .white
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }
    
    private func bindViewModel() {
        subscribers.removeAll()
        
        canvas.cutoutShapeView.bind(to: viewModel.designPublishable)
        
        canvas.cutoutShapeView.offsetPublisher
            .sink { [weak self] photoOffset in
                self?.viewModel.set(photoOffset: photoOffset)
            }
            .store(in: &subscribers)
        
        canvas.cutoutShapeView.zoomPublisher
            .sink { [weak self] photoZoom in
                self?.viewModel.set(photoZoom: Float(photoZoom))
            }
            .store(in: &subscribers)
        
        viewModel.$superDistanceWatermarkVisible
            .receive(on: DispatchQueue.main)
            .sink { [weak self] visible in
                guard let self = self else { return }
                self.canvas.setSuperDistanceWatermarkVisible(visible)
                self.shareButton.setImage(visible ? UIImage(named: "button_share_lock") : UIImage(named: "button_next"),
                                          for: .normal)
            }
            .store(in: &subscribers)

        viewModel.$goal
            .receive(on: DispatchQueue.main)
            .sink { [weak self] goal in
                guard let self = self else { return }
                self.canvas.setGoal(goal)
            }
            .store(in: &subscribers)
        
        // show the pill for routes not animating if we select a video
        // and 3D route graph
        viewModel.designPublishable.media
            .filter { $0 == .video }
            .combineLatest(viewModel.designPublishable.graphType)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, graphType in
                guard let self = self else { return }
                
                if graphType == .route3d {
                    self.showPill(withTitle: "ℹ️ 3D routes won't animate with videos")
                }
            }
            .store(in: &subscribers)
        
        viewModel.designPublishable.media
            .receive(on: DispatchQueue.main)
            .sink { [weak self] mediaType in
                self?.canvas.mediaType = mediaType
            }
            .store(in: &subscribers)
        
        viewModel.imageForFilters
            .receive(on: DispatchQueue.main)
            .sink { [weak self] image in
                guard let self = self else { return }
                self.editorControls.showFiltersMenu(for: image)
            }
            .store(in: &subscribers)
        
        viewModel.videoModesReady
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                guard let self = self else { return }
                self.editorControls.showVideoModesMenuForVideo()
            }
            .store(in: &subscribers)
        
        viewModel.mediaPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (asset: AVAsset?, image: UIImage?) in
                guard let self = self else { return }
                
                if let asset = asset {
                    self.canvas.changedVideo(asset: asset)
                } else {
                    self.canvas.removeVideo()
                }
                
                if let image = image {
                    self.canvas.cutoutShapeView.image = image
                } else {
                    self.canvas.removePhoto()
                }
                
                if asset != nil || image != nil {
                    self.canvas.cutoutShapeView.photoZoom = CGFloat(self.viewModel.design.photoZoom)
                    self.canvas.cutoutShapeView.photoOffset = self.viewModel.design.photoOffset
                }
            }
            .store(in: &subscribers)
        
        viewModel.savedImage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] image in
                guard let self = self else { return }
                
                Analytics.logEvent("Photo Set Successfully", self.screenName, .otherEvent)
            }
            .store(in: &subscribers)
        
        viewModel.savedVideo
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                guard let self = self else { return }
                
                Analytics.logEvent("Video Set Successfully", self.screenName, .otherEvent)
            }
            .store(in: &subscribers)
        
        Publishers.Merge(
            viewModel.designPublishable.cutoutShape.first().map { ($0, false) },
            viewModel.designPublishable.cutoutShape.dropFirst().map { ($0, true) })
            .receive(on: DispatchQueue.main)
            .sink { [weak self] cutoutShape, animate in
                guard let self = self else { return }
                
                Analytics.logEvent("Changed Layout", self.screenName, .buttonTap, withParameters: ["shape": cutoutShape.rawValue])
                
                self.canvas.setCutoutShape(cutoutShape, animated: animate)
            }
            .store(in: &subscribers)
        
        viewModel.$availableStatisticTypes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] stats in
                guard let self = self else { return }
                for statistic in stats {
                    self.canvas.updateStatistic(statistic,
                                                for: self.viewModel.activity,
                                                design: self.viewModel.design,
                                                animated: false)
                }
            }
            .store(in: &subscribers)
        
        Publishers.Merge(
            viewModel.changedStatistics.first().map { ($0, true) },
            viewModel.changedStatistics.dropFirst().map { ($0, false) })
            .receive(on: DispatchQueue.main)
            .sink { [weak self] designAndStats, isFirst in
                guard let self = self else { return }
                let (design, stats) = designAndStats
                let statistics: [StatisticType] = isFirst ? StatisticType.stats(for: self.viewModel.activity) : Array(stats)
                let filtered = statistics.filter { $0 != .graph }
                for statistic in filtered {
                    self.canvas.updateStatistic(statistic,
                                                for: self.viewModel.activity,
                                                design: design,
                                                animated: !isFirst)
                }
            }
            .store(in: &subscribers)
        
        viewModel.designPublishable.videoMode
            .receive(on: DispatchQueue.main)
            .sink { [weak self] videoMode in
                guard let self = self else { return }
                
                switch videoMode {
                case .loop:
                    Analytics.logEvent("Video Loop", self.screenName, .buttonTap)
                case .bounce:
                    Analytics.logEvent("VideoBounce", self.screenName, .buttonTap)
                }
            }
            .store(in: &subscribers)
        
        viewModel.designPublishable.graphType
            .receive(on: DispatchQueue.main)
            .sink { [weak self] graphType in
                guard let self = self else { return }
                
                Analytics.logEvent("Select Graph Type", self.screenName, .buttonTap, withParameters: ["graphType" : graphType.displayName])

                self.canvas.setGraphType(graphType,
                                         for: self.viewModel.activity,
                                         palette: self.viewModel.design.palette)
                
                if graphType == .route3d {
                    self.canvas.route3DView.setZoom(self.viewModel.design.graphTransform.a)
                    self.showARButton(animated: true)
                } else {
                    self.hideARButton(animated: true)
                }
            }
            .store(in: &disposables)
        
        viewModel.designPublishable.fill
            .receive(on: DispatchQueue.main)
            .sink { [weak self] fill in
                guard let self = self else { return }
                let fillName = fill?.name ?? "No Fill"
                Analytics.logEvent("Select Fill", self.screenName, .buttonTap, withParameters: ["fill" : fillName])
                
                if let _ = fill?.image {
                    self.editorControls.recentPhotoPicker.deselectAllButtons()
                }
            }
            .store(in: &subscribers)
        
        viewModel.designPublishable.font
            .receive(on: DispatchQueue.main)
            .sink { [weak self] font in
                guard let self = self else { return }
                
                Analytics.logEvent("Changed Font", self.screenName, .buttonTap, withParameters: ["font": font.rawValue])
                
                self.canvas.setFont(font)
            }
            .store(in: &subscribers)
        
        viewModel.designPublishable.alignment
            .receive(on: DispatchQueue.main)
            .sink { [weak self] alignment in
                guard let self = self else { return }
                
                Analytics.logEvent("Changed Alignment", self.screenName, .buttonTap, withParameters: ["alignment": alignment.rawValue])
                
                self.canvas.setAlignment(alignment)
                self.editorControls.selectAlignment(alignment)
            }
            .store(in: &subscribers)
        
        viewModel.designPublishable.photoFilter
            .receive(on: DispatchQueue.main)
            .dropFirst()
            .sink { [weak self] photoFilter in
                guard let self = self else { return }
                
//                Analytics.logEvent("Changed Filter", self.screenName, .buttonTap, withParameters: ["filter": photoFilter.effect?.name ?? ""])
                
                if !NSUbiquitousKeyValueStore.default.hasSeenFilterTapAgainView {
                    self.showPill(withTitle: "👆 Tap again to reapply")
                    NSUbiquitousKeyValueStore.default.hasSeenFilterTapAgainView = true
                }
            }
            .store(in: &disposables)
        
        viewModel.$routeIsAvailable
            .combineLatest(viewModel.designPublishable.graphType)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] routeIsAvailable, graphType in
                guard let self = self else { return }

                if !routeIsAvailable,
                   let source = self.viewModel.activity.workoutSource,
                   source.externalService == nil,
                   !source.hasRouteInfo,
                   graphType.requiresRouteData {
                    self.showNoRouteScreen(source)
                } else {
                    // TODO: hide no route?
                }
            }
            .store(in: &subscribers)
        
        viewModel.mediaAdded
            .sink { [weak self] in
                guard let self = self else { return }
                Analytics.logEvent("Media Add", self.screenName, .buttonTap)
            }
            .store(in: &subscribers)
        
        viewModel.mediaReplaced
            .sink { [weak self] in
                guard let self = self else { return }
                Analytics.logEvent("Media Replace", self.screenName, .buttonTap)
            }
            .store(in: &subscribers)
        
        viewModel.mediaRemoved
            .sink { [weak self] in
                guard let self = self else { return }
                Analytics.logEvent("Media Remove", self.screenName, .buttonTap)
                self.canvas.removePhoto()
                self.canvas.removeVideo()
                self.editorControls.hideMenuForMedia()
                self.editorControls.recentPhotoPicker.deselectAllButtons()
            }
            .store(in: &subscribers)
        
        Publishers.Merge(viewModel.mediaAdded,
                         viewModel.mediaReplaced)
        .receive(on: DispatchQueue.main)
        .sink { [weak self] in
            guard let self = self else { return }
            self.presentMediaPicker()
        }
        .store(in: &disposables)
        
        Publishers.Merge(
            viewModel.designPublishable.palette.first().map { ($0, true) },
            viewModel.designPublishable.palette.dropFirst().map { ($0, false) })
            .receive(on: DispatchQueue.main)
            .sink { [weak self] palette, isFirst in
                guard let self = self else { return }
                
                if !isFirst {
                    Analytics.logEvent("Select Palette", self.screenName, .buttonTap, withParameters: ["palette" : palette.name])
                }
                
                self.canvas.setPalette(palette, for: self.viewModel.activity, animated: !isFirst)
            }
            .store(in: &disposables)
        
        viewModel.designPublishable.graphTransform
            .receive(on: DispatchQueue.main)
            .sink { [weak self] graphTransform in
                guard let self = self else { return }
                
                self.canvas.graphContainer.setTransform(graphTransform)
                
                guard graphTransform != .identity,
                      !NSUbiquitousKeyValueStore.default.hasSeenDoubleTapToResetGraph else {
                    return
                }
                
                self.showPill(withTitle: "👆 Double tap graph to reset")
                NSUbiquitousKeyValueStore.default.hasSeenDoubleTapToResetGraph = true
            }
            .store(in: &subscribers)
        
        viewModel.$routeIsAvailable
            .receive(on: DispatchQueue.main)
            .sink { [weak self] routeIsAvailable in
                guard let self = self else { return }
                if !routeIsAvailable {
                    self.hideARButton(animated: true)
                }
            }
            .store(in: &subscribers)
        
        viewModel.graphImage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] image in
                guard let self = self else { return }
                
                self.canvas.graphImageView.image = image
                self.canvas.graphImageView.alpha = 1.0
                self.canvas.cutoutShapeView.toggleActivityIndicator(hidden: true)
            }
            .store(in: &subscribers)
    }
    
    // MARK: -
    
    @objc private func navigationBarLongPress() {
        Task {
            showDarkView(withLabel: "Generating debug data.\nThis may take a few moments.")
            var file = "User ID: \(ADUser.current.id)\n"
            file.append("Build: \(Bundle.main.releaseVersionNumber) (\(Int(Bundle.main.buildVersionNumber)))\n")
            file.append("System version: \(UIDevice.current.systemVersion) on \(UIDevice.modelName)\n")
            file.append("Subscription: \(ADUser.current.subscriptionProductID ?? "Not subscribed")\n")
            file.append("Expires on: \(iAPManager.shared.formattedExpirationDate)\n")
            file.append("----- Begin Activity struct -----\n\n\n")
            
            if viewModel.activity is CachedActivity,
               let nonCached = ActivitiesData.shared.activity(with: viewModel.activity.id) {
                file.append(await nonCached.debugData)
            } else {
                file.append(await viewModel.activity.debugData)
            }
            
            if let fileData = file.data(using: .utf8), MFMailComposeViewController.canSendMail() {
                let mail = MFMailComposeViewController()
                mail.mailComposeDelegate = self
                mail.setSubject("Activity Debug Data")
                mail.setToRecipients(["support@anydistance.club"])
                mail.addAttachmentData(fileData, mimeType: "txt", fileName: "Activity-Log.txt")
                hideDarkView()
                present(mail, animated: true, completion: nil)
            } else {
                UIPasteboard.general.string = file
                let alert = UIAlertController(title: "Activity debug data copied!",
                                              message: "Please paste it into an email and send it to us at support@anydistance.club. Thanks!",
                                              preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
                hideDarkView()
                present(alert, animated: true, completion: nil)
            }
        }
    }

    private func presentMediaPicker() {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Take Photo", style: .default, handler: { _ in
            self.showPhotoCamera()
        }))
        
        alert.addAction(UIAlertAction(title: "Take Video", style: .default, handler: { _ in
            self.showVideoCamera()
        }))
        
        alert.addAction(UIAlertAction(title: "Choose Existing Photo", style: .default, handler: { _ in
            self.showPhotoPicker()
        }))
        
        alert.addAction(UIAlertAction(title: "Choose Existing Video", style: .default, handler: { _ in
            self.showVideoPicker()
        }))
        
        alert.addAction(UIAlertAction(title: "Add Fill", style: .default, handler: { _ in
            self.editorControls.fillsTapped(self)
        }))
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        present(alert, animated: true, completion: nil)
    }
    
    private func showPhotoPicker() {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = .photoLibrary
        picker.mediaTypes = [UTType.image.identifier]
        picker.allowsEditing = false
        picker.presentationController?.delegate = self
        present(picker, animated: true, completion: nil)
        canvas.muteVideo()
    }
    
    private func showVideoPicker() {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = .photoLibrary
        picker.mediaTypes = [UTType.movie.identifier]
        picker.allowsEditing = true
        picker.videoMaximumDuration = 15.0
        picker.videoExportPreset = AVAssetExportPreset1280x720
        picker.presentationController?.delegate = self
        present(picker, animated: true, completion: nil)
        canvas.muteVideo()
    }
    
    private func showPhotoCamera() {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = .camera
        picker.allowsEditing = false
        picker.cameraCaptureMode = .photo
        picker.presentationController?.delegate = self
        present(picker, animated: true, completion: nil)
        canvas.muteVideo()
    }
    
    private func showVideoCamera() {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = .camera
        picker.allowsEditing = false
        picker.mediaTypes = [UTType.movie.identifier]
        picker.cameraCaptureMode = .video
        picker.videoMaximumDuration = 6
        picker.videoQuality = .typeHigh
        picker.presentationController?.delegate = self
        present(picker, animated: true, completion: nil)
        canvas.muteVideo()
    }
    
    private func showPill(withTitle title: String) {
        pillLabel.text = title
        UIView.animate(withDuration: 0.6,
                       delay: 0.3,
                       usingSpringWithDamping: 0.8,
                       initialSpringVelocity: 0.1,
                       options: [.beginFromCurrentState],
                       animations: {
            self.pillView.alpha = 1
            self.pillView.transform = .identity
        }, completion: nil)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
            self.hidePillView()
        }
    }
    
    private func hidePillView() {
        UIView.animate(withDuration: 0.2, delay: 0, options: [.beginFromCurrentState], animations: {
            self.pillView.alpha = 0
            self.pillView.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
        }, completion: nil)
    }
    
    override func cancelTapped() {
        super.cancelTapped()
        isShareCancelled = true
    }
    
    @IBAction func viewInARTapped(_ sender: Any) {
        Task {
            if let coordinates = try? await self.viewModel.activity.coordinates {
                Analytics.logEvent("View Route in AR Tapped", screenName, .buttonTap)
                let vc = ARRouteViewController(coordinates, canvas: canvas, palette: viewModel.design.palette)
                vc.delegate = self
                present(vc, animated: true, completion: nil)
            }
        }
    }
    
    private func showARButton(animated: Bool) {
        arButtonHeightConstraint.constant = 60.0
        canvasSizeReferenceCenterYConstraint.constant = -18.0
        canvasCenterYConstraint.constant = -18.0
        shouldAnimateCanvasTransform = animated
        UIView.animate(withDuration: animated ? 0.2 : 0.0, delay: 0.0, options: [.curveEaseOut]) {
            self.arButton.alpha = 1.0
            self.view.layoutIfNeeded()
        } completion: { _ in
            self.shouldAnimateCanvasTransform = false
        }
    }
    
    func hideARButton(animated: Bool) {
        arButtonHeightConstraint.constant = 23.0
        canvasSizeReferenceCenterYConstraint.constant = 0.0
        canvasCenterYConstraint.constant = 0.0
        shouldAnimateCanvasTransform = animated
        UIView.animate(withDuration: animated ? 0.2 : 0.0, delay: 0.0, options: [.curveEaseOut]) {
            self.arButton.alpha = 0.0
            self.view.layoutIfNeeded()
        } completion: { _ in
            self.shouldAnimateCanvasTransform = false
        }
    }
    
    @IBAction func shareTapped(_ sender: Any) {
        canvas.muteVideo()
        generator.impactOccurred()

        Analytics.logEvent("Share", screenName, .buttonTap)

        if viewModel.design.hasSuperDistanceFeaturesEnabled && !iAPManager.shared.hasSuperDistanceFeatures {
            let vc = UIHostingController(rootView: SuperDistanceView())
            vc.modalPresentationStyle = .overFullScreen
            present(vc, animated: true)
            return
        }

        setProgress(0.0, animated: false)
        
        showActivityIndicator()
        isShareCancelled = false
        
        if viewModel.design.media == .video || viewModel.design.graphType == .route3d {
            CanvasShareVideoGenerator.renderVideos(for: canvas,
                                                   activity: viewModel.activity,
                                                   design: viewModel.design) { [weak self] in
                return self?.isShareCancelled ?? true
            } progress: { [weak self] progress in
                self?.setProgress(progress, animated: true)
            } completion: { [weak self] videos in
                self?.hideActivityIndicator()
                self?.performSegue(withIdentifier: "designToShare", sender: videos)
            }
        } else {
            CanvasShareImageGenerator.generateShareImages(canvas: canvas,
                                                          design: viewModel.design) { [weak self] in
                return self?.isShareCancelled ?? true
            } progress: { [weak self] progress in
                DispatchQueue.main.async {
                    self?.setProgress(progress, animated: true)
                }
            } completion: { [weak self] images in
                self?.hideActivityIndicator()
                self?.performSegue(withIdentifier: "designToShare", sender: images)
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let shareVC = segue.destination as? ShareViewController {
            shareVC.title = "Share Activity"
            if let images = sender as? ShareImages {
                shareVC.images = images
            } else if let videos = sender as? ShareVideos {
                shareVC.videos = videos
            }
            shareVC.presentationController?.delegate = self
            shareVC.delegate = self
        } else if let noRouteScreen = segue.destination as? NoRouteViewController {
            noRouteScreen.source = sender as? HealthKitWorkoutSource
        }
    }
    
    internal func arViewControllerShouldSetVideo(with url: URL) {
        viewModel.saveVideo(from: url, isARMedia: true)
        canvas.cutoutShapeView.photoZoom = 1.1
        editorControls.hideSubmenu()
        editorControls.recentPhotoPicker.deselectAllButtons()
    }
    
    internal func arViewControllerShouldSetPhoto(_ image: UIImage) {
        viewModel.save(image: image, isARMedia: true)
        editorControls.hideSubmenu()
        editorControls.recentPhotoPicker.deselectAllButtons()
    }
    
    internal func showNoRouteScreen(_ source: HealthKitWorkoutSource) {
        performSegue(withIdentifier: "designToNoRoute", sender: source)
    }
    
}

extension DesignViewController: EditorControlsDelegate {
    func filtersSubmenuTapped() -> Bool {
        Analytics.logEvent("Tapped Filters (Unlocked)", screenName, .buttonTap)
        return true
    }
    
    func detailsStatisticTapped(_ statistic: StatisticType) {
        Analytics.logEvent("Toggle \(statistic.rawValue)", screenName, .buttonTap)
    }
    
    func showConnect(for service: ExternalService) {
        let toastModel = ToastView.Model(title: "Connect to \(service.displayName)",
                                         description: "See routes, splits and more.",
                                         image: UIImage(systemName: "face.smiling"),
                                         autohide: false)
        let tint = UIColor.adGreen
        let toast = ToastView(model: toastModel, imageTint: tint, borderTint: tint, actionHandler: {
            let authenticationVC = ExternalServiceAuthViewController(with: service)
            self.present(authenticationVC, animated: true)
        })
        let insets = UIEdgeInsets(top: 0, left: 0, bottom: editorControls.frame.height, right: 0)
        self.view.present(toast: toast, insets: insets)
    }
    
    func didSelectGraphType(graphType: GraphType) {
        if graphType != viewModel.design.graphType, graphType != .none {
            canvas.cutoutShapeView.toggleActivityIndicator(hidden: false)
        }
    }
}

extension DesignViewController: LayoutCanvasDelegate {
    func canvasTapped() {
        presentMediaPicker()
        Analytics.logEvent("Tapped Canvas", screenName, .buttonTap)
    }
    
    func finishedMovingRoute(to transform: CGAffineTransform) {
        viewModel.set(graphTransform: transform)
    }
}

extension DesignViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true, completion: nil)
        
        if info[.mediaType] as? String == UTType.image.identifier,
           let image = info[.originalImage] as? UIImage {
            viewModel.save(image: image)
            
            if picker.sourceType == .camera {
                PhotoLibrarySaver.saveImage(image.withCorrectedOrientation())
            }
        } else if info[.mediaType] as? String == UTType.movie.identifier,
                  let url = info[.mediaURL] as? URL {
            viewModel.saveVideo(from: url)
        }
        
        if let url = info[.imageURL] as? URL {
            try? FileManager.default.removeItem(at: url)
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
        canvas.unmuteVideo()
    }
}

extension DesignViewController: UIAdaptivePresentationControllerDelegate {
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        canvas.unmuteVideo()
    }
}

extension DesignViewController: ShareViewControllerDelegate {
    
    func showReviewPromptIfNecessary() {
        canvas.unmuteVideo()
        
        NSUbiquitousKeyValueStore.default.numberOfActivitiesShared += 1
        if NSUbiquitousKeyValueStore.default.numberOfActivitiesShared == 1 ||
            NSUbiquitousKeyValueStore.default.numberOfActivitiesShared % 5 == 0 {
            if let windowScene = UIApplication.shared.windows.first?.windowScene {
                SKStoreReviewController.requestReview(in: windowScene)
                Analytics.logEvent("Review Requested", screenName, .otherEvent)
            }
        }
    }
    
    func addToPost(_ image: UIImage) {}
    
    func addToPost(_ videoUrl: URL) {}
    
}
