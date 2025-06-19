// Licensed under the Any Distance Source-Available License
//
//  CutoutShapeView.swift
//  SwiftPlayground
//
//  Created by Jarod Luebbert on 10/3/22.
//

import UIKit
import AVFoundation
import Combine

fileprivate extension CGSize {
    
    func aspectFillSize(for imageSize: CGSize) -> CGSize {
        let minWidth = width / imageSize.width
        let minHeight = height / imageSize.height
        let size: CGSize
        if minHeight > minWidth {
            size = .init(width: minHeight * imageSize.width, height: height)
        } else if minWidth > minHeight {
            size = .init(width: width, height: minWidth * imageSize.height)
        }
        else {
            size = self
        }
        return size
    }
    
}

class CutoutShapeView: DesignableView {
    
    // MARK: Private
        
    private let zoomValue = PassthroughSubject<CGFloat, Never>()
    private let offsetValue = PassthroughSubject<CGPoint, Never>()
    
    private var maskedContentRect: CGRect = .zero {
        didSet {
            debugMaskedContentView.frame = maskedContentRect
        }
    }
    
    private var subscribers: Set<AnyCancellable> = []

    @IBOutlet private weak var blurredImageView: UIImageView!
    @IBOutlet private weak var visualEffectView: UIVisualEffectView!
    @IBOutlet private(set) weak var addMediaButtonImage: UIImageView!
    @IBOutlet private(set) weak var scrollView: UIScrollView!
    @IBOutlet private weak var scrollViewContentView: UIView!
    @IBOutlet private weak var scrollViewConstraintTop: NSLayoutConstraint!
    @IBOutlet private weak var scrollViewConstraintBottom: NSLayoutConstraint!
    @IBOutlet private weak var contentViewConstraintWidth: NSLayoutConstraint!
    @IBOutlet private weak var contentViewConstraintHeight: NSLayoutConstraint!
    @IBOutlet private(set) weak var cutoutImageView: UIImageView!
    @IBOutlet private weak var debugMaskedContentView: UIView!
    @IBOutlet private weak var imageView: UIImageView!
    @IBOutlet private(set) weak var videoView: UIView!
    @IBOutlet private weak var activityIndicator: UIActivityIndicatorView!
    
    // MARK: Public
    
    @IBOutlet private(set) weak var topGradient: UIImageView!
    @IBOutlet private(set) weak var bottomGradient: UIImageView!
    
    let zoomPublisher: AnyPublisher<CGFloat, Never>
    let offsetPublisher: AnyPublisher<CGPoint, Never>
    
    var debugEnabled: Bool = false {
        didSet {
            if debugEnabled {
                cutoutImageView.alpha = 0.5
                scrollView.layer.borderColor = UIColor.blue.cgColor
                scrollView.layer.borderWidth = 2.0
                scrollView.backgroundColor = .yellow.withAlphaComponent(0.5)
                scrollViewContentView.layer.borderColor = UIColor.red.cgColor
                scrollViewContentView.layer.borderWidth = 2.0
                debugMaskedContentView.isHidden = false
            } else {
                cutoutImageView.alpha = 1.0
                scrollView.layer.borderWidth = 0.0
                scrollView.backgroundColor = .clear
                scrollViewContentView.layer.borderWidth = 0.0
                debugMaskedContentView.isHidden = true
            }
        }
    }
    
    var image: UIImage? {
        didSet {
            UIView.transition(with: self,
                              duration: 0.2,
                              options: [.transitionCrossDissolve]) {
                self.imageView.image = self.image
                self.blurredImageView.image = self.image
            }
            
            if let image = image {
                recalculateContentViewSize(for: image.size)
            }
        }
    }
    
    var photoFrame: CGRect {
        return scrollView.frame
    }
    
    var photoZoom: CGFloat {
        get {
            scrollView.zoomScale
        }
        set {
            scrollView.zoomScale = newValue
        }
    }
    
    var photoOffset: CGPoint {
        get {
            scrollView.contentOffset
        }
        set {
            scrollView.contentOffset = newValue
            
            if newValue == .zero {
                centerContentView(animated: false)
            }
        }
    }
        
    var cutoutShape: CutoutShape = .fullScreen {
        didSet {
            UIView.transition(with: cutoutImageView,
                              duration: 0.2,
                              options: [.transitionCrossDissolve, .beginFromCurrentState],
                              animations: { self.cutoutImageView.image = self.cutoutShape.image },
                              completion: nil)
            
            topGradient.alpha = cutoutShape == .fullScreen ? 0.4 : 0.0
            
            recalculateMaskedContentSize()
            
            scrollView.contentInset = cutoutShape.insets
            
            guard oldValue != cutoutShape, let image = imageView.image else { return }
            self.recalculateContentViewSize(for: image.size)
            
            centerContentView(animated: false)
        }
    }
    
    // MARK: Exporting
    
