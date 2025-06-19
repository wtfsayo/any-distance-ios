// Licensed under the Any Distance Source-Available License
//
//  SceneLoader.swift
//  ADAC
//
//  Created by Daniel Kuntz on 12/12/22.
//

import Foundation
import ARKit
import SceneKit

class SceneLoader {
    static func loadScene(atUrl url: URL) async -> SCNScene? {
        return await withCheckedContinuation { continuation in
            Task(priority: .medium) {
                do {
                    if url.pathExtension == "usdz" {
                        let mdlAsset = MDLAsset(url: url)
                        mdlAsset.loadTextures()
                        let scene = SCNScene(mdlAsset: mdlAsset)
                        continuation.resume(returning: scene)
                    } else {
                        let scene = try SCNScene(url: url, options: nil)
                        continuation.resume(returning: scene)
                    }
                } catch {
                    print("Error initializing Scene: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
