//
//  VideoTrimmingService.swift
//  videoeditorApp
//
//  Created by macbook on 11/07/25.
//


import Foundation
import AVFoundation
import UIKit

class VideoTrimmingService: ObservableObject {
    @Published var isProcessing = false
    @Published var progress: Double = 0
    
    func trimVideo(asset: AVAsset, startTime: Double, endTime: Double, completion: @escaping (Result<URL, Error>) -> Void) {
        DispatchQueue.main.async {
            self.isProcessing = true
            self.progress = 0
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            // Create composition
            let composition = AVMutableComposition()
            let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
            let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
            
            guard let assetVideoTrack = asset.tracks(withMediaType: .video).first else {
                DispatchQueue.main.async {
                    completion(.failure(VideoTrimmingError.noVideoTrack))
                    self.isProcessing = false
                }
                return
            }
            
            // Define time range for trimming
            let startCMTime = CMTime(seconds: startTime, preferredTimescale: 600)
            let endCMTime = CMTime(seconds: endTime, preferredTimescale: 600)
            let timeRange = CMTimeRange(start: startCMTime, end: endCMTime)
            
            do {
                // Insert video track
                try videoTrack?.insertTimeRange(timeRange, of: assetVideoTrack, at: .zero)
                
                // Insert audio track if available
                if let assetAudioTrack = asset.tracks(withMediaType: .audio).first {
                    try audioTrack?.insertTimeRange(timeRange, of: assetAudioTrack, at: .zero)
                }
                
                // Apply video track transform
                videoTrack?.preferredTransform = assetVideoTrack.preferredTransform
                
                // Export the trimmed video
                self.exportTrimmedVideo(composition: composition, completion: completion)
                
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                    self.isProcessing = false
                }
            }
        }
    }
    
    private func exportTrimmedVideo(composition: AVMutableComposition, completion: @escaping (Result<URL, Error>) -> Void) {
        // Create output URL
        let outputURL = self.createTempVideoURL()
        
        // Remove existing file if it exists
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try? FileManager.default.removeItem(at: outputURL)
        }
        
        // Create export session
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            DispatchQueue.main.async {
                completion(.failure(VideoTrimmingError.exportSessionFailed))
                self.isProcessing = false
            }
            return
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        
        // Start export with progress monitoring
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            DispatchQueue.main.async {
                self.progress = Double(exportSession.progress)
            }
        }
        
        exportSession.exportAsynchronously {
            timer.invalidate()
            
            DispatchQueue.main.async {
                self.isProcessing = false
                
                switch exportSession.status {
                case .completed:
                    completion(.success(outputURL))
                case .failed:
                    completion(.failure(exportSession.error ?? VideoTrimmingError.exportFailed))
                case .cancelled:
                    completion(.failure(VideoTrimmingError.exportCancelled))
                default:
                    completion(.failure(VideoTrimmingError.exportFailed))
                }
            }
        }
    }
    
    private func createTempVideoURL() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let outputURL = documentsPath.appendingPathComponent("trimmed_video_\(UUID().uuidString).mp4")
        return outputURL
    }
    
    func generateThumbnail(from url: URL, completion: @escaping (UIImage?) -> Void) {
        let asset = AVAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 300, height: 300)
        
        let time = CMTime(seconds: 0.1, preferredTimescale: 600)
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
                let thumbnail = UIImage(cgImage: cgImage)
                DispatchQueue.main.async {
                    completion(thumbnail)
                }
            } catch {
                print("Error generating thumbnail: \(error)")
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
}

enum VideoTrimmingError: Error, LocalizedError {
    case noVideoTrack
    case exportSessionFailed
    case exportFailed
    case exportCancelled
    
    var errorDescription: String? {
        switch self {
        case .noVideoTrack:
            return "No video track found"
        case .exportSessionFailed:
            return "Failed to create export session"
        case .exportFailed:
            return "Video export failed"
        case .exportCancelled:
            return "Video export was cancelled"
        }
    }
}


