import SwiftUI
import AVFoundation
import PhotosUI

struct DraggableTimelineView: View {
    @Binding var currentTime: Double
    let totalTime: Double
    @Binding var trimStartTime: Double
    @Binding var trimEndTime: Double
    let mediaItems: [MediaItem]
    let mergedAsset: AVAsset?
    
    @State private var isDraggingSeeker = false
    @State private var isDraggingStart = false
    @State private var isDraggingEnd = false
    @State private var timelineThumbnails: [UIImage] = []
    @State private var mediaItemDurations: [Double] = []
    
    private let timelineHeight: CGFloat = 30
    private let handleWidth: CGFloat = 8
    private let minThumbnailWidth: CGFloat = 40
    
    private var sortedMediaItems: [MediaItem] {
        return mediaItems.sorted { item1, item2 in
            let date1 = item1.creationDate ?? Date.distantPast
            let date2 = item2.creationDate ?? Date.distantPast
            return date1 > date2
        }
    }
    
    private func calculateOptimalThumbnailCount(for width: CGFloat) -> Int {
        guard totalTime > 0 else { return 0 }
        
        let maxThumbnailsByWidth = Int(width / minThumbnailWidth)
        
        if mergedAsset != nil {
            let timeBasedCount = max(1, Int(totalTime / 2))
            return min(timeBasedCount, maxThumbnailsByWidth)
        } else {
            let contentBasedCount = max(1, sortedMediaItems.count * 2)
            return min(contentBasedCount, maxThumbnailsByWidth)
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            timelineContent(geometry: geometry)
        }
        .frame(height: timelineHeight)
        .onAppear {
            generateTimelineThumbnails(for: UIScreen.main.bounds.width)
        }
        .onChange(of: mediaItems) { oldValue, newValue in
            generateTimelineThumbnails(for: UIScreen.main.bounds.width)
        }
        .onChange(of: mergedAsset) { oldValue, newValue in
            generateTimelineThumbnails(for: UIScreen.main.bounds.width)
        }
    }
    
