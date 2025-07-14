import SwiftUI
import PhotosUI
import AVFoundation

struct VideoEditorView: View {
    let video: VideoItem?
    let onClose: () -> Void
//    let selectedVideos: [VideoItem]
//    let selectedPhotos: [PhotoItem]

    @State private var showCloseAlert = false
    @State private var currentTime: Double = 0
    @State private var totalTime: Double = 10
    @State private var videoThumbnails: [UIImage] = []
    @State private var trimStartTime: Double = 0
    @State private var trimEndTime: Double = 10
    @State private var dragOffset: CGFloat = 0
    @State private var isPlaying: Bool = false
    @State private var showPlayButton: Bool = true
    @State private var mergedAsset: AVAsset?
    
//    private var allMediaItems: [MediaItem] {
//        let videoItems = selectedVideos.map { MediaItem.video($0) }
//        let photoItems = selectedPhotos.map { MediaItem.photo($0) }
//        let combinedItems = videoItems + photoItems
//        
//        return combinedItems.sorted { item1, item2 in
//            let date1 = item1.creationDate ?? Date.distantPast
//            let date2 = item2.creationDate ?? Date.distantPast
//            return date1 > date2
//        }
//    }
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                StatusBarView()

                HStack {
                    Button(action: {
                        showCloseAlert = true
                    }) {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(.white)
                    }

                    Spacer()
                    
                    Image(systemName: "xmark")
                        .font(.title2)
                        .foregroundColor(.clear)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 15)
                .background(Color.black)
                
                ZStack(alignment: .topTrailing) {
                    ZStack {
                        if let video = video {
                            VideoPlayerView(
                                video: video,
                                currentTime: $currentTime,
                                totalTime: $totalTime,
                                isPlaying: $isPlaying
                            )
                            .aspectRatio(9/16, contentMode: .fit)
                            .cornerRadius(12)
                            .padding(.horizontal, 20)
                            .onTapGesture {
                                togglePlayPause()
                            }
                        } else {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.3))
                                .aspectRatio(9/16, contentMode: .fit)
                                .padding(.horizontal, 20)
                        }
                        if showPlayButton {
                            Button(action: togglePlayPause) {
                                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.white)
                                    .background(Color.black.opacity(0.3))
                                    .clipShape(Circle())
                            }
                        }
                    }
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showPlayButton.toggle()
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showPlayButton = false
                            }
                        }
                    }
                    
                    VStack(spacing: 20) {
                        MenuButton(icon: "textformat")
                        MenuButton(icon: "music.note")
                        MenuButton(icon: "sparkles")
                        MenuButton(icon: "square.and.arrow.down")
                    }
                    .padding(.trailing, 30)
                    .padding(.top, 20)
                }
                .padding(.top, 20)
                .background(Color.black)
                
                Spacer()
                
                VStack(spacing: 15) {
                    Text(String(format: "%.1f/%.1f", currentTime, totalTime))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                    
//                    DraggableTimelineView(
//                        currentTime: $currentTime,
//                        totalTime: totalTime,
//                        trimStartTime: $trimStartTime,
//                        trimEndTime: $trimEndTime,
//                        mediaItems: allMediaItems,
//                        mergedAsset: mergedAsset
//                    )
                    .padding(.horizontal, 20)
                    
                    HStack(spacing: 20) {
                        Button("Save Draft") {
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.5), lineWidth: 1.5)
                        )
                        Spacer()
                        Button("Share") {
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.orange, lineWidth: 1.5)
                        )
                    }
                    .padding(.horizontal, 20)
                }
               
                .padding(.bottom, 40)
                .background(Color.black)
            }
            .background(Color.black)
        }
        .edgesIgnoringSafeArea(.all)
        .onAppear {
            if let video = video {
                totalTime = video.asset.duration
                trimEndTime = totalTime
                generateVideoThumbnails()
            }
        }
        .onDisappear {
            isPlaying = false
        }
        .alert("Close Now?", isPresented: $showCloseAlert) {
            Button("Close Without Saving", role: .destructive) {
                onClose()
            }
            Button("Save as Draft") {
                onClose()
            }
            Button("Keep Editing", role: .cancel) {}
        } message: {
            Text("If you close now, your video will be lost.")
        }
    }
    
    private func togglePlayPause() {
        isPlaying.toggle()
        showPlayButton = true
        if isPlaying {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showPlayButton = false
                }
            }
        }
    }
    
    private func seekToTime(_ time: Double) {
        currentTime = time
    }

    private func generateVideoThumbnails() {
        guard let video = video else { return }

        let imageManager = PHImageManager.default()
        let requestOptions = PHVideoRequestOptions()
        requestOptions.deliveryMode = .fastFormat

        imageManager.requestAVAsset(forVideo: video.asset, options: requestOptions) { avAsset, _, _ in
            guard let avAsset = avAsset else { return }

            let generator = AVAssetImageGenerator(asset: avAsset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 100, height: 100)

            let duration = avAsset.duration
            let timeInterval = CMTimeGetSeconds(duration) / 8.0
            var thumbnails: [UIImage] = []

            for i in 0..<8 {
                let time = CMTime(seconds: Double(i) * timeInterval, preferredTimescale: 600)

                do {
                    let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
                    let thumbnail = UIImage(cgImage: cgImage)
                    thumbnails.append(thumbnail)
                } catch {
                    print("Error generating thumbnail: \(error)")
                }
            }

            DispatchQueue.main.async {
                self.videoThumbnails = thumbnails
            }
        }
    }
}
