// Licensed under the Any Distance Source-Available License
//
//  EditorControlsButtonView.swift
//  ADAC
//
//  Created by Daniel Kuntz on 4/26/21.
//

import UIKit
import PureLayout
import SDWebImage

final class EditorControlsButtonView: UIView {

    // MARK: - Constants

    private let selectedTintColor = UIColor.adOrangeLighter
    private let deselectedTintColor = UIColor.adGray3
    private let selectedBorderColor = UIColor.white
    private let deselectedBorderColor = UIColor.white.withAlphaComponent(0.3)

    // MARK: - Variables

    private(set) var label: UILabel!
    private(set) var buttonContainer: UIView!
    private(set) var button: LoadingButton!
    private(set) var bottomRightImageView: UIImageView?
    private(set) var fillImageView: UIImageView!
    private(set) var topRightImageView: UIImageView?
    var tapHandler: ((EditorControlsButtonView) -> Void)?
    private(set) var isSelected: Bool = false
    private(set) var palette: Palette?
    private(set) var fill: Fill?
    private(set) var filter: PhotoFilter?
    private var type: EditorControlsButtonViewType = .templateImage
    private var interactionEnabled: Bool = true

    var isLocked: Bool = false {
        didSet {
            topRightImageView?.isHidden = !isLocked
        }
    }

    var hasWarningIndicator: Bool = false {
        didSet {
            if hasWarningIndicator {
                topRightImageView?.image = UIImage(named: "glyph_i")
                topRightImageView?.isHidden = false
            } else {
                topRightImageView?.image = UIImage(named: "glyph_lock")
                topRightImageView?.isHidden = !isLocked
            }
        }
    }

    var id: String {
        return button.id
    }

    init(title: String,
         image: UIImage?,
         imageEdgeInsets: UIEdgeInsets? = nil,
         bottomRightImage: UIImage? = nil,
         id: String = "") {
        super.init(frame: .zero)
        setupWith(title: title,
                  image: image,
                  imageEdgeInsets: imageEdgeInsets,
                  bottomRightImage: bottomRightImage,
                  id: id)
    }

    func setupWith(title: String,
         image: UIImage?,
         imageEdgeInsets: UIEdgeInsets? = nil,
         bottomRightImage: UIImage? = nil,
         id: String = "") {
        backgroundColor = .clear
        layer.masksToBounds = false
        clipsToBounds = false

        label = UILabel()
        label.text = title
        label.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .white
        addSubview(label)
        sendSubviewToBack(label)

        buttonContainer = UIView()
        buttonContainer.backgroundColor = .clear
        buttonContainer.layer.masksToBounds = false
        addSubview(buttonContainer)
        sendSubviewToBack(buttonContainer)
        buttonContainer.autoPinEdgesToSuperviewEdges()

        button = LoadingButton()
        button.id = id
        button.setImage(image?.withRenderingMode(.alwaysTemplate), for: .normal)
        button.imageView?.tintColor = deselectedTintColor
        button.imageView?.contentMode = .scaleAspectFit
        if #available(iOS 15.0, *) {
            button.configuration?.contentInsets = NSDirectionalEdgeInsets(top: imageEdgeInsets?.top ?? 0,
                                                                          leading: imageEdgeInsets?.left ?? 0,
                                                                          bottom: imageEdgeInsets?.bottom ?? 0,
                                                                          trailing: imageEdgeInsets?.right ?? 0)
        } else {
            button.imageEdgeInsets = imageEdgeInsets ?? .zero
        }
        buttonContainer.addSubview(button)

