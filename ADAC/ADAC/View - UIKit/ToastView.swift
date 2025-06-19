// Licensed under the Any Distance Source-Available License
//
//  ToastView.swift
//  ADAC
//
//  Created by Jarod Luebbert on 4/15/22.
//

import UIKit

class ToastView: UIView {
    
    static var defaultHeight: CGFloat = 72.0
    
    // MARK: - Handlers
    
    var dismissHandler: (() -> ())?
    var actionHandler: (() -> ())?
        
    // MARK: - UI
    
    private lazy var horizontalStackView: UIStackView = {
        let h = UIStackView(arrangedSubviews: [imageView, textContentStackView, accessoryImageView])
        h.axis = .horizontal
        h.alignment = .center
        h.distribution = .fillProportionally
        h.spacing = 14.0
        return h
    }()
    
    private lazy var textContentStackView: UIStackView = {
        let h = UIStackView(arrangedSubviews: [titleLabel, descriptionLabel])
        h.translatesAutoresizingMaskIntoConstraints = false
        h.axis = .vertical
        h.distribution = .fill
        h.spacing = 5.0
        return h
    }()
    
    private lazy var imageView: UIImageView = {
       let imageView = UIImageView(image: nil)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private lazy var titleLabel: UILabel = {
        let t = UILabel(frame: .zero)
        t.font = UIFont.systemFont(ofSize: 14.0, weight: .bold)
        t.textColor = .white
        return t
    }()
    
    private lazy var descriptionLabel: UILabel = {
        let t = UILabel(frame: .zero)
        t.numberOfLines = 1
        t.adjustsFontSizeToFitWidth = true
        t.font = UIFont.systemFont(ofSize: 13.0, weight: .medium)
        t.textColor = UIColor(hex: "A8A8A8")
        return t
    }()
    
    private lazy var accessoryImageView: UIImageView = {
        let imageView = UIImageView(image: UIImage(systemName: "arrow.right.circle.fill"))
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = UIColor(hex: "747474")
        return imageView
    }()
    
    // MARK: - Gesture
    
    private let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
    private var animator: UIDynamicAnimator?
    private var snapBehavior: UISnapBehavior?
    private lazy var panGesture: UIPanGestureRecognizer = {
        return UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(recognizer:)))
    }()
    
    struct Model: Hashable {
        let title: String
        let description: String
        let image: UIImage?
        let autohide: Bool
        let maxPerSession: Int // 0 for no limit
        
        init(title: String, description: String, image: UIImage?, autohide: Bool = false, maxPerSession: Int = 0) {
            self.title = title
            self.description = description
            self.image = image
            self.autohide = autohide
            self.maxPerSession = maxPerSession
        }
    }
    
    // MARK: - Setup
    
    private(set) var model: Model = Model(title: "", description: "", image: nil)
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    override init(frame: CGRect) {
        super.init(frame: .zero)
        setup()
    }
    
    convenience init(model: Model,
                     imageTint: UIColor = .adOrangeLighter,
                     borderTint: UIColor = .adOrangeLighter,
                     actionHandler: (() -> ())? = nil,
                     dismissHandler: (() -> ())? = nil) {
        self.init(frame: .zero)
        
        self.model = model
        
        self.actionHandler = actionHandler
        self.dismissHandler = dismissHandler
        
        backgroundColor = UIColor(hex: "252525")
        layer.borderColor = borderTint.cgColor
        layer.borderWidth = 2.0
        layer.cornerRadius = 18.0
        layer.cornerCurve = .continuous
        
        titleLabel.text = model.title
        descriptionLabel.text = model.description
        descriptionLabel.isHidden = model.description.isEmpty
        imageView.image = model.image
        imageView.tintColor = imageTint
        
        accessoryImageView.isHidden = model.autohide
    }
    
    private func setup() {
        addSubview(horizontalStackView)
        
        let imagePadding: CGFloat = 44.0
        NSLayoutConstraint.activate([
            imageView.heightAnchor.constraint(equalTo: horizontalStackView.heightAnchor, constant: -imagePadding),
            imageView.widthAnchor.constraint(equalTo: horizontalStackView.heightAnchor, constant: -imagePadding),

            accessoryImageView.heightAnchor.constraint(equalTo: horizontalStackView.heightAnchor, constant: -imagePadding),
            accessoryImageView.widthAnchor.constraint(equalTo: horizontalStackView.heightAnchor, constant: -imagePadding)
        ])
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        guard frame != .zero, animator == nil, let superview = superview else { return }
        
        animator = UIDynamicAnimator(referenceView: superview)
        snapBehavior = UISnapBehavior(item: self, snapTo: center)
        snapBehavior?.damping = 1.0
        animator?.addBehavior(snapBehavior!)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTapGesture(recognizer:)))
        addGestureRecognizer(tapGesture)
        
        addGestureRecognizer(panGesture)
        isUserInteractionEnabled = true

        let padding: CGFloat = 22.0
        horizontalStackView.frame = bounds.insetBy(dx: padding, dy: 0.0)
    }
    
    // MARK: - Gesture Handlers
    
    @objc private func handleTapGesture(recognizer: UITapGestureRecognizer) {
        if recognizer.state == .ended {
            actionHandler?()
            
            dismiss()
        }
    }
    
    @objc private func handlePanGesture(recognizer: UIPanGestureRecognizer) {
        guard let animator = animator, let snap = snapBehavior else {
            return
        }
        
        guard let view = recognizer.view,
              let superview = view.superview else { return }
        
        switch recognizer.state {
        case .began:
            animator.removeBehavior(snap)
        case .changed:
            let maxVerticalMovement = ToastView.defaultHeight
            let translation = recognizer.translation(in: self)
            
            let verticalMovement = abs(view.center.y - (snapBehavior?.snapPoint.y ?? 0.0))
            guard verticalMovement <= maxVerticalMovement else { return }
            
            let tension: CGFloat = 5.0
            view.center = CGPoint(x: view.center.x + (translation.x / tension),
                                  y: view.center.y + (translation.y / tension))
            recognizer.setTranslation(.zero, in: self)
        case .ended, .failed, .cancelled:
            let velocity = recognizer.velocity(in: superview)
            
            if (abs(atan2(velocity.y, velocity.x) - .pi / 2) > .pi / 4) {
                animator.addBehavior(snap)
                dismiss()
            } else {
                let velocityMagnitude = sqrtf(Float((velocity.x * velocity.x) + (velocity.y * velocity.y)))
                let push = UIPushBehavior(items: [view], mode: .instantaneous)
                push.pushDirection = .init(dx: velocity.x / 10.0, dy: velocity.y / 10.0)
                push.magnitude = CGFloat(velocityMagnitude / 35.0)
                let finalPoint = recognizer.location(in: superview)
                let center = view.center
                push.setTargetOffsetFromCenter(.init(horizontal: finalPoint.x - center.x,
                                                     vertical: finalPoint.y - center.y), for: view)
                push.action = { [weak self] in
                    if (!superview.bounds.intersects(view.frame)) {
                        self?.animator?.removeAllBehaviors()
                        view.removeFromSuperview()
                    }
                }
                
                let disableRotation = UIDynamicItemBehavior(items: [view])
                disableRotation.allowsRotation = false
                animator.addBehavior(disableRotation)
                animator.addBehavior(push)
                
                let gravity = UIGravityBehavior(items: [view])
                gravity.magnitude = 0.7
                animator.addBehavior(gravity)
            }
            
            dismissHandler?()
        default:
            break
        }
    }
    
    // MARK: - Public
    
    func impact() {
        impactGenerator.impactOccurred()
    }
    
    func dismiss() {
        guard let view = panGesture.view,
              let superview = view.superview else { return }

        UIView.animate(withDuration: 0.2) {
            view.alpha = 0.0
        }
        animator?.removeAllBehaviors()
        let gravity = UIGravityBehavior(items: [view])
        gravity.magnitude = 1.0
        animator?.addBehavior(gravity)
        gravity.action = {
            if (!superview.bounds.intersects(view.frame)) {
                view.removeFromSuperview()
            }
        }
    }
    
}
