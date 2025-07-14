import SwiftUI
import PhotosUI
import AVFoundation

// MARK: - Models
struct VideoItem: Identifiable {
    let id = UUID().uuidString
    let asset: PHAsset
    let thumbnail: UIImage?
    let duration: String
}

extension VideoItem {
    var mediaType: MediaType { .video }
    var creationDate: Date? { asset.creationDate }
}

struct PhotoItem: Identifiable {
    let id = UUID().uuidString
    let asset: PHAsset
    let thumbnail: UIImage?
    init(asset: PHAsset, thumbnail: UIImage? = nil) {
        self.asset = asset
        self.thumbnail = thumbnail
    }
}

extension PhotoItem {
    var mediaType: MediaType { .photo }
    var creationDate: Date? { asset.creationDate }
}

enum Screen {
    case gallery
    case preview
    case editor
}

enum MediaType {
    case photo
    case video
}

enum MediaItem: Identifiable, Equatable {
    case photo(PhotoItem)
    case video(VideoItem)
    
    var id: String {
        switch self {
        case .photo(let photo):
            return photo.id
        case .video(let video):
            return video.id
        }
    }
    
    var thumbnail: UIImage? {
        switch self {
        case .photo(let photo):
            return photo.thumbnail
        case .video(let video):
            return video.thumbnail
        }
    }
    
    var mediaType: MediaType {
        switch self {
        case .photo:
            return .photo
        case .video:
            return .video
        }
    }
    
    var asset: PHAsset {
        switch self {
        case .photo(let photo):
            return photo.asset
        case .video(let video):
            return video.asset
        }
    }
    
    var creationDate: Date? {
        return asset.creationDate
    }
    
    var duration: String {
        switch self {
        case .photo:
            return "Photo"
        case .video(let video):
            return video.duration
        }
    }
    
    // MARK: - Equatable conformance
    static func == (lhs: MediaItem, rhs: MediaItem) -> Bool {
        switch (lhs, rhs) {
        case (.photo(let lhsPhoto), .photo(let rhsPhoto)):
            return lhsPhoto.id == rhsPhoto.id
        case (.video(let lhsVideo), .video(let rhsVideo)):
            return lhsVideo.id == rhsVideo.id
        default:
            return false
        }
    }
}

//
//import UIKit
//import PhotosUI
//import AVFoundation
//
//// MARK: - Media Item Types
//
//enum MediaItem {
//    case video(VideoItem)
//    case photo(PhotoItem)
//    
//    var thumbnail: UIImage? {
//        switch self {
//        case .video(let videoItem):
//            return videoItem.thumbnail
//        case .photo(let photoItem):
//            return photoItem.thumbnail
//        }
//    }
//    
//    var creationDate: Date? {
//        switch self {
//        case .video(let videoItem):
//            return videoItem.asset.creationDate
//        case .photo(let photoItem):
//            return photoItem.asset.creationDate
//        }
//    }
//    
//    var mediaType: MediaType {
//        switch self {
//        case .video:
//            return .video
//        case .photo:
//            return .photo
//        }
//    }
//}
//
//enum MediaType {
//    case video
//    case photo
//}
//
//// MARK: - Video Item
//
//struct VideoItem: Identifiable {
//    let id = UUID()
//    let asset: PHAsset
//    let thumbnail: UIImage?
//    
//    var duration: String {
//        let durationSeconds = asset.duration
//        let minutes = Int(durationSeconds) / 60
//        let seconds = Int(durationSeconds) % 60
//        return String(format: "%d:%02d", minutes, seconds)
//    }
//    
//    init(asset: PHAsset, thumbnail: UIImage? = nil) {
//        self.asset = asset
//        self.thumbnail = thumbnail
//    }
//}
//
//// MARK: - Photo Item
//

//}
