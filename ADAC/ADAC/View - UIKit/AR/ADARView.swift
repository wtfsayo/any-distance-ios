// Licensed under the Any Distance Source-Available License
//
//  ADARView.swift
//  ADAC
//
//  Created by Daniel Kuntz on 12/12/22.
//

import ARKit

protocol ADARView: ARSCNView {
    func worldTrackingConfiguration() -> ARConfiguration
}
