// Licensed under the Any Distance Source-Available License
//
//  EditorControls+Setup.swift
//  ADAC
//
//  Created by Daniel Kuntz on 11/25/21.
//

import UIKit

extension EditorControls {

    // MARK: - Main Menu

    func setupMainMenu() {
        mediaView.label.text = "Add Media"
        mediaView.button.setImage(UIImage(named: "glyph_media"), for: .normal)
        mediaView.tapHandler = { [weak self] in self?.mediaTapped($0) }

        mediaReplaceView.label.text = "Replace"
        mediaReplaceView.button.setImage(UIImage(named: "glyph_media_replace"), for: .normal)
        mediaReplaceView.tapHandler = { [weak self] in self?.mediaReplaceTapped($0) }

        mediaRemoveView.label.text = "Remove"
        mediaRemoveView.button.setImage(UIImage(named: "glyph_remove"), for: .normal)
        mediaRemoveView.tapHandler = { [weak self] in self?.mediaRemoveTapped($0) }

        filtersView.label.text = "Effects"
        filtersView.button.setImage(UIImage(named: "glyph_film_effects"), for: .normal)
        filtersView.tapHandler = { [weak self] in self?.photoFiltersTapped($0) }

        loopView.label.text = "Loop"
        loopView.button.setImage(UIImage(named: "glyph_loop"), for: .normal)
        loopView.tapHandler = { [weak self] in self?.mediaLoopTapped($0) }

        bounceView.label.text = "Bounce"
        bounceView.button.setImage(UIImage(named: "glyph_bounce"), for: .normal)
        bounceView.tapHandler = { [weak self] in self?.mediaBounceTapped($0) }

        layoutsView.label.text = "Layouts"
        layoutsView.button.setImage(UIImage(named: "glyph_layouts"), for: .normal)
        layoutsView.tapHandler = { [weak self] in self?.layoutsTapped($0) }

        graphsView.label.text = "Graphs"
        graphsView.button.setImage(UIImage(named: "glyph_graphs_route2d"), for: .normal)
        graphsView.tapHandler = { [weak self] in self?.graphsTapped($0) }

        colorsView.label.text = "Colors"
        colorsView.button.setImage(UIImage(named: "glyph_colors"), for: .normal)
        colorsView.button.imageEdgeInsets = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 0)
        colorsView.tapHandler = { [weak self] in self?.colorsTapped($0) }

        fillsView.label.text = "Fills"
        fillsView.button.setImage(UIImage(named: "glyph_fills"), for: .normal)
        fillsView.tapHandler = { [weak self] in self?.fillsTapped($0) }

        fontsView.label.text = "Fonts"
        fontsView.button.setImage(UIImage(named: "glyph_fonts"), for: .normal)
        fontsView.tapHandler = { [weak self] in self?.fontsTapped($0) }

