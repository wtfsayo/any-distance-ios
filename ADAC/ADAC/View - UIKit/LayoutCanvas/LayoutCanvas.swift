// Licensed under the Any Distance Source-Available License
//
//  LayoutCanvas.swift
//  ADAC
//
//  Created by Daniel Kuntz on 12/17/20.
//

import UIKit
import CoreLocation
import AVKit
import MobileCoreServices
import PureLayout
import UIImageColors
import Combine

protocol LayoutCanvasDelegate: AnyObject {
    func canvasTapped()
    func finishedMovingRoute(to transform: CGAffineTransform)
}

final class LayoutCanvas: DesignableView, UIScrollViewDelegate {

    // MARK: - Outlets

    @IBOutlet private(set) weak var cutoutShapeView: CutoutShapeView!
    @IBOutlet weak var goalProgressIndicator: GoalProgressIndicator!
    @IBOutlet weak var goalProgressDistanceLabel: UILabel!
    @IBOutlet weak var goalProgressYearLabel: UILabel!
    @IBOutlet weak var watermark: UIImageView!
    @IBOutlet weak var watermarkTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var watermarkLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var graphContainer: MovableView!
    @IBOutlet weak var graphImageView: UIImageView!
    @IBOutlet weak var locationActivityTypeView: LocationActivityTypeView!
    @IBOutlet weak var locationActivityTypeTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var stackView: StatisticStackView!
    @IBOutlet weak var route3DView: Route3DView!
    @IBOutlet weak var tintView: GradientView!
    @IBOutlet weak var superDistanceWatermark: UIImageView!

    // MARK: - Variables


    private(set) var locationOn: Bool = true
    private(set) var goalExists: Bool = true
    private(set) var prevAlignment: StatisticAlignment?
    private(set) var videoMode: VideoMode = .loop

    var mediaType: ActivityDesign.Media = .none {
        didSet {
            switch mediaType {
            case .none, .arVideo:
                break
            case .photo, .fill:
                route3DView.renderer.pausedForVideo = false
                route3DView.restartAnimation()
            case .video:
                route3DView.renderer.pausedForVideo = true
            }
        }
    }

    private var player: AVPlayerLooper?
    private var queuePlayer: AVQueuePlayer?
    private(set) var playerLayer: AVPlayerLayer?

    weak var delegate: LayoutCanvasDelegate?
    private var subscribers: Set<AnyCancellable> = []

    // MARK: - Setup

