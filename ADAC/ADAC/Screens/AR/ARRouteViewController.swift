// Licensed under the Any Distance Source-Available License
//
//  ARRouteViewController.swift
//  ADAC
//
//  Created by Daniel Kuntz on 2/17/22.
//

import SwiftUI
import ARKit
import UIKit

final class ARRouteViewController: ARViewController<RouteARView> {
    private var _showsRouteControls: Bool = true
    override var showsRouteControls: Bool {
        return _showsRouteControls
    }

    private var _showsRecordingControls: Bool = true
    override var showsRecordingControls: Bool {
        return _showsRecordingControls
    }

    init(_ coordinates: [CLLocation],
         canvas: LayoutCanvas?,
         palette: Palette,
         showRecordingControls: Bool = true,
         showRouteControls: Bool = true) {
        let routeARView = RouteARView()
        routeARView.renderLine(withCoordinates: coordinates, canvas: canvas, palette: palette)
        self._showsRecordingControls = showRecordingControls
        self._showsRouteControls = showRouteControls
        super.init(routeARView)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func startRecordingAction() {
        arView?.routeRenderer.restartAnimation()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            super.startRecordingAction()
        }
    }

    override func routeTypeSwitched(_ routeType: ARRouteType) {
        arView?.setRouteType(routeType)
    }
}
