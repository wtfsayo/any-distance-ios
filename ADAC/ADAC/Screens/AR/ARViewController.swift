// Licensed under the Any Distance Source-Available License
//
//  ARViewController.swift
//  ADAC
//
//  Created by Daniel Kuntz on 2/17/22.
//

import UIKit
import ARKit
import SwiftUI
import SCNRecorder
import AVFoundation
import Combine

protocol ARViewControllerDelegate: AnyObject {
    func arViewControllerShouldSetPhoto(_ image: UIImage)
    func arViewControllerShouldSetVideo(with url: URL)
}

/// A SwiftUIViewController wrapper around ARViewer that handles business logic for recording / taking photos. Allows for display of any
/// ARSCNView that conforms to ADARView.
class ARViewController<ARView: ADARView>: SwiftUIViewController<ARViewer<ARView>>, VisualGeneratingActor, ShareViewControllerDelegate {

    // MARK: - Variables

    weak var arView: ARView?
    weak var delegate: ARViewControllerDelegate?
    var feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
    var generatingModel = GeneratingVisualsViewModel()
    private var isShareCancelled: Bool = false
    var subscribers: Set<AnyCancellable> = []

    let screenName: String = "AR Viewer"

    var showsRouteControls: Bool {
        return false
    }

    var showsWearableControls: Bool {
        return false
    }

    var showsRecordingControls: Bool {
        return true
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }

    var shareScreenShowsAddToPostButton: Bool {
        return true
    }

    // MARK: - Setup

    init(_ arView: ARView) {
        super.init()
        self.arView = arView
//        arView.showsStatistics = true
        modalPresentationStyle = .fullScreen
        view.backgroundColor = .black

        NotificationCenter.default.publisher(for: .AVCaptureSessionDidStartRunning).sink { notification in
            if let captureSession = notification.object as? AVCaptureSession {
                for connection in captureSession.connections {
                    connection.preferredVideoStabilizationMode = .auto
                }
            }
        }.store(in: &subscribers)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func createSwiftUIView() {
        let model = ARViewModel(controller: self)
        generatingModel.blurBackground = true
        generatingModel.controller = self
        swiftUIView = ARViewer<ARView>(model: model, generatingModel: generatingModel)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        arView?.prepareForRecording()
        self.isModalInPresentation = true
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        arView?.cancelVideoRecording()
        (arView as? GestureARView)?.coachingOverlay.session = nil
        arView?.session.pause()
        arView?.scene.rootNode.cleanup()
        arView?.delegate = nil
        arView = nil
    }

    // MARK: - Actions

    func closeAction() {
        dismiss(animated: true)
    }

    func takePhotoAction(_ completion: @escaping () -> Void) {
        feedbackGenerator.impactOccurred()
        resetGeneratingModel()

        if let vc = UIStoryboard(name: "Activities", bundle: nil).instantiateViewController(withIdentifier: "shareVC") as? ShareViewController {
            Analytics.logEvent("Take Photo", screenName, .buttonTap)
            arView?.takePhoto { [weak self] img in
                self?.generatingModel.setProgress(1, animated: true)
                ARCollectibleShareImageGenerator.generateShareImages(img) { [weak self] images in
                    vc.images = images
                    vc.title = "Share"
                    vc.showsAddToPostButton = self?.shareScreenShowsAddToPostButton ?? false
                    vc.delegate = self
                    self?.present(vc, animated: true, completion: nil)
                    completion()
                }
            }
        }
    }

    func startRecordingAction() {
        let documentDirectory = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.cachesDirectory,
                                                                    FileManager.SearchPathDomainMask.userDomainMask, true).first!
        let documentDirectoryUrl = URL(fileURLWithPath: documentDirectory)
        let destinationUrl = documentDirectoryUrl.appendingPathComponent("AR-Video-NW.mp4")
        FileManager.default.removeItemIfExists(atUrl: destinationUrl)

        do {
            try arView?.startVideoRecording(to: destinationUrl,
                                           fileType: .mp4,
                                           size: CGSize(width: 1080, height: 1920))
        } catch {
            print(error.localizedDescription)
        }
    }

    func cancelTapped() {
        generatingModel.isLoading = false
        isShareCancelled = true
        if let config = arView?.session.configuration {
            arView?.session.run(config)
        }
    }

    func stopRecordingAction(_ completion: @escaping () -> Void) {
        Analytics.logEvent("Video Recording Finished", screenName, .buttonTap)
        resetGeneratingModel()

        arView?.finishVideoRecording { [weak self] info in
            self?.generatingModel.setProgress(0.5, animated: true)

            if self?.isShareCancelled ?? false {
                return
            }

            if NSUbiquitousKeyValueStore.default.shouldShowAnyDistanceBranding {
                self?.arView?.session.pause()

                FFMpegUtils.addWatermarkToVideo(atUrl: info.url, outputFilename: "AR-Video") { [weak self] in
                    return self?.isShareCancelled ?? true
                } progress: { [weak self] p in
                    self?.generatingModel.setProgress(0.5 + (p * 0.5), animated: true)
                } completion: { [weak self] outputUrl in
                    if self?.isShareCancelled ?? false {
                        return
                    }

                    if let config = self?.arView?.session.configuration {
                        self?.arView?.session.run(config)
                    }
                    self?.showShareScreen(withVideoUrl: outputUrl, noWatermarkUrl: info.url, completion: completion)
                }
            } else {
                self?.showShareScreen(withVideoUrl: info.url, noWatermarkUrl: info.url, completion: completion)
            }
        }
    }

    func routeTypeSwitched(_ routeType: ARRouteType) {}
    func medalViewModeSwitched(_ viewMode: MedalARViewMode) {}

    private func resetGeneratingModel() {
        generatingModel.setProgress(0, animated: false)
        isShareCancelled = false
    }

    private func showShareScreen(withVideoUrl outputUrl: URL, noWatermarkUrl: URL, completion: @escaping () -> Void) {
        let videos = ShareVideos(instagramStoryUrl: outputUrl, willRenderSquareVideo: false)
        videos.noWatermarkInstagramStoryUrl = noWatermarkUrl

        if let vc = UIStoryboard(name: "Activities", bundle: nil).instantiateViewController(withIdentifier: "shareVC") as? ShareViewController {
            vc.videos = videos
            vc.title = "Share"
            vc.showsAddToPostButton = shareScreenShowsAddToPostButton
            vc.delegate = self
            self.present(vc, animated: true, completion: nil)
            completion()
        }
    }

    // MARK: - ShareViewControllerDelegate
    
    func showReviewPromptIfNecessary() {}

    func addToPost(_ image: UIImage) {
        self.delegate?.arViewControllerShouldSetPhoto(image)
        presentingViewController?.dismiss(animated: true, completion: nil)
    }

    func addToPost(_ videoUrl: URL) {
        self.delegate?.arViewControllerShouldSetVideo(with: videoUrl)
        presentingViewController?.dismiss(animated: true, completion: nil)
    }
}

/// Convenience extension of SCNNode that clears all materials and geometry. Helpful for reducing
/// memory footprint when reloading SCNViews.
extension SCNNode {
    func cleanup() {
        for child in childNodes {
            child.cleanup()
        }

        for i in 0..<(geometry?.materials.count ?? 0) {
            geometry?.removeMaterial(at: i)
        }
        geometry = nil
    }
}
