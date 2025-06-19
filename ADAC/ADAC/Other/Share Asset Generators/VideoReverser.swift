// Licensed under the Any Distance Source-Available License
//
//  VideoReverser.swift
//  ADAC
//
//  Created by Daniel Kuntz on 3/18/21.
//

import UIKit
import AVFoundation

final class VideoReverser {
    static func makeBounceVideo(_ original: AVAsset, outputURL: URL, completion: @escaping (AVAsset?) -> Void) {
        // Initialize the reader
        var reader: AVAssetReader! = nil
        do {
            reader = try AVAssetReader(asset: original)
        } catch {
            print("could not initialize reader - \(error.localizedDescription)")
            completion(nil)
            return
        }

        guard let videoTrack = original.tracks(withMediaType: AVMediaType.video).last else {
            print("could not retrieve the video track.")
            completion(nil)
            return
        }

        let readerOutputSettings: [String: Any] = [kCVPixelBufferPixelFormatTypeKey as String : Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
        let readerOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: readerOutputSettings)
        reader.add(readerOutput)

        reader.startReading()

        // read in samples
        var samples: [CMSampleBuffer] = []
        while let sample = readerOutput.copyNextSampleBuffer() {
            samples.append(sample)
        }

        // Initialize the writer
        FileManager.default.removeItemIfExists(atUrl: outputURL)

        let writer: AVAssetWriter
        do {
            writer = try AVAssetWriter(outputURL: outputURL, fileType: AVFileType.mov)
        } catch let error {
            fatalError(error.localizedDescription)
        }
        
        guard (videoTrack.naturalSize.width > 0.0 &&
               videoTrack.naturalSize.height > 0.0) else {
            print("video track has a size <= zero.")
            completion(nil)
            return
        }

        let videoCompositionProps = [AVVideoAverageBitRateKey: videoTrack.estimatedDataRate]
        let writerOutputSettings = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: videoTrack.naturalSize.width,
            AVVideoHeightKey: videoTrack.naturalSize.height,
            AVVideoCompressionPropertiesKey: videoCompositionProps
        ] as [String : Any]

        let writerInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: writerOutputSettings)
        writerInput.expectsMediaDataInRealTime = false
        writerInput.transform = videoTrack.preferredTransform

        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: writerInput, sourcePixelBufferAttributes: nil)

        writer.add(writerInput)
        writer.startWriting()
        writer.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(samples.first!))

        var frame: Int64 = 0

        for sample in samples {
            let presentationTime = CMTimeMake(value: frame, timescale: Int32(videoTrack.nominalFrameRate))
            let imageBufferRef = CMSampleBufferGetImageBuffer(sample)
            while !writerInput.isReadyForMoreMediaData {
                Thread.sleep(forTimeInterval: 0.1)
            }
            pixelBufferAdaptor.append(imageBufferRef!, withPresentationTime: presentationTime)
            frame += 1
        }

        for (index, _) in samples.enumerated() {
            let presentationTime = CMTimeMake(value: frame, timescale: Int32(videoTrack.nominalFrameRate))
            let imageBufferRef = CMSampleBufferGetImageBuffer(samples[samples.count - 1 - index])
            while !writerInput.isReadyForMoreMediaData {
                Thread.sleep(forTimeInterval: 0.1)
            }
            pixelBufferAdaptor.append(imageBufferRef!, withPresentationTime: presentationTime)
            frame += 1
        }

        writer.finishWriting {
            completion(AVAsset(url: outputURL))
        }
    }

    static func reverse(_ original: AVAsset, outputURL: URL, completion: @escaping (AVAsset) -> Void) {
        // Initialize the reader
        var reader: AVAssetReader! = nil
        do {
            reader = try AVAssetReader(asset: original)
        } catch {
            print("could not initialize reader.")
            return
        }

        guard let videoTrack = original.tracks(withMediaType: AVMediaType.video).last else {
            print("could not retrieve the video track.")
            return
        }

        let readerOutputSettings: [String: Any] = [kCVPixelBufferPixelFormatTypeKey as String : Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
        let readerOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: readerOutputSettings)
        reader.add(readerOutput)

        reader.startReading()

        // read in samples
        var samples: [CMSampleBuffer] = []
        while let sample = readerOutput.copyNextSampleBuffer() {
            samples.append(sample)
        }

        // Initialize the writer
        FileManager.default.removeItemIfExists(atUrl: outputURL)

        let writer: AVAssetWriter
        do {
            writer = try AVAssetWriter(outputURL: outputURL, fileType: AVFileType.mov)
        } catch let error {
            fatalError(error.localizedDescription)
        }

        let videoCompositionProps = [AVVideoAverageBitRateKey: videoTrack.estimatedDataRate]
        let writerOutputSettings = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: videoTrack.naturalSize.width,
            AVVideoHeightKey: videoTrack.naturalSize.height,
            AVVideoCompressionPropertiesKey: videoCompositionProps
        ] as [String : Any]

        let writerInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: writerOutputSettings)
        writerInput.expectsMediaDataInRealTime = false
        writerInput.transform = videoTrack.preferredTransform

        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: writerInput, sourcePixelBufferAttributes: nil)

        writer.add(writerInput)
        writer.startWriting()
        writer.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(samples.first!))

        for (index, sample) in samples.enumerated() {
            let presentationTime = CMSampleBufferGetPresentationTimeStamp(sample)
            let imageBufferRef = CMSampleBufferGetImageBuffer(samples[samples.count - 1 - index])
            while !writerInput.isReadyForMoreMediaData {
                Thread.sleep(forTimeInterval: 0.1)
            }
            pixelBufferAdaptor.append(imageBufferRef!, withPresentationTime: presentationTime)

        }

        writer.finishWriting {
            completion(AVAsset(url: outputURL))
        }
    }
}

