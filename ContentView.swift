import SwiftUI

struct ContentView: View {
    @State private var currentScreen: Screen = .gallery
    @State private var selectedVideo: VideoItem?
    @State private var selectedVideos: [VideoItem] = []
    @State private var selectedPhotos: [PhotoItem] = []
    
    var body: some View {
        NavigationView {
            switch currentScreen {
            case .gallery:
                VideoGalleryView(
                    onVideoSelected: { video in
                        selectedVideo = video
                        selectedVideos = [video]
                        selectedPhotos = [] // reset photos
                        currentScreen = .preview
                    },
                    onPhotoSelected: { photo in
                        selectedVideo = nil // reset video
                        selectedVideos = [] // reset videos
                        selectedPhotos = [photo] // set single photo
                        currentScreen = .preview
                    },
                    onMultipleMediaSelected: { videos, photos in
                        selectedVideos = videos
                        selectedPhotos = photos
                        selectedVideo = videos.first
                        currentScreen = .preview
                    }
                )
            case .preview:
                VideoPreviewView(
                    selectedVideos: selectedVideos,
                    selectedPhotos: selectedPhotos,
                    onClose: {
                        currentScreen = .gallery
                        selectedVideos = []
                        selectedPhotos = []
                        selectedVideo = nil
                    },
                    onNext: {
                        currentScreen = .editor
                    }
                )
                
            case .editor:
                VideoEditorView(
                    video: selectedVideo,
                    
                    onClose: {
                        currentScreen = .gallery
                        selectedVideos = []
                        selectedVideo = nil
                    }
                )
            }
        }
        .navigationBarHidden(true)
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .preferredColorScheme(.dark)
    }
}
