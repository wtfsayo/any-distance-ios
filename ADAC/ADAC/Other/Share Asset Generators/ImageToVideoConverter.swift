// Licensed under the Any Distance Source-Available License
//
//  ImageToVideoConverter.swift
//  ADAC
//
//  Created by Daniel Kuntz on 10/9/21.
//

import AVFoundation
import UIKit

struct RenderSettings {
    var size : CGSize = .zero
    var fps: Int32 = 6   // frames per second
    var avCodecKey = AVVideoCodecType.hevc
    var videoFilename = "render"
    var videoFilenameExt = "mp4"

    var outputURL: URL {
        // Use the CachesDirectory so the rendered video file sticks around as long as we need it to.
        // Using the CachesDirectory ensures the file won't be included in a backup of the app.
        let fileManager = FileManager.default
        if let tmpDirURL = try? fileManager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true) {
            return tmpDirURL.appendingPathComponent(videoFilename).appendingPathExtension(videoFilenameExt)
        }
        fatalError("URLForDirectory() failed")
    }
}

final class ImageToVideoConverter {
    let renderSettings: RenderSettings

    var videoWriter: AVAssetWriter!
    var videoWriterInput: AVAssetWriterInput!
    var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor!

    var isReadyForData: Bool {
        return videoWriterInput?.isReadyForMoreMediaData ?? false
    }

    func pixelBufferFromImage(image: CGImage, pixelBufferPool: CVPixelBufferPool, size: CGSize) -> CVPixelBuffer {
        var pixelBufferOut: CVPixelBuffer?

        let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pixelBufferPool, &pixelBufferOut)
        if status != kCVReturnSuccess {
            fatalError("CVPixelBufferPoolCreatePixelBuffer() failed")
        }

        let pixelBuffer = pixelBufferOut!

        CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))

        let data = CVPixelBufferGetBaseAddress(pixelBuffer)
        let rgbColorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        let context = CGContext(data: data, width: Int(size.width), height: Int(size.height),
                                bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
                                space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)

        let imgWidth = CGFloat(image.width)
        let imgHeight = CGFloat(image.height)

        let horizontalRatio = size.width / imgWidth
        let verticalRatio = size.height / imgHeight
        //aspectRatio = max(horizontalRatio, verticalRatio) // ScaleAspectFill
        let aspectRatio = min(horizontalRatio, verticalRatio) // ScaleAspectFit

        let newSize = CGSize(width: imgWidth * aspectRatio, height: imgHeight * aspectRatio)

        let x = newSize.width < size.width ? (size.width - newSize.width) / 2 : 0
        let y = newSize.height < size.height ? (size.height - newSize.height) / 2 : 0

        context?.draw(image, in: CGRect(x: x, y: y, width: newSize.width, height: newSize.height))
        CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))

        return pixelBuffer
    }

    init(renderSettings: RenderSettings) {
        self.renderSettings = renderSettings
    }

    func start() {
        let avOutputSettings: [String: Any] = [
            AVVideoCodecKey: renderSettings.avCodecKey,
            AVVideoWidthKey: NSNumber(value: Float(renderSettings.size.width)),
            AVVideoHeightKey: NSNumber(value: Float(renderSettings.size.height))
        ]

        func createPixelBufferAdaptor() {
            let sourcePixelBufferAttributesDictionary = [
                kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_32ARGB),
                kCVPixelBufferWidthKey as String: NSNumber(value: Float(renderSettings.size.width)),
                kCVPixelBufferHeightKey as String: NSNumber(value: Float(renderSettings.size.height))
            ]
            pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoWriterInput,
                                                                      sourcePixelBufferAttributes: sourcePixelBufferAttributesDictionary)
        }

        func createAssetWriter(outputURL: URL) -> AVAssetWriter {
            guard let assetWriter = try? AVAssetWriter(outputURL: outputURL, fileType: AVFileType.mp4) else {
                fatalError("AVAssetWriter() failed")
            }

            guard assetWriter.canApply(outputSettings: avOutputSettings, forMediaType: AVMediaType.video) else {
                fatalError("canApplyOutputSettings() failed")
            }

            return assetWriter
        }

        if FileManager.default.isDeletableFile(atPath: renderSettings.outputURL.path) {
            do {
                try FileManager.default.removeItem(at: renderSettings.outputURL)
            } catch {
                print("Error removing render settings file: \(error.localizedDescription)")
            }
        }

        videoWriter = createAssetWriter(outputURL: renderSettings.outputURL)
        videoWriter.movieTimeScale = 30000

        videoWriterInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: avOutputSettings)
        videoWriterInput.mediaTimeScale = 30000

        if videoWriter.canAdd(videoWriterInput) {
            videoWriter.add(videoWriterInput)
        }
        else {
            fatalError("canAddInput() returned false")
        }

        // The pixel buffer adaptor must be created before we start writing.
        createPixelBufferAdaptor()

        if videoWriter.startWriting() == false {
            fatalError("startWriting() failed")
        }

        videoWriter.startSession(atSourceTime: CMTime.zero)

        precondition(pixelBufferAdaptor.pixelBufferPool != nil, "nil pixelBufferPool")
    }

    func addImage(image: CGImage, withPresentationTime presentationTime: CMTime) {
//        precondition(pixelBufferAdaptor.pixelBufferPool != nil, "Call start() to initialze the writer")

        guard let pool = pixelBufferAdaptor.pixelBufferPool else {
            return
        }

        let pixelBuffer = self.pixelBufferFromImage(image: image,
                                                    pixelBufferPool: pool,
                                                    size: self.renderSettings.size)

        while !self.pixelBufferAdaptor.assetWriterInput.isReadyForMoreMediaData {
            print("not ready")
            Thread.sleep(forTimeInterval: 0.01)
        }

        self.pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: presentationTime)
    }

    func finishRendering(completion: @escaping (() -> Void)) {
        print("finish")
        precondition(videoWriter != nil, "Call start() to initialze the writer")

        let queue = DispatchQueue.global(qos: .userInitiated)
        videoWriterInput.requestMediaDataWhenReady(on: queue) {
            self.videoWriterInput.markAsFinished()
            self.videoWriter.finishWriting() {
                DispatchQueue.main.async {
                    completion()
                }
            }
        }
    }
}
