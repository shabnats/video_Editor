import SwiftUI
import PhotosUI

struct VideoGalleryView: View {
    let onVideoSelected: (VideoItem) -> Void
    let onPhotoSelected: (PhotoItem) -> Void
    let onMultipleMediaSelected: ([VideoItem], [PhotoItem]) -> Void

    @State private var videos: [VideoItem] = []
    @State private var photos: [PhotoItem] = []
    @State private var selectedVideos: Set<String> = []
    @State private var selectedPhotos: Set<String> = []
    @State private var isMultiSelectMode = false
    @State private var hasPermission = false
    @State private var isLoading = true

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    private var allMediaItems: [MediaItem] {
        let videoItems = videos.map { MediaItem.video($0) }
        let photoItems = photos.map { MediaItem.photo($0) }
        return (videoItems + photoItems).sorted {
            ($0.creationDate ?? .distantPast) > ($1.creationDate ?? .distantPast)
        }
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                StatusBarView()

                HStack {
                    if isMultiSelectMode {
                        Button("Cancel") {
                            exitMultiSelectMode()
                        }
                        .foregroundColor(.white)

                        Spacer()

                        Text("\(selectedVideos.count + selectedPhotos.count) selected")
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundColor(.white)

                        Spacer()

                        Button("Done") {
                            handleMultipleSelection()
                        }
                        .foregroundColor(.blue)
                        .disabled(selectedVideos.isEmpty && selectedPhotos.isEmpty)
                    } else {
                        Text("All Media")
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundColor(.white)

                        Spacer()

                        Button("Select") {
                            isMultiSelectMode = true
                        }
                        .foregroundColor(.blue)
                        .padding(.trailing, 10)

                        Button(action: {}) {
                            Image(systemName: "xmark")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 15)
                .background(Color.black)

                if isLoading {
                    VStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                        Text("Loading media...")
                            .foregroundColor(.white)
                            .padding(.top, 20)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
                } else if !hasPermission {
                    VStack(spacing: 20) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)

                        Text("Access to Photos Required")
                            .font(.title2)
                            .foregroundColor(.white)

                        Text("Please allow access to your photos and videos to select media")
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)

                        Button("Allow Access") {
                            requestPermission()
                        }
                        .padding(.horizontal, 30)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(25)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
                } else if allMediaItems.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "photo.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)

                        Text("No Media Found")
                            .font(.title2)
                            .foregroundColor(.white)

                        Text("No videos or photos found in your photo library")
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(allMediaItems) { item in
                                switch item {
                                case .video(let video):
                                    VideoThumbnailView(
                                        video: video,
                                        isSelected: selectedVideos.contains(video.id),
                                        isMultiSelectMode: isMultiSelectMode
                                    ) {
                                        if isMultiSelectMode {
                                            toggleVideoSelection(for: video)
                                        } else {
                                            onVideoSelected(video)
                                        }
                                    }

                                case .photo(let photo):
                                    PhotoThumbnailView(
                                        photo: photo,
                                        isSelected: selectedPhotos.contains(photo.id),
                                        isMultiSelectMode: isMultiSelectMode
                                    ) {
                                        if isMultiSelectMode {
                                            togglePhotoSelection(for: photo)
                                        } else {
                                            onPhotoSelected(photo)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                    .background(Color.black)
                }
            }
        }
        .background(Color.black)
        .edgesIgnoringSafeArea(.all)
        .onAppear {
            checkPermissionAndLoadMedia()
        }
    }

    private func toggleVideoSelection(for video: VideoItem) {
        if selectedVideos.contains(video.id) {
            selectedVideos.remove(video.id)
        } else {
            selectedVideos.insert(video.id)
        }
        print("DEBUG - Video selection toggled: \(video.id)")
        print("DEBUG - Selected videos count: \(selectedVideos.count)")
    }

    private func togglePhotoSelection(for photo: PhotoItem) {
        if selectedPhotos.contains(photo.id) {
            selectedPhotos.remove(photo.id)
        } else {
            selectedPhotos.insert(photo.id)
        }
        print("DEBUG - Photo selection toggled: \(photo.id)")
        print("DEBUG - Selected photos count: \(selectedPhotos.count)")
    }

    private func exitMultiSelectMode() {
        isMultiSelectMode = false
        selectedVideos.removeAll()
        selectedPhotos.removeAll()
    }

    private func handleMultipleSelection() {
        let selectedVideoItems = videos.filter { selectedVideos.contains($0.id) }
        let selectedPhotoItems = photos.filter { selectedPhotos.contains($0.id) }
        print("DEBUG - handleMultipleSelection called")
        print("DEBUG - Selected video items: \(selectedVideoItems.count)")
        print("DEBUG - Selected photo items: \(selectedPhotoItems.count)")
        
        onMultipleMediaSelected(selectedVideoItems, selectedPhotoItems)
        exitMultiSelectMode()
    }

    private func checkPermissionAndLoadMedia() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)

