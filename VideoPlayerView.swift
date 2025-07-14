import SwiftUI
import AVFoundation
import PhotosUI

struct VideoPlayerView: UIViewRepresentable {
    let video: VideoItem?
    @Binding var currentTime: Double
    @Binding var totalTime: Double
    @Binding var isPlaying: Bool
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let playerLayer = AVPlayerLayer()
        playerLayer.videoGravity = .resizeAspect
        view.layer.addSublayer(playerLayer)
        
        context.coordinator.playerLayer = playerLayer
        context.coordinator.setupPlayer()
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let layer = uiView.layer.sublayers?.first as? AVPlayerLayer {
            layer.frame = uiView.bounds
        }
        
        context.coordinator.updatePlaybackState(isPlaying: isPlaying)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: VideoPlayerView
        var player: AVPlayer?
        var playerLayer: AVPlayerLayer?
        var timeObserver: Any?
        private var lastPlayingState: Bool = false
        
        init(_ parent: VideoPlayerView) {
            self.parent = parent
            super.init()
        }
        
        func setupPlayer() {
            guard let video = parent.video else { return }
            
            let imageManager = PHImageManager.default()
            let requestOptions = PHVideoRequestOptions()
            requestOptions.deliveryMode = .highQualityFormat
            requestOptions.isNetworkAccessAllowed = true
            
            imageManager.requestAVAsset(forVideo: video.asset, options: requestOptions) { [weak self] avAsset, _, _ in
                guard let self = self, let avAsset = avAsset else { return }
                
                DispatchQueue.main.async {
                    let playerItem = AVPlayerItem(asset: avAsset)
                    self.player = AVPlayer(playerItem: playerItem)
                    self.playerLayer?.player = self.player
                    
                    let duration = CMTimeGetSeconds(avAsset.duration)
                    self.parent.totalTime = duration
                    
                    self.addTimeObserver()
                    self.addObservers()
                }
            }
        }
        
        func updatePlaybackState(isPlaying: Bool) {
            guard let player = player, lastPlayingState != isPlaying else { return }
            
            lastPlayingState = isPlaying
            
            if isPlaying {
                player.play()
            } else {
                player.pause()
            }
        }
        
        func addTimeObserver() {
            guard let player = player else { return }
            
            let timeScale = CMTimeScale(NSEC_PER_SEC)
            let time = CMTime(seconds: 0.1, preferredTimescale: timeScale)
            
            timeObserver = player.addPeriodicTimeObserver(forInterval: time, queue: .main) { [weak self] time in
                self?.parent.currentTime = CMTimeGetSeconds(time)
            }
        }
        
        func addObservers() {
            guard let player = player else { return }
            
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player.currentItem,
                queue: .main
            ) { [weak self] _ in
                self?.parent.isPlaying = false
                self?.player?.seek(to: .zero)
            }
        }
        
        deinit {
            if let timeObserver = timeObserver {
                player?.removeTimeObserver(timeObserver)
            }
            NotificationCenter.default.removeObserver(self)
        }
    }
}