        button.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 10, left: 0, bottom: 0, right: 0), excludingEdge: .bottom)
        button.autoMatch(.height, to: .height, of: self, withMultiplier: 0.75)
        label.autoPinEdge(toSuperviewEdge: .bottom)
        label.autoAlignAxis(toSuperviewAxis: .vertical)
        label.autoPinEdge(.top, to: .bottom, of: button)

        button.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)

        if let bottomRightImage = bottomRightImage {
            bottomRightImageView = UIImageView(image: bottomRightImage)
            bottomRightImageView?.contentMode = .scaleAspectFit
            buttonContainer.addSubview(bottomRightImageView!)

            bottomRightImageView?.autoSetDimensions(to: CGSize(width: 52, height: 52))
            bottomRightImageView?.autoPinEdge(.bottom, to: .bottom, of: button, withOffset: 0)
            bottomRightImageView?.autoPinEdge(.trailing, to: .trailing, of: button, withOffset: 16)
        }
        
        fillImageView = UIImageView(frame: .zero)
        fillImageView.layer.cornerCurve = .continuous
        fillImageView.layer.cornerRadius = 3.5
        fillImageView.layer.masksToBounds = true
        buttonContainer.addSubview(fillImageView)
        fillImageView.autoSetDimensions(to: .init(width: 34, height: 56))
        fillImageView.autoAlignAxis(.horizontal, toSameAxisOf: button)
        fillImageView.autoAlignAxis(.vertical, toSameAxisOf: button)

        topRightImageView = UIImageView(image: UIImage(named: "glyph_lock"))
        buttonContainer.addSubview(topRightImageView!)
        topRightImageView?.autoPinEdge(.top, to: .top, of: button, withOffset: -14)
        topRightImageView?.autoPinEdge(.trailing, to: .trailing, of: button, withOffset: 17)
        topRightImageView?.isHidden = !isLocked
    }

    func setPalette(_ palette: Palette) {
        type = .colorPalette
        self.palette = palette

        let size = CGSize(width: 46, height: 68)
        let frame = CGRect(origin: .zero, size: size)
        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale
        DispatchQueue.global(qos: .userInitiated).async {
            let renderer = UIGraphicsImageRenderer.init(size: size, format: format)
            let buttonImage = renderer.image { ctx in
                let roundedPath = UIBezierPath(roundedRect: frame.insetBy(dx: 6, dy: 6), cornerRadius: 3.5)
                roundedPath.addClip()
                palette.backgroundColor.setFill()
                ctx.fill(CGRect(x: 0, y: 0, width: size.width, height: size.height / 2))
                palette.foregroundColor.setFill()
                ctx.fill(CGRect(x: 0, y: size.height / 2, width: size.width, height: size.height / 2))
                palette.accentColor.setFill()
                let dotWidth = size.width * 0.38
                let path = UIBezierPath(ovalIn: CGRect(x: (size.width / 2) - (dotWidth / 2),
                                                       y: (size.height / 2) - (dotWidth / 2),
                                                       width: dotWidth,
                                                       height: dotWidth))
                path.fill()
            }

            DispatchQueue.main.async { [weak self] in
                self?.button.setImage(buttonImage, for: .normal)
            }
        }

        button.borderSize = size
        button.borderCornerRadius = 8
        button.borderWidth = 3
        setSelected(isSelected, animated: false)
    }

    func setPhotoFilter(_ filter: PhotoFilter, originalImage: UIImage) {
        type = .photoFilter
        self.filter = filter

        button.imageView?.contentMode = .scaleAspectFill
        button.imageView?.layer.cornerRadius = 8
        button.imageView?.layer.cornerCurve = .continuous
        button.imageView?.layer.masksToBounds = true
        button.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)

        Task {
//            if let filteredImage = try? await filter.applied(to: originalImage) {
//                button.setImage(filteredImage, for: .normal)
//                setSelected(isSelected, animated: false)
//            } else {
//                button.setImage(UIImage(named: "glyph_nofilter"), for: .normal)
//                setSelected(isSelected, animated: false)
//            }
        }
    }

    func setFill(_ fill: Fill?) {
        type = .fill
                
        self.fill = fill

        button.borderSize = CGSize(width: 46, height: 68)
        button.borderCornerRadius = 8
        button.borderWidth = 3
        
        if let image = fill?.imageThumbnail {
            button.setImage(nil, for: .normal)
            fillImageView.image = image
        } else {
            button.setImage(UIImage(named: "glyph_no_fill"), for: .normal)
            fillImageView.image = nil
        }

        setSelected(isSelected, animated: false)
    }

    func setSelected(_ selected: Bool, animated: Bool = true) {
        self.isSelected = selected

        let block = {
            switch self.type {
            case .templateImage:
                self.button.borderColor = nil
                self.buttonContainer.alpha = 1.0
                self.button.imageView?.tintColor = selected ? self.selectedTintColor : self.deselectedTintColor
                self.label.textColor = selected ? self.selectedTintColor : .white
            case .photoFilter:
                self.button.borderColor = nil
                self.buttonContainer.alpha = 1.0
                self.label.textColor = selected ? self.selectedTintColor : .white
            case .colorPalette, .fill:
                self.buttonContainer.alpha = 1.0
                self.button.borderColor = selected ? self.selectedBorderColor : self.deselectedBorderColor
                self.button.imageView?.tintColor = selected ? self.selectedBorderColor : self.deselectedBorderColor
                self.label.textColor = selected ? self.selectedTintColor : .white
            }
        }

        if animated {
            UIView.transition(with: self,
                              duration: 0.2,
                              options: [.transitionCrossDissolve, .allowAnimatedContent],
                              animations: block, completion: nil)
        } else {
            block()
        }
    }

    func enableInteraction(_ enable: Bool) {
        if !enable {
            setSelected(false)
            button.alpha = 0.3
            label.alpha = 0.3
            interactionEnabled = false
        } else {
            button.alpha = 1.0
            label.alpha = 1.0
            interactionEnabled = true
        }
    }

    func setLoading(_ loading: Bool) {
        button.isLoading = loading
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupWith(title: "", image: nil, imageEdgeInsets: nil, bottomRightImage: nil, id: "")
    }

    @objc private func buttonTapped() {
        if isLocked && !hasWarningIndicator {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } else if interactionEnabled || hasWarningIndicator {
            tapHandler?(self)
        }
    }
}

enum EditorControlsButtonViewType {
    case photoFilter
    case colorPalette
    case templateImage
    case fill
}