        switch status {
        case .authorized, .limited:
            hasPermission = true
            loadMedia()
        case .denied, .restricted:
            hasPermission = false
            isLoading = false
        case .notDetermined:
            requestPermission()
        @unknown default:
            hasPermission = false
            isLoading = false
        }
    }

    private func requestPermission() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized, .limited:
                    hasPermission = true
                    loadMedia()
                default:
                    hasPermission = false
                    isLoading = false
                }
            }
        }
    }

    private func loadMedia() {
        isLoading = true
        loadVideos()
        loadPhotos()
    }

    private func loadVideos() {
        DispatchQueue.global(qos: .userInitiated).async {
            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            fetchOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.video.rawValue)
            let assets = PHAsset.fetchAssets(with: fetchOptions)
            var videoItems: [VideoItem] = []

            let imageManager = PHImageManager.default()
            let requestOptions = PHImageRequestOptions()
            requestOptions.isSynchronous = false
            requestOptions.deliveryMode = .opportunistic
            requestOptions.resizeMode = .fast

            let group = DispatchGroup()

            assets.enumerateObjects { asset, _, _ in
                group.enter()

                let duration = formatDuration(asset.duration)
                let targetSize = CGSize(width: 200, height: 200)

                imageManager.requestImage(
                    for: asset,
                    targetSize: targetSize,
                    contentMode: .aspectFill,
                    options: requestOptions
                ) { image, info in
                    defer { group.leave() }

                    if let isDegraded = info?[PHImageResultIsDegradedKey] as? Bool, isDegraded {
                        return
                    }

                    let videoItem = VideoItem(
                        asset: asset,
                        thumbnail: image,
                        duration: duration
                    )

                    DispatchQueue.main.async {
                        videoItems.append(videoItem)
                    }
                }
            }

            group.notify(queue: .main) {
                self.videos = videoItems.sorted {
                    ($0.asset.creationDate ?? .distantPast) > ($1.asset.creationDate ?? .distantPast)
                }
                self.checkLoadingComplete()
            }
        }
    }

    private func loadPhotos() {
        DispatchQueue.global(qos: .userInitiated).async {
            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            fetchOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
            let assets = PHAsset.fetchAssets(with: fetchOptions)
            var photoItems: [PhotoItem] = []

            let imageManager = PHImageManager.default()
            let requestOptions = PHImageRequestOptions()
            requestOptions.isSynchronous = false
            requestOptions.deliveryMode = .opportunistic
            requestOptions.resizeMode = .fast

            let group = DispatchGroup()

            assets.enumerateObjects { asset, _, _ in
                group.enter()

                let targetSize = CGSize(width: 200, height: 200)

                imageManager.requestImage(
                    for: asset,
                    targetSize: targetSize,
                    contentMode: .aspectFill,
                    options: requestOptions
                ) { image, info in
                    defer { group.leave() }

                    if let isDegraded = info?[PHImageResultIsDegradedKey] as? Bool, isDegraded {
                        return
                    }

                    let photoItem = PhotoItem(
                        asset: asset,
                        thumbnail: image
                    )

                    DispatchQueue.main.async {
                        photoItems.append(photoItem)
                    }
                }
            }

            group.notify(queue: .main) {
                self.photos = photoItems.sorted {
                    ($0.asset.creationDate ?? .distantPast) > ($1.asset.creationDate ?? .distantPast)
                }
                self.checkLoadingComplete()
            }
        }
    }

    private func checkLoadingComplete() {
        if !videos.isEmpty || !photos.isEmpty {
            isLoading = false
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
