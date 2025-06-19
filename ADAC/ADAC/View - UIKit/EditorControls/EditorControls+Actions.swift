// Licensed under the Any Distance Source-Available License
//
//  EditorControls+Actions.swift
//  ADAC
//
//  Created by Daniel Kuntz on 11/25/21.
//

import UIKit

extension EditorControls {
    
    // MARK: - Main Menu Actions

    func mediaTapped(_ sender: Any) {
        if mediaView.label.text == "Add Media" {
            viewModel.mediaReplaceTapped()
            return
        }

        hideAllSubmenus()
        mediaScrollView.isHidden = false
        showSubmenu()
    }

    func layoutsTapped(_ sender: Any) {
        hideAllSubmenus()
        scrollToSelectedButton(inScrollView: layoutScrollView)
        layoutScrollView.isHidden = false
        showSubmenu()
    }

    func photoFiltersTapped(_ sender: Any) {
        hideAllSubmenus()
        scrollToSelectedButton(inScrollView: filtersScrollView)
        filtersScrollView.isHidden = false
        filtersScrollView.layer.masksToBounds = false
        showSubmenu()
    }

    func graphsTapped(_ sender: Any) {
        hideAllSubmenus()
        scrollToSelectedButton(inScrollView: graphsScrollView)
        graphsScrollView.isHidden = false
        showSubmenu()
    }

    func colorsTapped(_ sender: Any) {
        hideAllSubmenus()
        scrollToSelectedButton(inScrollView: colorsScrollView)
        colorsScrollView.isHidden = false
        showSubmenu()
    }

    func fillsTapped(_ sender: Any) {
        hideAllSubmenus()
        scrollToSelectedButton(inScrollView: fillsScrollView)
        fillsScrollView.isHidden = false
        showSubmenu()
    }

    func fontsTapped(_ sender: Any) {
        hideAllSubmenus()
        scrollToSelectedButton(inScrollView: fontsScrollView)
        fontsScrollView.isHidden = false
        showSubmenu()
    }

    func statsTapped(_ sender: Any) {
        hideAllSubmenus()
        detailsScrollView.isHidden = false
        showSubmenu()
    }

    func scrollToSelectedButton(inScrollView scrollView: UIScrollView) {
        if let selectedButton = scrollView.subviews.first(where: { ($0 as? EditorControlsButtonView)?.isSelected ?? false }) {
            let minContentOffset = -1 * scrollView.contentInset.left
            let maxContentOffset = (scrollView.contentSize.width - bounds.width)
                .clamped(to: minContentOffset...CGFloat.greatestFiniteMagnitude)
            scrollView.contentOffset.x = (selectedButton.frame.midX - (bounds.width / 2))
                .clamped(to: minContentOffset...maxContentOffset)
        }
    }

    func showSubmenu() {
        mainScrollViewLeadingConstraint.constant = -1 * view.bounds.width
        UIView.animate(withDuration: 0.55,
                       delay: 0,
                       usingSpringWithDamping: 0.8,
                       initialSpringVelocity: 0.1,
                       options: [.allowUserInteraction, .beginFromCurrentState, .curveEaseInOut],
                       animations: {
            self.view.layoutIfNeeded()
            self.mainScrollView.alpha = 0
        },
                       completion: nil)
    }

    func hideSubmenu() {
        mainScrollViewLeadingConstraint.constant = 0
        filtersScrollView.layer.masksToBounds = true

        UIView.animate(withDuration: 0.55,
                       delay: 0,
                       usingSpringWithDamping: 0.8,
                       initialSpringVelocity: 0.1,
                       options: [.allowUserInteraction, .beginFromCurrentState, .curveEaseInOut],
                       animations: {
            self.view.layoutIfNeeded()
            self.mainScrollView.alpha = 1
        },
                       completion: { _ in
            self.hideAllSubmenus()
        })
    }

    private func hideAllSubmenus() {
        self.mediaScrollView.isHidden = true
        self.filtersScrollView.isHidden = true
        self.layoutScrollView.isHidden = true
        self.fontsScrollView.isHidden = true
        self.detailsScrollView.isHidden = true
        self.graphsScrollView.isHidden = true
        self.colorsScrollView.isHidden = true
        self.fillsScrollView.isHidden = true
    }

    // MARK: - Submenus

    @IBAction func submenuBackTapped(_ sender: Any) {
        alignmentPicker?.contract()
        hideSubmenu()
    }

    // MARK: - Media Submenu

    func mediaLoopTapped(_ sender: Any) {
        viewModel.set(videoMode: .loop)
        generator.impactOccurred()
    }

    func mediaBounceTapped(_ sender: Any) {
        viewModel.set(videoMode: .bounce)
        generator.impactOccurred()
    }

