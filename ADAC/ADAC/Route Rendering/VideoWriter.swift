// Licensed under the Any Distance Source-Available License
//
//  VideoWriter.swift
//  ADAC
//
//  Created by Jarod Luebbert on 6/6/22.
//

import Foundation
import AVFoundation
import UIKit
import VideoToolbox

class VideoWriter {
    
    private var videoInput: AVAssetWriterInput
    private var pixelAdapter: AVAssetWriterInputPixelBufferAdaptor
    private var videoWriter: AVAssetWriter
    private let videoURL: URL
    private let pixelFormat: OSType = kCVPixelFormatType_32BGRA
    
    // MARK: Init
    
    init(videoName: String, with videoSize: CGSize ) throws {
        videoURL = FileManager.default.temporaryDirectory.appendingPathComponent(videoName)
        Self.removeVideo(from: videoURL)
        
        let videoInput = Self.videoWriterInput(with: videoSize)
        self.videoInput = videoInput
        pixelAdapter = Self.pixelBufferAdapter(for: videoInput,
                                               pixelFormat: pixelFormat,
                                               videoSize: videoSize)
        videoWriter = try Self.assetWriter(with: [videoInput], outputURL: videoURL)
    }
    
    deinit {
        if videoWriter.status == .writing {
            videoInput.markAsFinished()
            videoWriter.finishWriting {
                Self.removeVideo(from: self.videoURL)
            }
        }
    }
    
    // MARK: Public
    
    func startSession(at sourceTime: CMTime) {
        if sourceTime == CMTime.invalid {
            fatalError("startSession failed to initiate video writing at invalid time: \(sourceTime)")
        }
        videoWriter.startWriting()
        videoWriter.startSession(atSourceTime: sourceTime)
    }
    
    func endSession() async -> URL {
        while !videoInput.isReadyForMoreMediaData {
            Thread.sleep(forTimeInterval: 0.01)
        }
        videoInput.markAsFinished()
        await videoWriter.finishWriting()
        return videoURL
    }
    
    func append(buffer: CVPixelBuffer, at displayTime: CMTime) {
        while !pixelAdapter.assetWriterInput.isReadyForMoreMediaData {
            Thread.sleep(forTimeInterval: 0.01)
        }
        
        if pixelAdapter.assetWriterInput.isReadyForMoreMediaData {
            if !pixelAdapter.append(buffer, withPresentationTime: displayTime) {
                // log error
            }
        }
    }
    
}

// MARK: Init Helpers

fileprivate extension VideoWriter {
    
    static func removeVideo(from url: URL) {
        let path = url.path
        if FileManager.default.fileExists(atPath: path) {
            do {
                try FileManager.default.removeItem(atPath: path)
                print("file removed")
            } catch let error as NSError {
                print("error removing file",error.debugDescription)
            }
        }
    }
    
    static func pixelBufferAdapter(for input: AVAssetWriterInput,
                                   pixelFormat: OSType,
                                   videoSize: CGSize) -> AVAssetWriterInputPixelBufferAdaptor {
        let bufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: pixelFormat,
            kCVPixelBufferWidthKey as String: videoSize.width,
            kCVPixelBufferHeightKey as String: videoSize.height,
        ]
        let pixelAdapter = AVAssetWriterInputPixelBufferAdaptor.init(assetWriterInput: input,
                                                                     sourcePixelBufferAttributes: bufferAttributes)
        return pixelAdapter
    }
    
    static func videoWriterInput(with videoSize: CGSize) -> AVAssetWriterInput {
        let videoSettings: [String : Any] = [ AVVideoCodecKey: AVVideoCodecType.h264,
                                              AVVideoWidthKey: videoSize.width,
                                             AVVideoHeightKey: videoSize.height,
                                       AVVideoScalingModeKey : AVVideoScalingModeResizeAspectFill,
                                    AVVideoColorPropertiesKey: [
                                        AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                                        AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
                                        AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                                    ],
                              AVVideoCompressionPropertiesKey:
                                                [
                                                    AVVideoAverageBitRateKey : 10 * 1024 * 1024,
                                                    AVVideoExpectedSourceFrameRateKey : NSNumber.init(value: 30.0),
//                                                    kVTCompressionPropertyKey_TargetQualityForAlpha: 1.0
                                                ]]
        let videoInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: videoSettings)
        videoInput.mediaTimeScale = 30000
        videoInput.expectsMediaDataInRealTime = true
        return videoInput
    }
    
//    static func audioWriterInput() -> AVAssetWriterInput {
//        var acl: AudioChannelLayout = AudioChannelLayout()
//        bzero(&acl, MemoryLayout.size(ofValue: acl))
//        acl.mChannelLayoutTag = kAudioChannelLayoutTag_Mono
//
//        let audioSettings: [String: Any] = [AVFormatIDKey: Int(kAudioFormatAppleLossless),
//                                 AVEncoderBitDepthHintKey: Int(16),
//                                          AVSampleRateKey: Float(44100.0),
//                                    AVNumberOfChannelsKey: 1,
//                                       AVChannelLayoutKey: NSData(bytes: &acl, length: MemoryLayout.size(ofValue: acl))]
//        let audioInput = AVAssetWriterInput(mediaType: AVMediaType.audio, outputSettings: audioSettings)
//        audioInput.expectsMediaDataInRealTime = true
//        return audioInput
//    }
    
    static func assetWriter(with inputs: [AVAssetWriterInput], outputURL: URL) throws -> AVAssetWriter {
        let videoWriter = try AVAssetWriter(outputURL: outputURL, fileType: AVFileType.mp4)
        videoWriter.movieTimeScale = 30000
        for input in inputs {
            if videoWriter.canAdd(input) {
                videoWriter.add(input)
            }
        }
        return videoWriter
    }
    
}