    override func awakeFromNib() {
        super.awakeFromNib()

        graphContainer.layer.masksToBounds = false
        backgroundColor = .clear
        tintView.isUserInteractionEnabled = false
        tintView.startPoint = CGPoint(x: 0.5, y: 0.0)
        tintView.endPoint = CGPoint(x: 0.5, y: 1.0)

        let tapGR = UITapGestureRecognizer(target: self, action: #selector(canvasTapped(_:)))
        tapGR.numberOfTapsRequired = 1
        for gr in graphContainer.gestureRecognizers ?? [] {
            tapGR.require(toFail: gr)
        }
        addGestureRecognizer(tapGR)
    }
    
    @objc private func canvasTapped(_ sender: Any) {
        delegate?.canvasTapped()
    }
    
    // MARK: - Rendering

    func render(activity: Activity) {
        stackView.setStatistics(fromActivity: activity)

        locationActivityTypeView.locationContainer.alpha = 0.0

        watermark.layer.minificationFilter = .trilinear
        watermark.layer.minificationFilterBias = 0.05
        watermark.image = UIImage(named: "watermark_v2")

        graphImageView.layer.minificationFilter = .trilinear
        graphImageView.layer.minificationFilterBias = 0.06
        graphImageView.layer.zPosition = 1000.0
        cutoutShapeView.toggleActivityIndicator(hidden: false)

        locationActivityTypeView.activityTypeImageView.image = activity.activityType.glyph

        Task {
            let cityAndState = try? await activity.cityAndState
            setCityState(cityAndState)
        }
    }

    func render(stepCount: DailyStepCount) {
        route3DView.isHidden = true
        stackView.setStatistics(fromStepCount: stepCount)

        locationActivityTypeView.locationContainer.alpha = 0.0
        goalProgressIndicator.alpha = 0.0
        goalProgressDistanceLabel.alpha = 0.0
        goalProgressYearLabel.alpha = 0.0

        watermark.layer.minificationFilter = .trilinear
        watermark.layer.minificationFilterBias = 0.05
        graphImageView.layer.minificationFilter = .trilinear
        graphImageView.layer.minificationFilterBias = 0.06

        locationActivityTypeView.activityTypeImageView.image = DailyStepCount.glyph
    }

    // MARK: - Setters

    func setSuperDistanceWatermarkVisible(_ visible: Bool) {
        UIView.animate(withDuration: 0.3) {
            self.superDistanceWatermark.alpha = visible ? 0.5 : 0.0
        }
    }

    func setGoal(_ goal: Goal?) {
        if let goal = goal {
            let formatter = DateFormatter()
            formatter.dateFormat = "yy"
            let year = formatter.string(from: goal.endDate)

            formatter.dateFormat = "MMM"
            let month = formatter.string(from: goal.endDate).uppercased()
            goalProgressYearLabel.text = "\(month) '\(year)"

            let activityDistance = goal.distanceInSelectedUnit.rounded()
            goalProgressDistanceLabel.text = "\(Int(activityDistance))/\(Int(goal.targetDistanceInSelectedUnit))\(goal.unit.abbreviation.uppercased())"
            goalProgressIndicator.setProgress(activityDistance/Float(goal.targetDistanceInSelectedUnit))
        } else {
            self.goalProgressIndicator.alpha = 0.0
            self.goalProgressDistanceLabel.alpha = 0.0
            self.goalProgressYearLabel.alpha = 0.0
            goalExists = false
        }

    }

    private func setCityState(_ cityState: String?) {
        locationActivityTypeView.setLocationText(cityState)
    }

    func changedVideo(asset: AVAsset) {
        let item = AVPlayerItem(asset: asset)
        if queuePlayer == nil {
            queuePlayer = AVQueuePlayer(playerItem: item)
        } else {
            queuePlayer?.removeAllItems()
            queuePlayer?.insert(item, after: nil)
        }
        player = AVPlayerLooper(player: queuePlayer!, templateItem: item)
        setupPlayerLayer()
    }

    private func setupPlayerLayer() {
        if playerLayer == nil {
            playerLayer = AVPlayerLayer(player: queuePlayer)
            playerLayer?.frame = cutoutShapeView.videoView.bounds
            playerLayer?.videoGravity = .resizeAspectFill
            cutoutShapeView.videoView.layer.addSublayer(playerLayer!)
        }

        queuePlayer?.play()
    }

    func muteVideo() {
        queuePlayer?.volume = 0.0
    }

    func unmuteVideo() {
        queuePlayer?.volume = 1.0
        queuePlayer?.play()
    }
    
    func removeVideo() {
        queuePlayer?.pause()
        queuePlayer = nil
        player = nil
        playerLayer?.removeFromSuperlayer()
        playerLayer = nil
    }

    func removePhoto() {
        UIView.transition(with: cutoutShapeView, duration: 0.2, options: [.transitionCrossDissolve, .layoutSubviews], animations: {
            self.cutoutShapeView.image = nil
        }, completion: nil)
    }

    func setPalette(_ palette: Palette, for activity: Activity, animated: Bool = true) {
        stackView.setPalette(palette, animated: animated)
        locationActivityTypeView.setPalette(palette, animated: animated)
        route3DView.setPalette(palette)

        let animDuration: TimeInterval = animated ? 0.3 : 0.0
        UIView.animate(withDuration: animDuration, delay: 0.0, options: [.curveEaseInOut, .beginFromCurrentState], animations: {
            self.cutoutShapeView.cutoutImageView.tintColor = palette.backgroundColor
            self.goalProgressDistanceLabel.textColor = palette.foregroundColor
            self.goalProgressYearLabel.textColor = palette.foregroundColor
            self.goalProgressIndicator.setInactiveTrackTintColor(palette.foregroundColor)

            let clearBg = palette.backgroundColor.withAlphaComponent(0.0)
            let paletteBg = palette.backgroundColor.withAlphaComponent(0.3)
            if palette.name == "Dark" || palette.backgroundColor.isReallyDark {
                self.tintView.colors = [clearBg, clearBg]
            } else {
                self.tintView.colors = [paletteBg, paletteBg]
            }
        }, completion: nil)
    }

    func setAlignment(_ alignment: StatisticAlignment, animated: Bool = true) {
        stackView.setStatisticAlignment(alignment, animated: animated)
        updateLocationActivityTypePosition(withAlignment: alignment, prevAlignment: prevAlignment, animated: animated)
        prevAlignment = alignment
    }

    func pause3DRoute() {
        route3DView.isPlaying = false
    }

    func unpause3DRoute() {
        route3DView.isPlaying = true
    }

    func setGraphType(_ graphType: GraphType, for activity: Activity, palette: Palette, animated: Bool = true, restartAnimation: Bool = true) {
        let block = { [weak self] in
            guard let self = self else { return }
            switch graphType {
            case .none:
                self.graphImageView.alpha = 0.0
                self.route3DView.alpha = 0.0
                self.route3DView.isPlaying = false
            case .route2d:
                self.route3DView.alpha = 0.0
                self.route3DView.isPlaying = false
                self.graphImageView.alpha = 1.0
                self.graphContainer.isRotationEnabled = true
                self.graphContainer.isScaleEnabled = true
            case .route3d:
                if restartAnimation {
                    self.route3DView.restartAnimation()
                }
                self.route3DView.alpha = 1.0
                self.route3DView.isPlaying = true
                self.graphImageView.alpha = 1.0
                self.graphContainer.isRotationEnabled = false
                self.graphContainer.isScaleEnabled = false
                Task {
                    let coordinates = try? await activity.coordinates
                    DispatchQueue.main.async {
                        self.route3DView.renderLine(withCoordinates: coordinates ?? [])
                    }
                }
            case .splits:
                self.route3DView.alpha = 0.0
                self.route3DView.isPlaying = false
                self.graphImageView.alpha = 1.0
                self.graphContainer.isRotationEnabled = true
                self.graphContainer.isScaleEnabled = true
            case .heartRate:
                self.route3DView.alpha = 0.0
                self.route3DView.isPlaying = false
                self.graphImageView.alpha = 1.0
                self.graphContainer.isRotationEnabled = false
                self.graphContainer.isScaleEnabled = true
            case .elevation:
                self.route3DView.alpha = 0.0
                self.route3DView.isPlaying = false
                self.graphImageView.alpha = 1.0
                self.graphContainer.isRotationEnabled = false
                self.graphContainer.isScaleEnabled = true
            case .stepCount:
                self.route3DView.alpha = 0.0
                self.route3DView.isPlaying = false
                self.graphImageView.alpha = 1.0
                self.graphContainer.isRotationEnabled = true
                self.graphContainer.isScaleEnabled = true
            }
        }
        
        if graphType == .none {
            graphContainer.delegate = nil
            graphContainer.isHidden = true
            graphContainer.isUserInteractionEnabled = false
            graphContainer.gesturesEnabled = false
        } else {
            graphContainer.delegate = self
            graphContainer.isHidden = false
            graphContainer.isUserInteractionEnabled = true
            graphContainer.gesturesEnabled = true
        }
        
        if animated {
            UIView.animate(withDuration: 0.3) {
                block()
            }
        } else {
            block()
        }
    }

    private func updateLocationActivityTypePosition(withAlignment alignment: StatisticAlignment,
                                                    prevAlignment: StatisticAlignment?,
                                                    animated: Bool) {
        if let prevAlignment = prevAlignment {
            switch alignment {
            case .left, .center:
                guard prevAlignment == .right else {
                    return
                }
            case .right:
                guard prevAlignment != .right else {
                    return
                }
            }
        }

        func installNewConstraint() {
            switch alignment {
            case .left, .center:
                self.locationActivityTypeTrailingConstraint.autoRemove()
                self.locationActivityTypeTrailingConstraint = self.locationActivityTypeView.autoPinEdge(toSuperviewSafeArea: .trailing, withInset: 26)
            case .right:
                self.locationActivityTypeTrailingConstraint.autoRemove()
                self.locationActivityTypeTrailingConstraint = self.locationActivityTypeView.autoPinEdge(toSuperviewSafeArea: .leading, withInset: 26)
            }
        }

        if !animated {
            installNewConstraint()
            layoutIfNeeded()
            return
        }

        UIView.animate(withDuration: 0.15) {
            self.locationActivityTypeView.alpha = 0
        } completion: { finished in
            installNewConstraint()
            self.layoutIfNeeded()
            UIView.animate(withDuration: 0.3) {
                self.locationActivityTypeView.alpha = 1
            }
        }
    }

    func setCutoutShape(_ shape: CutoutShape, animated: Bool = true) {
        if animated {
            UIView.animate(withDuration: 0.2) {
                self.cutoutShapeView.cutoutShape = shape
            }
        } else {
            cutoutShapeView.cutoutShape = shape
        }

        switch shape {
        case .dip, .rounded:
            watermarkLeadingConstraint.constant = 28.0
            watermarkTopConstraint.constant = 45.0
        default:
            watermarkLeadingConstraint.constant = 16.0
            watermarkTopConstraint.constant = 30.0
        }

        layoutIfNeeded()
    }

    func setFont(_ font: ADFont) {
        stackView.setFont(font)
        locationActivityTypeView.setLocationLabelFont(font)
    }

    func toggleActivityType(on: Bool? = nil, animated: Bool = true) {
        let enabled = on ?? !locationActivityTypeView.activityTypeOn
        locationActivityTypeView.toggleActivityType(on: enabled, animated: animated)
    }

    func toggleLocation(on: Bool? = nil, animated: Bool = true) {
        let enabled = on ?? !locationActivityTypeView.locationOn
        locationActivityTypeView.toggleLocation(on: enabled, animated: animated)
    }

    func toggleGoalProgress(on: Bool? = nil, animated: Bool = true) {
        let enabled = on ?? (goalProgressIndicator.alpha == 0)

        UIView.animate(withDuration: animated ? 0.2 : 0) {
            let alpha: CGFloat = enabled ? 1 : 0
            self.goalProgressIndicator.alpha = alpha
            self.goalProgressDistanceLabel.alpha = alpha
            self.goalProgressYearLabel.alpha = alpha
        }
    }

    func updateStatistic(_ type: StatisticType, for activity: Activity, design: ActivityDesign, animated: Bool = true) {
        let on = design.shows(statisticType: type)
        switch type {
        case .location:
            toggleLocation(on: on, animated: animated)
        case .activityType:
            toggleActivityType(on: on, animated: animated)
        case .goal:
            toggleGoalProgress(on: on, animated: animated)
        case .graph:
            setGraphType(design.graphType, for: activity, palette: design.palette, animated: animated)
        default:
            stackView.toggleStatistic(type, on: on, animated: animated)
        }
    }
}

extension LayoutCanvas: MovableViewDelegate {
    func movableView(_ movableView: MovableView, finishedTransformingTo newTransform: CGAffineTransform) {
        delegate?.finishedMovingRoute(to: newTransform)
    }

    func movableView(_ movableView: MovableView, scaledTo scale: CGFloat) {
        route3DView.setZoom(scale)
    }
}
