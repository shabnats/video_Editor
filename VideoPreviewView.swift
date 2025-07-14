import SwiftUI
import PhotosUI
import AVFoundation

struct VideoPreviewView: View {
    let selectedVideos: [VideoItem]
    let selectedPhotos: [PhotoItem]
    let onClose: () -> Void
    let onNext: () -> Void
    
    @State private var currentTime: Double = 0
    @State private var totalTime: Double = 10
    @State private var videoThumbnails: [UIImage] = []
    @State private var trimStartTime: Double = 0
    @State private var trimEndTime: Double = 10
    @State private var isPlaying: Bool = false
    @State private var showPlayButton: Bool = true
    @State private var mergedAsset: AVAsset?
    @State private var isLoading: Bool = false
    @State private var currentMediaIndex: Int = 0
    @State private var showingMediaStrip: Bool = false
    
    @StateObject private var videoMerger = VideoMergerService()
    
    private var allMediaItems: [MediaItem] {
        let videoItems = selectedVideos.map { MediaItem.video($0) }
        let photoItems = selectedPhotos.map { MediaItem.photo($0) }
        let combinedItems = videoItems + photoItems
        
        return combinedItems.sorted { item1, item2 in
            let date1 = item1.creationDate ?? Date.distantPast
            let date2 = item2.creationDate ?? Date.distantPast
            return date1 > date2
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                Color.black.ignoresSafeArea()
                
                if isLoading {
                    LoadingView()
                } else {
                    mainContentView
                }
                
                topNavigationView
            }
        }
        .onAppear {
            setupMedia()
        }
        .onDisappear {
            isPlaying = false
        }
        .onChange(of: videoMerger.mergedAsset) { oldValue, newValue in
            handleMergedAssetChange(newValue)
        }
    }
    
    // MARK: - Main Content View
    private var mainContentView: some View {
        VStack(spacing: 0) {
            mediaDisplayContainer
            Spacer()
            
            if showingMediaStrip && allMediaItems.count > 1 {
                mediaStripView
            }
            
            timelineContainer
        }
    }
    
    // MARK: - Media Display Container
    private var mediaDisplayContainer: some View {
        ZStack {
            if allMediaItems.isEmpty {
                emptyMediaView
            } else {
                currentMediaView
            }
            
            playButtonOverlay
        }
        .gesture(mediaSwipeGesture)
    }
    
    private var emptyMediaView: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.gray.opacity(0.3))
            .aspectRatio(9/16, contentMode: .fit)
            .frame(maxWidth: .infinity)
    }
    
    private var currentMediaView: some View {
        Group {
            if currentMediaIndex < allMediaItems.count {
                let currentMedia = allMediaItems[currentMediaIndex]
                
                switch currentMedia {
                case .video(let videoItem):
                    videoPlayerView(for: videoItem)
                case .photo(let photoItem):
                    photoView(for: photoItem)
                }
            } else {
                emptyMediaView
            }
        }
    }
    
    private func videoPlayerView(for videoItem: VideoItem) -> some View {
        Group {
            if shouldShowMergedVideo, let asset = mergedAsset {
                mergedVideoPlayer(asset: asset)
            } else {
                singleVideoPlayer(video: videoItem)
            }
        }
    }
    
    private var shouldShowMergedVideo: Bool {
        selectedVideos.count > 1 || selectedPhotos.count > 0
    }
    
    private func mergedVideoPlayer(asset: AVAsset) -> some View {
        MergedVideoPlayerView(
            asset: asset,
            currentTime: $currentTime,
            totalTime: $totalTime,
            isPlaying: $isPlaying
        )
        .aspectRatio(9/16, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipped()
        .onTapGesture {
            togglePlayPause()
        }
    }
    
    private func singleVideoPlayer(video: VideoItem) -> some View {
        VideoPlayerView(
            video: video,
            currentTime: $currentTime,
            totalTime: $totalTime,
            isPlaying: $isPlaying
        )
        .aspectRatio(9/16, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipped()
        .onTapGesture {
            togglePlayPause()
        }
    }
    
    private func photoView(for photoItem: PhotoItem) -> some View {
        PhotoDisplayView(photo: photoItem)
            .aspectRatio(9/16, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .clipped()
            .onTapGesture {
                withAnimation(.easeInOut(duration: 3)) {
                    showingMediaStrip.toggle()
                }
            }
    }
    
    // MARK: - Play Button Overlay
    private var playButtonOverlay: some View {
        Group {
            if shouldShowPlayButton {
                Button(action: togglePlayPause) {
                    playButtonImage
                }
            }
        }
    }
    
    private var shouldShowPlayButton: Bool {
        if allMediaItems.isEmpty || currentMediaIndex >= allMediaItems.count { return false }
        
        let currentMedia = allMediaItems[currentMediaIndex]
        switch currentMedia {
        case .video:
            return showPlayButton
        case .photo:
            return false
        }
    }
    
    private var playButtonImage: some View {
        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
            .font(.system(size: 60))
            .foregroundColor(.white)
            .background(Color.black.opacity(0.3))
            .clipShape(Circle())
    }
    
    // MARK: - Media Strip View
    private var mediaStripView: some View {
        VStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(allMediaItems.enumerated()), id: \.offset) { index, mediaItem in
                        MediaThumbnailView(
                            mediaItem: mediaItem,
                            isSelected: index == currentMediaIndex,
                            index: index
                        )
                        .onTapGesture {
                            currentMediaIndex = index
                            updateMediaDisplay()
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            .frame(height: 80)
        }
        .padding(.bottom, 10)
        .background(Color.black.opacity(0.8))
        .cornerRadius(15)
        .padding(.horizontal, 20)
    }
    
    // MARK: - Timeline Container
    private var timelineContainer: some View {
        Group {
            if !allMediaItems.isEmpty && currentMediaIndex < allMediaItems.count {
                let currentMedia = allMediaItems[currentMediaIndex]
                
                switch currentMedia {
                case .video:
                    videoTimelineView
                case .photo:
                    photoInfoView
                }
            }
        }
    }
    
    private var videoTimelineView: some View {
        VStack(spacing: 15) {
            timeDisplayText
            
            DraggableTimelineView(
                currentTime: $currentTime,
                totalTime: totalTime,
                trimStartTime: $trimStartTime,
                trimEndTime: $trimEndTime,
                mediaItems: allMediaItems,
                mergedAsset: mergedAsset
            )
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 20)
    }
    
    private var timeDisplayText: some View {
        Text(String(format: "%.1f/%.1f", currentTime, totalTime))
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.white)
    }
    
    private var photoInfoView: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "photo")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                
                Text("Photo")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
            }
        }
        .padding(.bottom, 20)
    }
    
    // MARK: - Top Navigation View
    private var topNavigationView: some View {
        VStack {
            HStack {
                cancelButton
                Spacer()
                mediaCounterView
                Spacer()
                nextButton
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            Spacer()
        }
    }
    
    private var cancelButton: some View {
        Button(action: onClose) {
            Text("Cancel")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.9))
                .cornerRadius(20)
        }
    }
    
    private var mediaCounterView: some View {
        Group {
            if allMediaItems.count > 1 {
                Text("\(currentMediaIndex + 1) of \(allMediaItems.count)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(15)
            }
        }
    }
    
    private var nextButton: some View {
        Button(action: onNext) {
            Text("Next")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.orange, lineWidth: 1.5)
                )
        }
    }
    
    // MARK: - Gestures
    private var mediaSwipeGesture: some Gesture {
        DragGesture()
            .onEnded { value in
                handleSwipeGesture(value)
            }
    }
    
    private func handleSwipeGesture(_ value: DragGesture.Value) {
        if value.translation.width > 50 && currentMediaIndex > 0 {
            currentMediaIndex -= 1
            updateMediaDisplay()
        } else if value.translation.width < -50 && currentMediaIndex < allMediaItems.count - 1 {
            currentMediaIndex += 1
            updateMediaDisplay()
        }
    }
    
    // MARK: - Helper Methods
    private func handleMergedAssetChange(_ asset: AVAsset?) {
        if let asset = asset {
            mergedAsset = asset
            totalTime = CMTimeGetSeconds(asset.duration)
            trimEndTime = totalTime
            generateMergedVideoThumbnails()
            isLoading = false
        }
    }
    
    private func setupMedia() {
        print("Setting up media - Videos: \(selectedVideos.count), Photos: \(selectedPhotos.count)")
        if allMediaItems.count > 1 {
            showingMediaStrip = true
        }
        let needsMerging = selectedVideos.count > 1 || selectedPhotos.count > 0
        
        if needsMerging {
            print("Media needs merging")
            isLoading = true
            
            videoMerger.mergeMediaItems(videos: selectedVideos, photos: selectedPhotos) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let asset):
                        print("Media merged successfully")
                        self.mergedAsset = asset
                        self.totalTime = CMTimeGetSeconds(asset.duration)
                        self.trimEndTime = self.totalTime
                        self.generateMergedVideoThumbnails()
                        self.isLoading = false
                    case .failure(let error):
                        print("Error merging media: \(error.localizedDescription)")
                        self.handleMergingFailure()
                    }
                }
            }
        } else if let firstVideo = selectedVideos.first {
            print("Single video case")
            totalTime = firstVideo.asset.duration
            trimEndTime = totalTime
            generateVideoThumbnails(for: firstVideo)
            isLoading = false
        } else if let firstPhoto = selectedPhotos.first {
            print("Single photo case")
            isLoading = false
            showPlayButton = false
        } else {
            print("No media selected")
            isLoading = false
        }
    }

    private func handleMergingFailure() {
        print("Handling merging failure - falling back to individual display")
        isLoading = false
        mergedAsset = nil
        
        if let firstVideo = selectedVideos.first {
            totalTime = firstVideo.asset.duration
            trimEndTime = totalTime
            generateVideoThumbnails(for: firstVideo)
        }
        currentMediaIndex = 0
        updateMediaDisplay()
    }
    
    private func updateMediaDisplay() {
        if currentMediaIndex < allMediaItems.count {
            let currentMedia = allMediaItems[currentMediaIndex]
            
            switch currentMedia {
            case .video(let videoItem):
                if mergedAsset == nil {
                    totalTime = videoItem.asset.duration
                    trimEndTime = totalTime
                    generateVideoThumbnails(for: videoItem)
                }
                showPlayButton = true
            case .photo:
                isPlaying = false
                showPlayButton = false
            }
        }
    }
    
    private func togglePlayPause() {
        let canPlay = mergedAsset != nil ||
                     (currentMediaIndex < allMediaItems.count &&
                      allMediaItems[currentMediaIndex].mediaType == .video)
        
        if canPlay {
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
    }
    
    private func generateVideoThumbnails(for video: VideoItem) {
        let imageManager = PHImageManager.default()
        let requestOptions = PHVideoRequestOptions()
        requestOptions.deliveryMode = .automatic
        
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
    
    private func generateMergedVideoThumbnails() {
        guard let asset = mergedAsset else { return }
        
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 100, height: 100)
        
        let duration = asset.duration
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

// MARK: - Photo Display View
struct PhotoDisplayView: View {
    let photo: PhotoItem
    
    var body: some View {
        ZStack {
            photoImageView
            photoIndicator
        }
    }
    
    private var photoImageView: some View {
        Group {
            if let thumbnail = photo.thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    private var photoIndicator: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Image(systemName: "photo")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(8)
                    .padding(16)
            }
        }
    }
}

// MARK: - Media Thumbnail View
struct MediaThumbnailView: View {
    let mediaItem: MediaItem
    let isSelected: Bool
    let index: Int
    
    var body: some View {
        ZStack {
            thumbnailImage
            selectionIndicator
            overlayIndicators
        }
    }
    
    private var thumbnailImage: some View {
        Group {
            if let thumbnail = mediaItem.thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 80)
                    .clipped()
                    .cornerRadius(8)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 80)
                    .cornerRadius(8)
            }
        }
    }
    
    private var selectionIndicator: some View {
        Group {
            if isSelected {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.orange, lineWidth: 2)
                    .frame(width: 60, height: 80)
            }
        }
    }
    
    private var overlayIndicators: some View {
        VStack {
            indexIndicator
            Spacer()
            mediaTypeIndicator
        }
        .padding(4)
    }
    
    private var indexIndicator: some View {
        HStack {
            Text("\(index + 1)")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
                .padding(4)
                .background(Color.black.opacity(0.7))
                .cornerRadius(4)
            
            Spacer()
        }
    }
    
    private var mediaTypeIndicator: some View {
        HStack {
            Spacer()
            
            HStack(spacing: 2) {
                Image(systemName: mediaItem.mediaType == .video ? "video.fill" : "photo")
                    .font(.system(size: 8))
                    .foregroundColor(.white)
                
                if case .video(let videoItem) = mediaItem {
                    Text(videoItem.duration)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(Color.black.opacity(0.7))
            .cornerRadius(3)
        }
    }
}

// MARK: - Loading View
struct LoadingView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .progressViewStyle(CircularProgressViewStyle(tint: .orange))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.8))
    }
}

// MARK: - Merged Video Player View
struct MergedVideoPlayerView: UIViewRepresentable {
    let asset: AVAsset
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
        var parent: MergedVideoPlayerView
        var player: AVPlayer?
        var playerLayer: AVPlayerLayer?
        var timeObserver: Any?
        private var lastPlayingState: Bool = false
        
        init(_ parent: MergedVideoPlayerView) {
            self.parent = parent
            super.init()
        }
        
        func setupPlayer() {
            let playerItem = AVPlayerItem(asset: parent.asset)
            player = AVPlayer(playerItem: playerItem)
            playerLayer?.player = player
            
            let duration = CMTimeGetSeconds(parent.asset.duration)
            parent.totalTime = duration
            
            addTimeObserver()
            addObservers()
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
