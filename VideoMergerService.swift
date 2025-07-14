import Foundation
import Photos
import AVFoundation
import UIKit
import Combine

class VideoMergerService: ObservableObject {
    @Published var mergedAsset: AVAsset?
    
    func mergeMediaItems(videos: [VideoItem], photos: [PhotoItem], completion: @escaping (Result<AVAsset, Error>) -> Void) {
        print("Starting merge process...")
        
        Task {
            do {
                var allAssets: [AVAsset] = []
                for video in videos {
                    let asset = AVAsset(url: await getVideoURL(from: video.asset))
                    allAssets.append(asset)
                }
                
                for photo in photos {
                    if let photoAsset = await createVideoAsset(from: photo.asset, duration: CMTime(seconds: 3, preferredTimescale: 600)) {
                        allAssets.append(photoAsset)
                        print("Successfully converted photo to video: \(photo.id)")
                    } else {
                        print("Failed to convert photo to video: \(photo.id)")
                    }
                }
                
                print("Total assets converted: \(allAssets.count)")
                let mergedAsset = try await mergeAssets(allAssets)
                
                DispatchQueue.main.async {
                    completion(.success(mergedAsset))
                }
                
            } catch {
                print("Error in merge process: \(error)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    private func getVideoURL(from asset: PHAsset) async -> URL {
        return await withCheckedContinuation { continuation in
            let options = PHVideoRequestOptions()
            options.version = .original
            options.deliveryMode = .highQualityFormat
            
            PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
                if let urlAsset = avAsset as? AVURLAsset {
                    continuation.resume(returning: urlAsset.url)
                } else {
                    let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("temp_video_\(UUID().uuidString).mov")
                    continuation.resume(returning: tempURL)
                }
            }
        }
    }
    
    private func createVideoAsset(from photoAsset: PHAsset, duration: CMTime) async -> AVAsset? {
        guard let image = await getImage(from: photoAsset) else {
            print("Failed to get image from photo asset")
            return nil
        }
        
        return await withCheckedContinuation { continuation in
            let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("photo_video_\(UUID().uuidString).mov")
            
            createVideoFromImage(image: image, duration: duration, outputURL: tempURL) { success in
                if success {
                    let asset = AVAsset(url: tempURL)
                    print("Successfully created video asset from photo")
                    continuation.resume(returning: asset)
                } else {
                    print("Failed to create video asset from photo")
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    private func getImage(from asset: PHAsset) async -> UIImage? {
        return await withCheckedContinuation { continuation in
            let manager = PHImageManager.default()
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .none
            options.isSynchronous = false
            
            manager.requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFit, options: options) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
    
    private func createVideoFromImage(image: UIImage, duration: CMTime, outputURL: URL, completion: @escaping (Bool) -> Void) {
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try? FileManager.default.removeItem(at: outputURL)
        }
        
        guard let cgImage = image.cgImage else {
            print("Failed to get CGImage from UIImage")
            completion(false)
            return
        }
        
        let width = cgImage.width
        let height = cgImage.height
        
        do {
            let assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mov)
            
            let videoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: width,
                AVVideoHeightKey: height,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: 2000000,
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264BaselineAutoLevel
                ]
            ]
            
            let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            writerInput.expectsMediaDataInRealTime = false
            
            let pixelBufferAttributes: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height
            ]
            
            let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: writerInput,
                sourcePixelBufferAttributes: pixelBufferAttributes
            )
            
            guard assetWriter.canAdd(writerInput) else {
                print("Cannot add writer input to asset writer")
                completion(false)
                return
            }
            
            assetWriter.add(writerInput)
            
            guard assetWriter.startWriting() else {
                print("Failed to start writing: \(assetWriter.error?.localizedDescription ?? "Unknown error")")
                completion(false)
                return
            }
            
            assetWriter.startSession(atSourceTime: .zero)
            
            let queue = DispatchQueue(label: "video.writer.queue")
            
            writerInput.requestMediaDataWhenReady(on: queue) {
                if writerInput.isReadyForMoreMediaData {
                    var pixelBuffer: CVPixelBuffer?
                    
                    let status = CVPixelBufferPoolCreatePixelBuffer(nil, pixelBufferAdaptor.pixelBufferPool!, &pixelBuffer)
                    
                    if status == kCVReturnSuccess, let buffer = pixelBuffer {
                        CVPixelBufferLockBaseAddress(buffer, [])
                        
                        let context = CGContext(
                            data: CVPixelBufferGetBaseAddress(buffer),
                            width: width,
                            height: height,
                            bitsPerComponent: 8,
                            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
                        )
                        
                        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
                        
                        CVPixelBufferUnlockBaseAddress(buffer, [])
                        
                        if !pixelBufferAdaptor.append(buffer, withPresentationTime: .zero) {
                            print("Failed to append pixel buffer at start time")
                        }
                    }
                    
                    writerInput.markAsFinished()
                    
                    guard assetWriter.status == .writing else {
                        print("Asset writer is not in writing state: \(assetWriter.status.rawValue)")
                        if let error = assetWriter.error {
                            print("Asset writer error: \(error.localizedDescription)")
                        }
                        completion(false)
                        return
                    }
                    
                    assetWriter.finishWriting {
                        DispatchQueue.main.async {
                            if assetWriter.status == .completed {
                                completion(true)
                            } else {
                                print("Asset writer failed to complete: \(assetWriter.error?.localizedDescription ?? "Unknown error")")
                                completion(false)
                            }
                        }
                    }
                } else {
                    print("Writer input is not ready for more media data")
                    completion(false)
                }
            }
            
        } catch {
            print("Error creating asset writer: \(error)")
            completion(false)
        }
    }
    
    private func mergeAssets(_ assets: [AVAsset]) async throws -> AVAsset {
        print("Merging \(assets.count) assets")
        
        let composition = AVMutableComposition()
        
        guard let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
              let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw NSError(domain: "VideoMerger", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create composition tracks"])
        }
        
        var currentTime = CMTime.zero
        
        for (index, asset) in assets.enumerated() {
            print("Processing asset \(index + 1)/\(assets.count)")
            
            let assetDuration = asset.duration
            if let assetVideoTrack = asset.tracks(withMediaType: .video).first {
                do {
                    try videoTrack.insertTimeRange(
                        CMTimeRange(start: .zero, duration: assetDuration),
                        of: assetVideoTrack,
                        at: currentTime
                    )
                    print("Added video track for asset \(index + 1)")
                } catch {
                    print("Failed to add video track for asset \(index + 1): \(error)")
                    throw error
                }
            }
            if let assetAudioTrack = asset.tracks(withMediaType: .audio).first {
                do {
                    try audioTrack.insertTimeRange(
                        CMTimeRange(start: .zero, duration: assetDuration),
                        of: assetAudioTrack,
                        at: currentTime
                    )
                    print("Added audio track for asset \(index + 1)")
                } catch {
                    print("Failed to add audio track for asset \(index + 1): \(error)")
                }
            }
            
            currentTime = CMTimeAdd(currentTime, assetDuration)
        }
        
        print("Total composition duration: \(CMTimeGetSeconds(composition.duration)) seconds")
        
        return composition
    }
}
