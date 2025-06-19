// Licensed under the Any Distance Source-Available License
//
//  HorizontalImageRow.swift
//  ADAC
//
//  Created by Daniel Kuntz on 3/29/23.
//

import SwiftUI
import UIKit
import CoreGraphics
import Cache

fileprivate class HorizontalImageRowCache {
    static let shared = HorizontalImageRowCache()
    private var internalCache: Storage<String, UIImage>? // url string, image

    init() {
        let memoryConfig = MemoryConfig(expiry: .never,
                                        countLimit: 100,
                                        totalCostLimit: 10)

        internalCache = try? Storage<String, UIImage>(
            diskConfig: DiskConfig(name: "com.anydistance.HorizontalImageRowCache", maxSize: 1),
            memoryConfig: memoryConfig,
            transformer: TransformerFactory.forImage()
        )
    }

    func cachedImage(for url: URL) -> UIImage? {
        return try? internalCache?.object(forKey: url.absoluteString)
    }

    func cache(image: UIImage, for url: URL) {
        try? internalCache?.setObject(image, forKey: url.absoluteString)
    }
}

class HorizontalImageRowView: UIView {
    private let imageSize: CGSize
    private let imageSpacing: CGFloat
    private var collectibles: [Collectible] = []
    private var imageUrls: [URL] = []
    private var images: [(Collectible, UIImage)] = []
    private var latestFramesForURLs: [CGRect: Collectible] = [:]
    private var xOffset: CGFloat = 0
    private var displayLink: CADisplayLink?
    private var alwaysAnimate: Bool = false
    private var centered: Bool = false
    private var load: Int = 0
    private var i = 0
    private var loadedAlphaRamp: CGFloat = 0.0
    private var onTap: ((Collectible) -> Void)?

