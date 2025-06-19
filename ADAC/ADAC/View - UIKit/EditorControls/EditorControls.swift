// Licensed under the Any Distance Source-Available License
//
//  EditorControls.swift
//  ADAC
//
//  Created by Daniel Kuntz on 12/22/20.
//

import UIKit
import AVFoundation
import Combine

protocol EditorControlsDelegate: AnyObject {
    func filtersSubmenuTapped() -> Bool
    func detailsStatisticTapped(_ statistic: StatisticType)
    func showConnect(for service: ExternalService)
    func didSelectGraphType(graphType: GraphType)
}

@IBDesignable final class EditorControls: DesignableView {
    
    var viewModel: ActivityDesignViewModel! {
        didSet {
            bindViewModel()
        }
    }

    // MARK: - Constants

    static let buttonWidth: CGFloat = 60
    static let buttonSpacing: CGFloat = 8

    // MARK: - Outlets

    @IBOutlet weak var mainScrollView: UIScrollView!
    @IBOutlet weak var mainScrollViewLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var loopBounceView: UIView!
    @IBOutlet weak var loopBounceViewWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var mediaView: EditorControlsButtonView!
    @IBOutlet weak var filtersView: EditorControlsButtonView!
    @IBOutlet weak var loopView: EditorControlsButtonView!
    @IBOutlet weak var bounceView: EditorControlsButtonView!
    @IBOutlet weak var layoutsView: EditorControlsButtonView!
    @IBOutlet weak var graphsView: EditorControlsButtonView!
    @IBOutlet weak var graphsViewWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var graphsViewTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var colorsView: EditorControlsButtonView!
    @IBOutlet weak var fillsView: EditorControlsButtonView!
    @IBOutlet weak var fontsView: EditorControlsButtonView!
    @IBOutlet weak var statsView: EditorControlsButtonView!

    @IBOutlet weak var mediaScrollView: UIScrollView!
    @IBOutlet weak var mediaReplaceView: EditorControlsButtonView!
    @IBOutlet weak var mediaRemoveView: EditorControlsButtonView!
    @IBOutlet weak var recentPhotoPicker: RecentPhotoPicker!

    @IBOutlet weak var filtersContainer: UIView!
    @IBOutlet weak var filtersScrollView: UIScrollView!
    @IBOutlet weak var filtersLockIcon: UIImageView!
    @IBOutlet weak var filtersViewWidthConstraint: NSLayoutConstraint!

    @IBOutlet weak var layoutScrollView: HitTestScrollView!
    @IBOutlet weak var fontsScrollView: UIScrollView!
    @IBOutlet weak var graphsScrollView: UIScrollView!
    @IBOutlet weak var colorsScrollView: UIScrollView!
    @IBOutlet weak var fillsScrollView: UIScrollView!
    @IBOutlet weak var detailsScrollView: UIScrollView!

    // MARK: - Variables

    var statButtons: [EditorControlsButtonView] = []
    var graphButtons: [EditorControlsButtonView] = []
    var paletteButtons: [EditorControlsButtonView] = []
    var fontButtons: [EditorControlsButtonView] = []
    var layoutButtons: [EditorControlsButtonView] = []
    var filterButtons: [EditorControlsButtonView] = []
    var fillButtons: [EditorControlsButtonView] = []
    var alignmentPicker: VerticalPicker?

    weak var delegate: EditorControlsDelegate?
    let generator = UIImpactFeedbackGenerator(style: .medium)

    internal var subscribers: Set<AnyCancellable> = []

    // MARK: - Setup
    
    deinit {
        viewModel = nil
    }

    override func awakeFromNib() {
        layer.masksToBounds = false
        clipsToBounds = false
        view.layer.masksToBounds = false
        view.clipsToBounds = false
        mainScrollView.layer.masksToBounds = false
        filtersScrollView.layer.masksToBounds = false

        let insets = UIEdgeInsets(top: 0, left: 50, bottom: 0, right: 20)
        detailsScrollView.contentInset = insets
        mediaScrollView.contentInset = insets
        fontsScrollView.contentInset = insets
        filtersScrollView.contentInset = insets
        graphsScrollView.contentInset = insets
        colorsScrollView.contentInset = insets
        fillsScrollView.contentInset = insets
        layoutScrollView.contentInset = UIEdgeInsets(top: 0, left: 65, bottom: 0, right: 0)

        mainScrollView.contentInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        mainScrollView.isScrollEnabled = true

        mediaScrollView.isHidden = true
        filtersScrollView.isHidden = true
        layoutScrollView.isHidden = true
        fontsScrollView.isHidden = true
        detailsScrollView.isHidden = true
        graphsScrollView.isHidden = true
        fillsScrollView.isHidden = true

        filtersLockIcon.isHidden = true

        setupMainMenu()
        addGraphButtons()
        addFontButtons()
        addLayoutButtons()
        addFillButtons()
        addFilterButtons()
    }