    func mediaReplaceTapped(_ sender: Any) {
        viewModel.mediaReplaceTapped()
        generator.impactOccurred()
    }

    func mediaRemoveTapped(_ sender: Any) {
        viewModel.mediaRemoveTapped()
        generator.impactOccurred()
    }

    // MARK: - Submenu Selection

    func selectButton(_ buttonToSelect: EditorControlsButtonView,
                      inArray arr: [EditorControlsButtonView],
                      animated: Bool = true) {
        for view in arr {
            if view === buttonToSelect {
                view.setSelected(true, animated: animated)
            } else {
                view.setSelected(false, animated: animated)
            }
        }
    }

    // MARK: - Layouts Submenu

    func layoutButtonTapped(_ sender: EditorControlsButtonView) {
        if let shape = CutoutShape(rawValue: sender.button.id) {
            viewModel.set(cutoutShape: shape)
        }

        generator.impactOccurred()
    }

    func selectLayoutShape(_ shape: CutoutShape, animated: Bool = true) {
        if let button = layoutButtons.first(where: { $0.id == shape.rawValue }) {
            selectButton(button, inArray: layoutButtons, animated: animated)
        }
    }
    
    func selectAlignment(_ alignment: StatisticAlignment) {
        alignmentPicker?.selectIdx(alignment.idx)
    }

    // MARK: - Graph Submenu

    func graphTapped(_ sender: EditorControlsButtonView) {
        if let graphType = GraphType(rawValue: sender.button.id) {
            delegate?.didSelectGraphType(graphType: graphType)
            viewModel.set(graphType: graphType)
        }

        generator.impactOccurred()
    }

    func selectGraphType(_ type: GraphType, animated: Bool = true) {
        if let button = graphButton(forType: type) {
            selectButton(button, inArray: graphButtons, animated: animated)
        }

        graphsView.button.setImage(type.image, for: .normal)
    }

    func graphButton(forType type: GraphType) -> EditorControlsButtonView? {
        return graphButtons.first(where: { $0.id == type.rawValue })
    }

    // MARK: - Colors Submenu

    func paletteTapped(_ sender: EditorControlsButtonView) {
        if let palette = sender.palette {
            viewModel.set(palette: palette)
        }

        generator.impactOccurred()
    }

    func selectPalette(withName name: String, animated: Bool = true) {
        if let button = paletteButtons.first(where: { $0.id == name }) {
            selectButton(button, inArray: paletteButtons, animated: animated)
        }
    }

    // MARK: - Fills Submenu

    func fillTapped(_ sender: EditorControlsButtonView) {
        generator.impactOccurred()

        viewModel.set(fill: sender.fill)
    }

    func selectFill(withName name: String, animated: Bool = true) {
        if let button = fillButtons.first(where: { $0.id == name }) {
            selectButton(button, inArray: fillButtons, animated: animated)
        }
    }

    // MARK: - Font Submenu

    func fontTapped(_ sender: EditorControlsButtonView) {
        if let font = ADFont(rawValue: sender.button.id) {
            viewModel.set(font: font)
        }

        generator.impactOccurred()
    }

    func selectFont(_ font: ADFont, animated: Bool = true) {
        if let button = fontButtons.first(where: { $0.id == font.rawValue }) {
            selectButton(button, inArray: fontButtons, animated: animated)
        }
    }

    // MARK: - Filters Submenu

    func filterTapped(_ sender: EditorControlsButtonView) {
        if let photoFilter = PhotoFilter(rawValue: sender.button.id) {
            viewModel.set(photoFilter: photoFilter)
        }

        generator.impactOccurred()
    }

    func selectFilter(_ filter: PhotoFilter, animated: Bool = true) {
        if let buttonView = filterButtons.first(where: { $0.button.id == filter.rawValue }) {
            selectButton(buttonView, inArray: filterButtons, animated: animated)
        }
    }

    // MARK: - Stats Submenu

    func statisticTapped(_ sender: EditorControlsButtonView) {
        guard let statistic = StatisticType(rawValue: sender.id) else {
            return
        }
        
        viewModel.toggle(statistic: statistic)
        delegate?.detailsStatisticTapped(statistic)
        generator.impactOccurred()
    }

    func statisticButtonView(forType type: StatisticType) -> EditorControlsButtonView? {
        return statButtons.first(where: { $0.id == type.rawValue })
    }

    func toggleDetailButton(_ buttonToToggle: EditorControlsButtonView?, on: Bool? = nil, animated: Bool = true) {
        guard let buttonToToggle = buttonToToggle else {
            return
        }

        buttonToToggle.setSelected(on ?? !buttonToToggle.isSelected, animated: animated)
    }
}