    // MARK: - Sub-views
    private func timelineContent(geometry: GeometryProxy) -> some View {
        ZStack(alignment: .leading) {
            thumbnailsBackground(geometry: geometry)
            trimOverlays(geometry: geometry)
            startTrimHandle(geometry: geometry)
            endTrimHandle(geometry: geometry)
            seekerLine(geometry: geometry)
        }
        .frame(height: timelineHeight)
        .clipped()
        .onTapGesture { location in
            let tappedTime = (location.x / geometry.size.width) * totalTime
            currentTime = max(0, min(totalTime, tappedTime))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange, lineWidth: 1)
        )
    }
    
    private func thumbnailsBackground(geometry: GeometryProxy) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<timelineThumbnails.count, id: \.self) { index in
                thumbnailView(at: index, geometry: geometry)
            }
        }
        .background(Color.black.opacity(0.8))
        .cornerRadius(8)
    }
    
    private func thumbnailView(at index: Int, geometry: GeometryProxy) -> some View {
        let cellWidth = timelineThumbnails.count > 0 ?
            geometry.size.width / CGFloat(timelineThumbnails.count) :
            geometry.size.width
        
        return Image(uiImage: timelineThumbnails[index])
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: cellWidth, height: timelineHeight)
            .clipped()
    }
    
    private func trimOverlays(geometry: GeometryProxy) -> some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(Color.black.opacity(0.7))
                .frame(width: startPosition(in: geometry.size.width))
            
            Rectangle()
                .fill(Color.clear)
                .frame(width: selectedWidth(in: geometry.size.width))
            
            Rectangle()
                .fill(Color.black.opacity(0.7))
                .frame(width: endOverlayWidth(in: geometry.size.width))
        }
        .cornerRadius(8)
    }
    
    private func startTrimHandle(geometry: GeometryProxy) -> some View {
        VStack(spacing: 2) {
            Rectangle()
                .fill(Color.white)
                .frame(width: 2, height: 4)
            Rectangle()
                .fill(Color.white)
                .frame(width: 2, height: 4)
            Rectangle()
                .fill(Color.white)
                .frame(width: 2, height: 4)
        }
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white)
                .frame(width: handleWidth, height: timelineHeight)
        )
        .offset(x: startPosition(in: geometry.size.width) - handleWidth/2)
        .gesture(startTrimGesture(geometry: geometry))
    }
    
    private func endTrimHandle(geometry: GeometryProxy) -> some View {
        VStack(spacing: 2) {
            Rectangle()
                .fill(Color.white)
                .frame(width: 2, height: 8)
            Rectangle()
                .fill(Color.white)
                .frame(width: 2, height: 8)
            Rectangle()
                .fill(Color.white)
                .frame(width: 2, height: 8)
        }
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white)
                .frame(width: handleWidth, height: timelineHeight)
        )
        .offset(x: endPosition(in: geometry.size.width) - handleWidth/2)
        .gesture(endTrimGesture(geometry: geometry))
    }
    
    private func seekerLine(geometry: GeometryProxy) -> some View {
        Rectangle()
            .fill(Color.orange)
            .frame(width: 2, height: timelineHeight + 8)
            .offset(x: currentTimePosition(in: geometry.size.width) - 1)
            .gesture(seekerGesture(geometry: geometry))
    }
    
    // MARK: - Gestures
    private func startTrimGesture(geometry: GeometryProxy) -> some Gesture {
        DragGesture()
            .onChanged { value in
                isDraggingStart = true
                let newPosition = max(0, min(value.location.x, endPosition(in: geometry.size.width) - handleWidth))
                let newStartTime = (newPosition / geometry.size.width) * totalTime
                trimStartTime = max(0, min(newStartTime, trimEndTime - 1))
            }
            .onEnded { _ in
                isDraggingStart = false
            }
    }
    
    private func endTrimGesture(geometry: GeometryProxy) -> some Gesture {
        DragGesture()
            .onChanged { value in
                isDraggingEnd = true
                let newPosition = max(startPosition(in: geometry.size.width) + handleWidth, min(value.location.x, geometry.size.width))
                let newEndTime = (newPosition / geometry.size.width) * totalTime
                trimEndTime = max(trimStartTime + 1, min(newEndTime, totalTime))
            }
            .onEnded { _ in
                isDraggingEnd = false
            }
    }
    
    private func seekerGesture(geometry: GeometryProxy) -> some Gesture {
        DragGesture()
            .onChanged { value in
                isDraggingSeeker = true
                let newTime = (value.location.x / geometry.size.width) * totalTime
                currentTime = max(0, min(totalTime, newTime))
            }
            .onEnded { _ in
                isDraggingSeeker = false
            }
    }
    
    private func startPosition(in width: CGFloat) -> CGFloat {
        return (trimStartTime / totalTime) * width
    }
    
    private func endPosition(in width: CGFloat) -> CGFloat {
        return (trimEndTime / totalTime) * width
    }
    
    private func currentTimePosition(in width: CGFloat) -> CGFloat {
        return (currentTime / totalTime) * width
    }
    
    private func selectedWidth(in width: CGFloat) -> CGFloat {
        return endPosition(in: width) - startPosition(in: width)
    }
    
    private func endOverlayWidth(in width: CGFloat) -> CGFloat {
        return width - endPosition(in: width)
    }
    
    private func generateTimelineThumbnails(for width: CGFloat) {
        let optimalCount = calculateOptimalThumbnailCount(for: width)
        
        if let asset = mergedAsset {
            generateThumbnailsFromAsset(asset, count: optimalCount)
        } else {
            generateThumbnailsFromMediaItems(count: optimalCount)
        }
    }
    
    private func generateThumbnailsFromAsset(_ asset: AVAsset, count: Int) {
        guard count > 0 else {
            DispatchQueue.main.async {
                self.timelineThumbnails = []
            }
            return
        }
        
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 100, height: 100)
        
        let duration = asset.duration
        let durationSeconds = CMTimeGetSeconds(duration)
        let timeInterval = durationSeconds / Double(count)
        
        var thumbnails: [UIImage] = []
        
        for i in 0..<count {
            let time = CMTime(seconds: Double(i) * timeInterval, preferredTimescale: 600)
            
            do {
                let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
                let thumbnail = UIImage(cgImage: cgImage)
                thumbnails.append(thumbnail)
            } catch {
                print("Error generating thumbnail: \(error)")
                thumbnails.append(createPlaceholderThumbnail())
            }
        }
        
        DispatchQueue.main.async {
            self.timelineThumbnails = thumbnails
        }
    }
    
    private func generateThumbnailsFromMediaItems(count: Int) {
        let sortedItems = sortedMediaItems
        
        guard !sortedItems.isEmpty && count > 0 else {
            DispatchQueue.main.async {
                self.timelineThumbnails = []
            }
            return
        }
        
        var allThumbnails: [UIImage] = []
        let thumbnailsPerItem = max(1, count / sortedItems.count)
        var remainingThumbnails = count
        
        var completedItems = 0
        for (index, mediaItem) in sortedItems.enumerated() {
            let itemThumbnailCount = min(thumbnailsPerItem, remainingThumbnails)
            remainingThumbnails -= itemThumbnailCount
            
            switch mediaItem {
            case .video(let videoItem):
                generateVideoThumbnails(for: videoItem, count: itemThumbnailCount) { videoThumbnails in
                    allThumbnails.append(contentsOf: videoThumbnails)
                    completedItems += 1
                    
                    if completedItems == sortedItems.count {
                        DispatchQueue.main.async {
                            self.timelineThumbnails = Array(allThumbnails.prefix(count))
                        }
                    }
                }
                
            case .photo(let photoItem):
                for _ in 0..<itemThumbnailCount {
                    if let photoThumbnail = photoItem.thumbnail {
                        allThumbnails.append(photoThumbnail)
                    } else {
                        allThumbnails.append(createPlaceholderThumbnail())
                    }
                }
                completedItems += 1
                
                if completedItems == sortedItems.count {
                    DispatchQueue.main.async {
                        self.timelineThumbnails = Array(allThumbnails.prefix(count))
                    }
                }
            }
        }
    }
    
    private func generateVideoThumbnails(for video: VideoItem, count: Int, completion: @escaping ([UIImage]) -> Void) {
        let imageManager = PHImageManager.default()
        let requestOptions = PHVideoRequestOptions()
        requestOptions.deliveryMode = .automatic
        
        imageManager.requestAVAsset(forVideo: video.asset, options: requestOptions) { avAsset, _, _ in
            guard let avAsset = avAsset else {
                completion(Array(repeating: createPlaceholderThumbnail(), count: count))
                return
            }
            
            let generator = AVAssetImageGenerator(asset: avAsset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 100, height: 100)
            
            let duration = avAsset.duration
            let durationSeconds = CMTimeGetSeconds(duration)
            let timeInterval = count > 1 ? durationSeconds / Double(count - 1) : 0
            
            var thumbnails: [UIImage] = []
            
            for i in 0..<count {
                let time = CMTime(seconds: Double(i) * timeInterval, preferredTimescale: 600)
                
                do {
                    let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
                    let thumbnail = UIImage(cgImage: cgImage)
                    thumbnails.append(thumbnail)
                } catch {
                    print("Error generating video thumbnail: \(error)")
                    thumbnails.append(createPlaceholderThumbnail())
                }
            }
            
            completion(thumbnails)
        }
    }
    
    private func createPlaceholderThumbnail() -> UIImage {
        let size = CGSize(width: 100, height: 100)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            let cgContext = context.cgContext
            
            UIColor.gray.withAlphaComponent(0.3).setFill()
            cgContext.fill(CGRect(origin: .zero, size: size))
            
            let iconSize: CGFloat = 30
            let iconRect = CGRect(
                x: (size.width - iconSize) / 2,
                y: (size.height - iconSize) / 2,
                width: iconSize,
                height: iconSize
            )
            
            UIColor.white.withAlphaComponent(0.6).setFill()
            cgContext.fillEllipse(in: iconRect)
        }
    }
}

extension UIImage {
    func resized(to size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