    override func willMove(toSuperview newSuperview: UIView?) {
        super.willMove(toSuperview: newSuperview)

        if newSuperview == nil {
            fontButtons.removeAll()
            layoutButtons.removeAll()
        }
    }

    override func layoutSubviews() {
        loopBounceViewWidthConstraint.priority = loopBounceView.alpha > 0 ? .defaultLow : .required
        super.layoutSubviews()
    }
    
    // MARK: Binding
    
    private func bindViewModel() {
        subscribers.removeAll()
        viewModel.designPublishable.videoMode
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] videoMode in
                guard let self = self else { return }
                UIView.animate(withDuration: 0.2) {
                    switch videoMode {
                    case .bounce:
                        self.bounceView.button.alpha = 1.0
                        self.loopView.button.alpha = 0.3
                    case .loop:
                        self.bounceView.button.alpha = 0.3
                        self.loopView.button.alpha = 1.0
                    }
                }
            }
            .store(in: &subscribers)
        
        viewModel.designPublishable.font
            .receive(on: DispatchQueue.main)
            .sink { [weak self] font in
                guard let self = self else { return }
                self.selectFont(font)
            }
            .store(in: &subscribers)
        
        viewModel.designPublishable.cutoutShape
            .receive(on: DispatchQueue.main)
            .sink { [weak self] cutoutShape in
                guard let self = self else { return }
                self.selectLayoutShape(cutoutShape)
            }
            .store(in: &subscribers)
        
        viewModel.designPublishable.graphType
            .receive(on: DispatchQueue.main)
            .sink { [weak self] graphType in
                guard let self = self else { return }
                self.selectGraphType(graphType)
            }
            .store(in: &subscribers)

        viewModel.changedStatistics
            .receive(on: DispatchQueue.main)
            .sink { [weak self] design, _ in
                guard let self = self else { return }
                self.updateStatsButtons(for: design)
            }
            .store(in: &subscribers)
        
        viewModel.designPublishable.fill
            .receive(on: DispatchQueue.main)
            .sink { [weak self] fill in
                guard let self = self else { return }
                self.selectFill(withName: fill?.name ?? "No Fill")
            }
            .store(in: &subscribers)
        
        viewModel.designPublishable.photoFilter
            .receive(on: DispatchQueue.main)
            .sink { [weak self] photoFilter in
                guard let self = self else { return }

                self.selectFilter(photoFilter)
                if photoFilter == .none {
                    self.filtersScrollView.contentOffset.x = -1 * self.filtersScrollView.contentInset.left
                }
            }
            .store(in: &subscribers)
        
        viewModel.designPublishable.palette
            .receive(on: DispatchQueue.main)
            .sink { [weak self] palette in
                guard let self = self else { return }
                self.selectPalette(withName: palette.name)
            }
            .store(in: &subscribers)

        viewModel.palettes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] palettes in
                guard let self = self else { return }
                self.addColorButtons(withPalettes: palettes)
            }
            .store(in: &subscribers)
        
        viewModel.$availableGraphTypes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] availableGraphTypes in
                guard let self = self else { return }
                for graphType in self.viewModel.availableGraphTypes {
                    self.graphButton(forType: graphType)?.setLoading(false)
                    print("loaded \(graphType.displayName)")
                }
            }
            .store(in: &subscribers)

        viewModel.$unavailableGraphTypes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] availableGraphTypes in
                guard let self = self else { return }
                for graphType in self.viewModel.unavailableGraphTypes {
                    self.graphButton(forType: graphType)?.setLoading(false)
                    print("could not load \(graphType.displayName)")
                    self.graphButton(forType: graphType)?.enableInteraction(false)
                }
            }
            .store(in: &subscribers)
        
        viewModel.$availableStatisticTypes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] availableStatisticTypes in
                guard let self = self else { return }
                for statType in StatisticType.allCases {
                    let enabled = availableStatisticTypes.contains(statType)
                    if let statButton = self.statisticButtonView(forType: statType) {
                        statButton.enableInteraction(enabled)
                        let shows = self.viewModel.design.shows(statisticType: statType)
                        statButton.setSelected(shows, animated: true)
                    }
                }
            }
            .store(in: &subscribers)
        
    }
    
    func updateStatsButtons(for design: ActivityDesign) {
        for statButton in self.statButtons {
            if let stat = StatisticType(rawValue: statButton.id),
               design.shows(statisticType: stat) {
                statButton.setSelected(true, animated: true)
            } else {
                statButton.setSelected(false, animated: true)
            }
        }
    }
    
    // MARK: - Hit Test

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard isUserInteractionEnabled else { return nil }
        guard !isHidden else { return nil }
        guard alpha >= 0.01 else { return nil }

        for subview in view.subviews.reversed() {
            let convertedPoint = subview.convert(point, from: view)
            if let candidate = subview.hitTest(convertedPoint, with: event) {
                return candidate
            }
        }
        return nil
    }
}

extension EditorControls: RecentPhotoPickerDelegate {
    func recentPhotoPickerPickedPhoto(_ photo: UIImage) {
        generator.impactOccurred()
        viewModel.save(image: photo)
    }
}
