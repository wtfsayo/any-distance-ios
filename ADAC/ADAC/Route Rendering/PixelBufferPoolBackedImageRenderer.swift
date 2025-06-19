// Licensed under the Any Distance Source-Available License
//
//  PixelBufferPoolBackedImageRenderer.swift
//  SceneKitOffscreen
//
//  Created by Jarod Luebbert on 6/7/22.
//  Copyright © 2022 Any Distance. All rights reserved.
//

import Foundation
import MetalPetal
import VideoToolbox

class PixelBufferPoolBackedImageRenderer {
    
    private var pixelBufferPool: MTICVPixelBufferPool?
    private let renderSemaphore: DispatchSemaphore

    init(renderTaskQueueCapacity: Int = 5) {
        self.renderSemaphore = DispatchSemaphore(value: renderTaskQueueCapacity)
    }
    
    func render(_ image: MTIImage, using context: MTIContext, sRGB: Bool) throws -> CVPixelBuffer {
        let pixelBufferPool: MTICVPixelBufferPool
        if let pool = self.pixelBufferPool,
           pool.pixelBufferWidth == image.dimensions.width,
           pool.pixelBufferHeight == image.dimensions.height {
            pixelBufferPool = pool
        } else {
            pixelBufferPool = try MTICVPixelBufferPool(pixelBufferWidth: Int(image.dimensions.width),
                                                       pixelBufferHeight: Int(image.dimensions.height),
                                                       pixelFormatType: kCVPixelFormatType_32BGRA,
                                                       minimumBufferCount: 30)
            self.pixelBufferPool = pixelBufferPool
        }
        let pixelBuffer = try pixelBufferPool.makePixelBuffer(allocationThreshold: 20)
        
        self.renderSemaphore.wait()
        do {
            try context.startTask(toRender: image,
                                  to: pixelBuffer,
                                  sRGB: sRGB,
//                                  destinationAlphaType: .nonPremultiplied,
                                  completion: { task in
                self.renderSemaphore.signal()
            })
        } catch {
            self.renderSemaphore.signal()
            throw error
        }
        
        return pixelBuffer
    }
    
    func finish() {
        pixelBufferPool = nil
    }
    
}