        statsView.label.text = "Stats"
        statsView.button.setImage(UIImage(named: "glyph_display"), for: .normal)
        statsView.tapHandler = { [weak self] in self?.statsTapped($0) }
    }

    // MARK: - Recent Photo Picker

    func setupRecentPhotoPicker(for activity: Activity) {
        recentPhotoPicker.delegate = self

        let collectibles = ADUser.current.collectibles(for: activity)
        Task {
            let collectibleImages = await CollectibleShareImageGenerator.generateLayoutBackgroundImages(forCollectibles: collectibles)
            let startDate = activity.startDate
            let endDate = activity.endDate
            let midPoint = (startDate.timeIntervalSince1970 + endDate.timeIntervalSince1970) / 2
            let midDate = Date(timeIntervalSince1970: midPoint)

            RecentPhotoLoader.loadPhotos(forDate: midDate, maxCount: 3) { userPhotos in
                DispatchQueue.main.async {
                    self.recentPhotoPicker.addButtonsWithPhotos(collectibleImages + userPhotos)
                }
            }
        }
    }

    // MARK: - Palettes

    func addColorButtons(withPalettes palettes: [Palette]) {
        if paletteButtons.count == palettes.count {
            for (button, newPalette) in zip(paletteButtons, palettes) {
                if button.id == Palette.dark.name || button.id == Palette.light.name {
                    continue
                }

                button.setPalette(newPalette)
            }
            return
        }

        let selectedId = paletteButtons.first(where: { $0.isSelected })?.id
        colorsScrollView.subviews.forEach { view in
            view.removeFromSuperview()
        }
        paletteButtons.removeAll()

        for palette in palettes {
            let buttonView = EditorControlsButtonView(title: palette.name,
                                                      image: nil,
                                                      id: palette.name)
            buttonView.setPalette(palette)
            buttonView.tapHandler = { [weak self] in self?.paletteTapped($0) }
            paletteButtons.append(buttonView)
        }

        addButtonViews(paletteButtons, toScrollView: colorsScrollView)

        if let id = selectedId {
            selectPalette(withName: id)
        }
    }

    // MARK: - Fills

    func addFillButtons() {
        var buttonViews: [UIView] = []
        
        let noFillName = "No Fill"
        let buttonView = EditorControlsButtonView(title: noFillName,
                                                  image: nil,
                                                  id: noFillName)
        buttonView.tapHandler = { [weak self] in self?.fillTapped($0) }
        buttonView.setFill(nil)
        fillButtons.append(buttonView)
        buttonViews.append(buttonView)

        for collection in FillCollection.allCases {
            if !collection.name.isEmpty {
                buttonViews.append(VerticalLabel(text: collection.name))
            }
            
            for fill in collection.fills {
                let buttonView = EditorControlsButtonView(title: fill.name,
                                                          image: nil,
                                                          id: fill.name)
                buttonView.setFill(fill)
                buttonView.tapHandler = { [weak self] in self?.fillTapped($0) }
                fillButtons.append(buttonView)
                buttonViews.append(buttonView)
            }
        }

        addButtonViews(buttonViews, toScrollView: fillsScrollView)
    }

    // MARK: - Graphs

    func addGraphButtons() {
        for graphType in GraphType.visibleCases {
            let buttonView = EditorControlsButtonView(title: graphType.displayName,
                                                      image: graphType.image,
                                                      id: graphType.rawValue)
            buttonView.setSelected(false, animated: false)
            buttonView.setLoading(true)
            buttonView.tapHandler = { [weak self] in self?.graphTapped($0) }
            graphButtons.append(buttonView)
        }

        addButtonViews(graphButtons, toScrollView: graphsScrollView, spacing: 16)
    }

    // MARK: - Stats

    func addStatsButtons(for activity: Activity) {
        let statistics = StatisticType.possibleStats(for: activity)

        for stat in statistics {
            let buttonView = EditorControlsButtonView(title: stat.displayName,
                                                      image: stat.image,
                                                      id: stat.rawValue)
            buttonView.setSelected(false, animated: false)
            buttonView.enableInteraction(false)
            buttonView.tapHandler = { [weak self] in self?.statisticTapped($0) }
            statButtons.append(buttonView)
        }

        addButtonViews(statButtons, toScrollView: detailsScrollView)
    }

    // MARK: - Layouts

    func addLayoutButtons() {
        var buttonViews: [UIView] = []

        alignmentPicker = VerticalPicker(title: "Alignment",
                                         buttonImages: StatisticAlignment.allCases.map { $0.icon! })
        alignmentPicker?.tapHandler = { [weak self] idx -> Void in
            let alignment = StatisticAlignment(idx: idx)
            self?.viewModel.set(alignment: alignment)
        }
        buttonViews.append(alignmentPicker!)

        for layout in CutoutShape.allCases {
            let buttonView = EditorControlsButtonView(title: layout.displayName,
                                                      image: layout.editorControlsImage,
                                                      imageEdgeInsets: layout.editorControlsImageEdgeInsets,
                                                      id: layout.rawValue)
            buttonView.tapHandler = { [weak self] in self?.layoutButtonTapped($0) }
            layoutButtons.append(buttonView)
            buttonViews.append(buttonView)
        }

        addButtonViews(buttonViews, toScrollView: layoutScrollView, spacing: EditorControls.buttonSpacing + 8)
    }

    // MARK: - Fonts

    func addFontButtons() {
        for font in ADFont.allCases {
            let buttonView = EditorControlsButtonView(title: font.displayName,
                                                      image: font.editorControlsImage,
                                                      imageEdgeInsets: nil,
                                                      id: font.rawValue)
            buttonView.tapHandler = { [weak self] in self?.fontTapped($0) }
            fontButtons.append(buttonView)
        }

        addButtonViews(fontButtons, toScrollView: fontsScrollView)
    }

    // MARK: - Filters

    func addFilterButtons() {
        for filter in PhotoFilter.allCases {
            let buttonView = EditorControlsButtonView(title: filter.displayName,
                                                      image: nil,
                                                      imageEdgeInsets: .zero,
                                                      bottomRightImage: filter.icon,
                                                      id: filter.rawValue)
            buttonView.tapHandler = { [weak self] in self?.filterTapped($0) }
            filterButtons.append(buttonView)
        }

        addButtonViews(filterButtons, toScrollView: filtersScrollView, spacing: 22, pinLastToTrailingEdge: false)

        let poweredByHipstaView = PoweredByHipstaView(frame: .zero)
        filtersScrollView.addSubview(poweredByHipstaView)
        poweredByHipstaView.autoPinEdge(.leading, to: .trailing, of: filterButtons.last!, withOffset: 34)
        poweredByHipstaView.autoMatch(.height, to: .height, of: filtersScrollView)
        poweredByHipstaView.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .leading)
    }

    func addButtonViews(_ buttonViews: [UIView],
                        toScrollView scrollView: UIScrollView,
                        spacing: CGFloat = EditorControls.buttonSpacing,
                        pinLastToTrailingEdge: Bool = true) {
        var prevButtonView: UIView?
        for buttonView in buttonViews {
            scrollView.addSubview(buttonView)
            buttonView.autoPinEdge(toSuperviewEdge: .top)
            buttonView.autoPinEdge(toSuperviewEdge: .bottom)
            buttonView.autoMatch(.height, to: .height, of: scrollView)

            if buttonView is VerticalLabel {
                buttonView.autoSetDimension(.width, toSize: 20)
            } else {
                buttonView.autoSetDimension(.width, toSize: EditorControls.buttonWidth)
            }

            if let prev = prevButtonView {
                buttonView.autoPinEdge(.leading, to: .trailing, of: prev, withOffset: spacing)
            } else {
                buttonView.autoPinEdge(toSuperviewEdge: .leading)
            }

            prevButtonView = buttonView
        }

        if pinLastToTrailingEdge {
            prevButtonView?.autoPinEdge(toSuperviewEdge: .trailing)
        }
    }

    // MARK: - Picked Photo / Video

    func showFiltersMenu(for image: UIImage) {
        mediaView.label.text = "Media"

        if filtersViewWidthConstraint.priority != .defaultLow {
            filtersViewWidthConstraint.priority = .defaultLow

            let block = {
                self.loopBounceView.alpha = 0
                self.filtersContainer.alpha = 1
                self.layoutIfNeeded()
                self.layoutSubviews()
            }

            if superview != nil {
                UIView.animate(withDuration: 0.55,
                               delay: 0,
                               usingSpringWithDamping: 0.75,
                               initialSpringVelocity: 0.1,
                               options: [.allowAnimatedContent, .beginFromCurrentState, .allowUserInteraction, .curveEaseIn],
                               animations: block, completion: nil)
            } else {
                block()
            }
        }

        if !mediaScrollView.isHidden {
            hideSubmenu()
        }

        DispatchQueue.global(qos: .background).async {
            let resizedImage = image.resized(withNewWidth: 250)
            for buttonView in self.filterButtons {
                guard let filter = PhotoFilter(rawValue: buttonView.button.id) else {
                    continue
                }

                DispatchQueue.main.async {
                    buttonView.setPhotoFilter(filter, originalImage: resizedImage)
                }
            }
        }
    }

    func showVideoModesMenuForVideo() {
        mediaView.label.text = "Media"
        loopBounceView.alpha = 1.0
        filtersViewWidthConstraint.priority = .required
        filtersContainer.alpha = 0.0
        layoutSubviews()
        layoutIfNeeded()
    }
    
    func hideMenuForMedia() {
        mediaView.label.text = "Add Media"
        loopBounceView.alpha = 0.0
        filtersViewWidthConstraint.priority = .required
        filtersContainer.alpha = 0.0
        hideSubmenu()
        layoutSubviews()
    }

    // MARK: - Restore Cached Design
    
    func setup(activity: Activity) {
        setupRecentPhotoPicker(for: activity)
        addStatsButtons(for: activity)

        if activity.activityType == .stepCount {
            let activityTypeButton = statisticButtonView(forType: .activityType)?.button
            activityTypeButton?.setImage(DailyStepCount.glyph?
                .resized(withNewWidth: 45)
                .withRenderingMode(.alwaysTemplate), for: .normal)
            
            graphsViewWidthConstraint.constant = 0
            graphsViewTrailingConstraint.constant = 0
            graphsView.isHidden = true
        } else {
            if activity.activityType.shouldShowSpeedInsteadOfPace {
                let buttonView = statisticButtonView(forType: .pace)
                buttonView?.button.setImage(UIImage(named: "glyph_speed")?.withRenderingMode(.alwaysTemplate), for: .normal)
                buttonView?.label.text = "Speed"
            }
            
            if let source = activity.workoutSource {
                if let service = source.externalService {
                    delegate?.showConnect(for: service)
                }
                else if !source.hasRouteInfo {
                    graphsView.hasWarningIndicator = true
                    graphButton(forType: .route2d)?.hasWarningIndicator = true
                    graphButton(forType: .route3d)?.hasWarningIndicator = true
                    graphButton(forType: .elevation)?.hasWarningIndicator = true
                }
            }
            
            let activityTypeButton = statisticButtonView(forType: .activityType)?.button
            activityTypeButton?.setImage(activity.activityType.glyph?
                .resized(withNewWidth: 45)
                .withRenderingMode(.alwaysTemplate), for: .normal)
        }
    }

    // MARK: - Subscription State Change

    func observeSubscriptionStateChanges() {
        iAPManager.shared.$isSubscribed
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateSubscriptionState(iAPManager.shared.hasSuperDistanceFeatures)
            }
            .store(in: &subscribers)
    }

    private func updateSubscriptionState(_ isSubscribed: Bool) {
        for filterButton in self.filterButtons {
            if filterButton.filter != PhotoFilter.none {
                filterButton.isLocked = !isSubscribed
            } else {
                filterButton.isLocked = false
            }
        }

        for (shape, layoutButton) in zip(CutoutShape.allCases, self.layoutButtons) {
            if shape.requiresSuperDistance {
                layoutButton.isLocked = !isSubscribed
            }
        }

        for (graphType, graphButton) in zip(GraphType.visibleCases, self.graphButtons) {
            if graphType.requiresSuperDistance {
                graphButton.isLocked = !isSubscribed
            }
        }

        for paletteButton in self.paletteButtons {
            if paletteButton.palette?.name != "Dark" && paletteButton.palette?.name != "Light" {
                paletteButton.isLocked = !isSubscribed
            }
        }

        for fillButton in self.fillButtons {
            if fillButton.fill?.name != "No Fill" {
                fillButton.isLocked = !isSubscribed
            }
        }
    }

}
