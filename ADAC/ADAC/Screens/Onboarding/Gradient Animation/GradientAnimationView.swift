// Licensed under the Any Distance Source-Available License
//
//  GradientAnimationView.swift
//  ADAC
//
//  Created by Daniel Kuntz on 1/4/23.
//

import UIKit
import MetalKit
import SwiftUI
import Combine
import PureLayout

/// UIViewRepresentable wrapper for GradientAnimationMTKView
struct GradientAnimationView: UIViewRepresentable {
    var pageIdx: Int

    func makeUIView(context: Context) -> UIView {
        let container = UIView()

        let metalView = GradientAnimationMTKView()
        metalView.page = pageIdx
        container.addSubview(metalView)
        metalView.autoPinEdgesToSuperviewEdges()

        context.coordinator.container = container
        return container
    }

    private func updatePage(context: Context) {
        guard let oldMetalView = context.coordinator.container?.subviews.first as? GradientAnimationMTKView,
              oldMetalView.page != pageIdx else {
            return
        }

        let newMetalView = GradientAnimationMTKView()
        newMetalView.page = pageIdx
        newMetalView.alpha = 0.0
        context.coordinator.container?.addSubview(newMetalView)
        newMetalView.autoPinEdgesToSuperviewEdges()

        UIView.animate(withDuration: 0.5) {
            oldMetalView.alpha = 0.0
            newMetalView.alpha = 1.0
        } completion: { finished in
            guard finished else {
                return
            }

            oldMetalView.removeFromSuperview()
        }
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        updatePage(context: context)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject {
        var subscribers: Set<AnyCancellable> = []
        var container: UIView?
    }
}

struct GradientAnimationView_Previews: PreviewProvider {
    static var previews: some View {
        GradientAnimationView(pageIdx: 0)
            .ignoresSafeArea()
    }
}

/// UIView wrapper for an MTKView that shows a gradient animation. Set "page" to change the colors of the
/// gradient animation.
class GradientAnimationMTKView: UIView {
    private var mtkView: MTKView?
    private let device = MTLCreateSystemDefaultDevice()
    private var pipelineState: MTLRenderPipelineState!
    private var commandQueue: MTLCommandQueue!
    private var vertexBuffer: MTLBuffer?

    private var time: Float = 0.0
    var page: Int = 0

    private struct Vertex {
        var position: simd_float2
    }

    private lazy var viewSize: [Float] = {
        return [Float(UIScreen.main.bounds.width * UIScreen.main.scale),
                Float(UIScreen.main.bounds.height * UIScreen.main.scale)]
    }()

    override func willMove(toSuperview newSuperview: UIView?) {
        guard let device = device else {
            return
        }

        let library = device.makeDefaultLibrary()!
        let vertexFunction = library.makeFunction(name: "gradient_animation_vertex")
        let fragmentFunction = library.makeFunction(name: "gradient_animation_fragment")
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        let mdlVertexDescriptor = MDLVertexDescriptor()
        mdlVertexDescriptor.attributes[0] = MDLVertexAttribute(name: "position", format: MDLVertexFormat.float2, offset: 0, bufferIndex: 0)
        mdlVertexDescriptor.attributes[1] = MDLVertexAttribute(name: "time", format: MDLVertexFormat.float, offset: 8, bufferIndex: 0)
        mdlVertexDescriptor.attributes[2] = MDLVertexAttribute(name: "page", format: MDLVertexFormat.int, offset: 12, bufferIndex: 0)
        mdlVertexDescriptor.layouts[0] = MDLVertexBufferLayout(stride: 16)
        pipelineDescriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(mdlVertexDescriptor)!

        pipelineState = try! device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        commandQueue = device.makeCommandQueue()

        let vertexData: [Float] = [1, 1, 0,
                                   -1, -1, 0,
                                   -1, 1, 0,
                                   1, 1, 0,
                                   -1, -1, 0,
                                   1, -1, 0]
        let dataSize = vertexData.count * MemoryLayout<Float>.size
        vertexBuffer = device.makeBuffer(bytes: vertexData,
                                              length: dataSize,
                                              options: [])

        mtkView = MTKView(frame: CGRect(origin: .zero, size: UIScreen.main.bounds.size),
                          device: device)
        addSubview(mtkView!)
        mtkView?.autoPinEdgesToSuperviewEdges()
        mtkView?.delegate = self
    }
}

extension GradientAnimationMTKView: MTKViewDelegate {
    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer()
        else { return }

        guard UIApplication.shared.topViewController is UITabBarController ||
              UIApplication.shared.topViewController is OnboardingViewController else {
            return
        }

        descriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0.5, blue: 0.5, alpha: 1.0)
        descriptor.colorAttachments[0].texture = drawable.texture
        descriptor.colorAttachments[0].loadAction = .clear
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)!

        time += 1.5 / Float(UIScreen.main.maximumFramesPerSecond)
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBytes(&time, length: MemoryLayout<Float>.stride, index: 1)
        renderEncoder.setVertexBytes(&viewSize, length: MemoryLayout<Float>.stride * viewSize.count, index: 2)
        renderEncoder.setVertexBytes(&page, length: MemoryLayout<Int>.stride, index: 3)
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6, instanceCount: 1)
        renderEncoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        //
    }
}