    /// hide any views in preparation for exporting the view as an image
    func prepareForExport(_ isExporting: Bool) {
        cutoutImageView.alpha = 1.0
        addMediaButtonImage.isHidden = isExporting
        blurredImageView.isHidden = isExporting
        visualEffectView.isHidden = isExporting
    }
        
    // MARK: Binding
    
    func bind(to designPublishable: ActivityDesignPublishable) {
        subscribers.removeAll()
        
        designPublishable.media
            .receive(on: DispatchQueue.main)
            .sink { [weak self] media in
                guard let self = self else { return }
                self.scrollView.isScrollEnabled = media != .none
                self.addMediaButtonImage.alpha = media == .none ? 1.0 : 0.0
            }
            .store(in: &subscribers)
        
        designPublishable.cutoutShape
            .receive(on: DispatchQueue.main)
            .sink { [weak self] cutoutShape in
                guard let self = self else { return }
                self.cutoutShape = cutoutShape
            }
            .store(in: &subscribers)
    }
    
    // MARK: Helpers
    
    private func centerContentView(animated: Bool) {
        let width = scrollView.frame.width
        let height = scrollView.frame.height
        let centerOffsetX = (scrollView.contentSize.width - width) / 2.0
        let centerOffsetY = (scrollView.contentSize.height - height) / 2.0
        let xOffset = abs(scrollView.contentInset.left - scrollView.contentInset.right)
        let yOffset = abs(scrollView.contentInset.top - scrollView.contentInset.bottom)
        let centerPoint = CGPoint(x: max(centerOffsetX - xOffset, -scrollView.contentInset.left),
                                  y: max(centerOffsetY - yOffset, -scrollView.contentInset.top))
        scrollView.setContentOffset(centerPoint, animated: animated)
    }
    
    private func recalculateContentViewSize(for size: CGSize) {
        let size = maskedContentRect.size.aspectFillSize(for: size)
        contentViewConstraintWidth.constant = size.width
        contentViewConstraintHeight.constant = size.height
        layoutIfNeeded()
    }
    
    private func recalculateMaskedContentSize() {
        /// make the scroll view the same size as the mask image so our mask inset is correct
        let maskImageSize = cutoutShape.image?.size ?? scrollView.bounds.size
        let rect = AVMakeRect(aspectRatio: maskImageSize, insideRect: cutoutImageView.bounds)
        let verticalInset = ((frame.height - rect.height) / 2.0)
        scrollViewConstraintTop.constant = verticalInset
        scrollViewConstraintBottom.constant = verticalInset
        layoutIfNeeded()
        maskedContentRect = rect.inset(by: cutoutShape.insets)
        maskedContentRect.origin.y = verticalInset + cutoutShape.insets.top
    }
    
    // MARK: Overrides
    
    override init(frame: CGRect) {
        zoomPublisher = zoomValue.eraseToAnyPublisher()
        offsetPublisher = offsetValue.eraseToAnyPublisher()

        super.init(frame: frame)
    }
    
    required init?(coder aDecoder: NSCoder) {
        zoomPublisher = zoomValue.eraseToAnyPublisher()
        offsetPublisher = offsetValue.eraseToAnyPublisher()

        super.init(coder: aDecoder)
    }
    
    override func setup() {
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 7.0
        scrollView.delegate = self
        scrollView.decelerationRate = .fast
        
        backgroundColor = .clear
        
        let doubleTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap))
        doubleTapRecognizer.numberOfTapsRequired = 2
        scrollViewContentView.addGestureRecognizer(doubleTapRecognizer)
        
        cutoutShape = .fullScreen
    }
    
    // MARK: Gestures
    
    @objc private func handleDoubleTap() {
        scrollView.setZoomScale(1.0, animated: true)
    }
    
    // MARK: Animations
    
    func toggleActivityIndicator(hidden: Bool) {
        if hidden {
            activityIndicator.stopAnimating()
            addMediaButtonImage.isHidden = false
        } else {
            activityIndicator.startAnimating()
            addMediaButtonImage.isHidden = true
        }
    }
    
    private func fadeMaskImageView(_ fade: Bool) {
        UIView.animate(withDuration: 0.2,
                       delay: 0.0,
                       options: [.curveEaseInOut, .beginFromCurrentState]) { [weak self] in
            guard let self = self else { return }
            self.cutoutImageView.alpha = fade ? (self.debugEnabled ? 0.25 : 0.7) : (self.debugEnabled ? 0.5 : 1.0)
        }
    }
    
}

extension CutoutShapeView: UIScrollViewDelegate {
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return scrollViewContentView
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        guard scrollView.isTracking else { return }
        fadeMaskImageView(true)
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        guard scrollView.isTracking else { return }
        
        fadeMaskImageView(false)
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        offsetValue.send(scrollView.contentOffset)
    }
    
    func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
        guard scrollView.isTracking else { return }
        fadeMaskImageView(true)
    }
    
    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        zoomValue.send(scrollView.zoomScale)
        offsetValue.send(scrollView.contentOffset)
        
        guard scrollView.isTracking else { return }
        
        fadeMaskImageView(false)
    }
    
}