    init(frame: CGRect,
         imageSize: CGSize,
         imageSpacing: CGFloat,
         collectibles: [Collectible],
         alwaysAnimate: Bool,
         centered: Bool = false,
         onTap: ((Collectible) -> Void)?) {
        self.imageSize = CGSize(width: imageSize.width,
                                height: imageSize.height.rounded())
        self.imageSpacing = imageSpacing
        self.collectibles = collectibles
        self.imageUrls = collectibles.compactMap { $0.medalImageUrl }
        self.alwaysAnimate = alwaysAnimate
        self.centered = centered
        self.onTap = onTap

        super.init(frame: frame)
        self.contentScaleFactor = 1.0
        self.layer.contentsScale = 1.0

        self.backgroundColor = .clear
        loadImages()

        let tapGR = UITapGestureRecognizer(target: self, action: #selector(viewTapped(_:)))
        self.addGestureRecognizer(tapGR)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setCollectibles(_ collectibles: [Collectible]) {
        if collectibles != self.collectibles {
            self.collectibles = collectibles
            self.imageUrls = collectibles.compactMap { $0.medalImageUrl }
            self.loadImages()
        }
    }

    private func loadImages() {
        self.images.removeAll()
        self.loadedAlphaRamp = 0.0
        load += 1
        let curLoad = load

        for collectible in collectibles {
            guard let imageUrl = collectible.medalImageUrl else {
                continue
            }

            Task(priority: .userInitiated) {
                if let cached = HorizontalImageRowCache.shared.cachedImage(for: imageUrl) {
                    let resizedImage = cached.resized(withNewWidth: self.imageSize.width)
                    guard let preparedImage = await resizedImage.byPreparingForDisplay() else {
                        return
                    }
                    self.images.append((collectible, preparedImage))
                    self.setNeedsDisplay()
                } else {
                    ParallelImageLoader.loadImage(with: imageUrl) { image in
                        Task(priority: .userInitiated) {
                            let resizedImage = image?.resized(withNewWidth: self.imageSize.width)
                            guard let preparedImage = await resizedImage?.byPreparingForDisplay() else {
                                return
                            }

                            DispatchQueue.main.async { [weak self] in
                                guard let self = self,
                                      self.load == curLoad else { return }
                                self.images.append((collectible, preparedImage))
                                self.setNeedsDisplay()
                                HorizontalImageRowCache.shared.cache(image: preparedImage,
                                                                     for: imageUrl)
                            }
                        }
                    }
                }
            }
        }
    }

    @objc private func viewTapped(_ tapGR: UITapGestureRecognizer) {
        guard !images.isEmpty,
              images.count == imageUrls.count else {
            return
        }

        let location = tapGR.location(in: self)
        let nearestCollectible: Collectible? = {
            let frames = latestFramesForURLs.map { $0 }
            for frame in frames {
                let outsetFrame = frame.key.insetBy(dx: -2 * imageSpacing,
                                                    dy: -1 * imageSpacing)
                if outsetFrame.contains(location) {
                    return frame.value
                }
            }
            return nil
        }()

        guard let nearestCollectible = nearestCollectible else {
            return
        }

        onTap?(nearestCollectible)
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.interpolationQuality = .low

        context.clear(rect)

        guard !images.isEmpty,
              images.count == imageUrls.count else {
            return
        }

        var updatedFramesForURLs: [CGRect: Collectible] = [:]

        var totalImageWidth = (imageSize.width + imageSpacing) * CGFloat(images.count)
        if totalImageWidth < (bounds.width - imageSize.width) {
            totalImageWidth -= imageSpacing

            for (i, image) in images.enumerated() {
                let idx: CGFloat = CGFloat(i)
                let leadingPadding = centered ? ((bounds.width / 2) - (totalImageWidth / 2)) : 20
                let rect = CGRect(x: leadingPadding + ((imageSpacing + imageSize.width) * idx).rounded(),
                                  y: ((bounds.height - imageSize.height) / 2).rounded(),
                                  width: imageSize.width,
                                  height: imageSize.height)
                if loadedAlphaRamp <= 1.0 {
                    image.1.draw(at: rect.origin, blendMode: .normal, alpha: loadedAlphaRamp)
                } else {
                    image.1.draw(at: rect.origin)
                }
                updatedFramesForURLs[rect] = image.0
            }
        } else {
            if i == 1 {
                xOffset -= 1.0
                i = 0
            } else {
                i = 1
            }

            if xOffset <= -(imageSize.width + imageSpacing) {
                xOffset += imageSize.width + imageSpacing
                images.append(images.removeFirst())
            }

            var currentXOffset = xOffset
            var idx = 0

            while currentXOffset < bounds.width {
                let image = images[idx]
                let rect = CGRect(x: currentXOffset,
                                  y: ((bounds.height - imageSize.height) / 2).rounded(),
                                  width: imageSize.width,
                                  height: imageSize.height)
                if loadedAlphaRamp <= 1.0 {
                    image.1.draw(at: rect.origin, blendMode: .normal, alpha: loadedAlphaRamp)
                } else {
                    image.1.draw(at: rect.origin)
                }
                currentXOffset += imageSize.width + imageSpacing
                idx = (idx + 1) % images.count

                updatedFramesForURLs[rect] = image.0
            }
        }

        latestFramesForURLs = updatedFramesForURLs
        loadedAlphaRamp = (loadedAlphaRamp + 0.05).clamped(to: 0...1)
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()

        if window != nil {
            displayLink?.invalidate()
            displayLink = CADisplayLink(target: self, selector: #selector(update))
//            displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 90, maximum: 120)
            displayLink?.add(to: .main, forMode: .common)
        } else {
            displayLink?.invalidate()
            displayLink = nil
        }
    }

    @objc private func update() {
        guard UIApplication.shared.topViewController is UITabBarController ||
              UIApplication.shared.topViewController is ProfileViewController ||
              alwaysAnimate else {
            return
        }

        setNeedsDisplay()
    }
}

extension CGRect: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(origin.x)
        hasher.combine(origin.y)
        hasher.combine(size.width)
        hasher.combine(size.height)
    }
}

struct HorizontalImageRow: UIViewRepresentable {
    let imageSize: CGSize
    let imageSpacing: CGFloat
    let collectibles: [Collectible]
    let alwaysAnimate: Bool
    var centered: Bool = false
    let onTap: ((Collectible) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> HorizontalImageRowView {
        let view = HorizontalImageRowView(frame: .zero,
                                          imageSize: imageSize,
                                          imageSpacing: imageSpacing,
                                          collectibles: collectibles,
                                          alwaysAnimate: alwaysAnimate,
                                          centered: centered,
                                          onTap: onTap)
        return view
    }

    func updateUIView(_ uiView: HorizontalImageRowView, context: Context) {
        uiView.setCollectibles(collectibles)
    }

    class Coordinator: NSObject {
        var parent: HorizontalImageRow

        init(_ parent: HorizontalImageRow) {
            self.parent = parent
        }
    }
}
