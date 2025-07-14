//
//  VideoWriter.swift
//  videoeditorApp
//
//  Created by macbook on 13/07/25.
//


import UIKit
import AVFoundation
import Photos

class VideoWriter {
    let size: CGSize
    private var images: [(UIImage, CMTime)] = []

    init(size: CGSize) {
        self.size = size
    }

    func addImage(_ image: UIImage, duration: CMTime) {
        images.append((image, duration))
    }
 
    func export() -> URL? {
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("photoVideo-\(UUID().uuidString).mp4")

        guard let writer = try? AVAssetWriter(outputURL: outputURL, fileType: .mp4) else { return nil }

        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: size.width,
            AVVideoHeightKey: size.height
        ]

        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: nil)

        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        var currentTime = CMTime.zero

        for (image, duration) in images {
            if let buffer = pixelBuffer(from: image) {
                while !input.isReadyForMoreMediaData { usleep(10_000) }

                adaptor.append(buffer, withPresentationTime: currentTime)
                currentTime = currentTime + duration
            }
        }

        input.markAsFinished()
        writer.finishWriting {
            print("Photo video exported: \(outputURL)")
        }

        return outputURL
    }

    private func pixelBuffer(from image: UIImage) -> CVPixelBuffer? {
        let attrs: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ]

        var buffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                         Int(size.width),
                                         Int(size.height),
                                         kCVPixelFormatType_32ARGB,
                                         attrs as CFDictionary,
                                         &buffer)

        guard status == kCVReturnSuccess, let pixelBuffer = buffer else { return nil }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        let context = CGContext(data: CVPixelBufferGetBaseAddress(pixelBuffer),
                                width: Int(size.width),
                                height: Int(size.height),
                                bitsPerComponent: 8,
                                bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)

        if let cgImage = image.cgImage {
            context?.draw(cgImage, in: CGRect(origin: .zero, size: size))
        }

        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
        return pixelBuffer
    }
}
