//
//  VideoThumbnailView.swift
//  videoeditorApp
//
//  Created by macbook on 10/07/25.
//
import SwiftUI
struct VideoThumbnailView: View {
    let video: VideoItem
    let isSelected: Bool
    let isMultiSelectMode: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            GeometryReader { geometry in
                ZStack {
                    // Thumbnail
                    if let thumbnail = video.thumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                            .cornerRadius(8)
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.3))
                    }
                    
                    // Selection overlay
                    if isSelected {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue.opacity(0.3))
                            .frame(width: geometry.size.width, height: geometry.size.height)
                    }
                    
                    // Play button or selection indicator
                    if isMultiSelectMode {
                        // Selection circle
                        ZStack {
                            Circle()
                                .fill(isSelected ? Color.blue : Color.clear)
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 2)
                                )
                            
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .position(x: geometry.size.width - 15, y: 15)
                    }
                    
                    // Duration label
                    Text(video.duration)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(4)
                        .position(x: geometry.size.width - 25, y: geometry.size.height - 15)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

struct PhotoThumbnailView: View {
    let photo: PhotoItem
    let isSelected: Bool
    let isMultiSelectMode: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            GeometryReader { geometry in
                ZStack {
                    // Thumbnail
                    if let thumbnail = photo.thumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                            .cornerRadius(8)
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.3))
                    }

                    // Selection overlay
                    if isSelected {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue.opacity(0.3))
                            .frame(width: geometry.size.width, height: geometry.size.height)
                    }

                    // Selection circle
                    if isMultiSelectMode {
                        ZStack {
                            Circle()
                                .fill(isSelected ? Color.blue : Color.clear)
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 2)
                                )

                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .position(x: geometry.size.width - 15, y: 15)
                    } 
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
