//
//  PostView.swift
//  Bottle
//
//  Created by Cobalt on 3/27/24.
//

import NukeUI
import SwiftUI

@MainActor
struct PostView: View {
    let postID: Post.ID
    let model: PostProvider
    let user: User?
    let post: Post
    let work: Work?
    let media: [Media]
    let images: [LibraryImage]

    private let mediaImagePairs: [(Media, LibraryImage?)]

    init(postID: Post.ID, model: PostProvider, user: User?, post: Post, work: Work?, media: [Media], images: [LibraryImage]) {
        self.postID = postID
        self.model = model
        self.user = user
        self.post = post
        self.work = work
        self.media = media
        self.images = images
        self.mediaImagePairs = media.map { m in (m, images.first(where: { $0.pageIndex == m.pageIndex })) }
    }

    var coverWidth: Int {
        guard let (media, image) = mediaImagePairs.first else { return 100 }
        return image?.width ?? media.width ?? 100
    }

    var coverHeight: Int {
        guard let (media, image) = mediaImagePairs.first else { return 100 }
        return image?.height ?? media.height ?? 100
    }

    var coverThumbnailURL: String? {
        guard let (_, image) = mediaImagePairs.first else { return nil }
        return image?.localThumbnailURL
    }

    var body: some View {
        NavigationLink {
            GalleryView(mediaImagePairs: mediaImagePairs)
        } label: {
            outer
        }
        .buttonStyle(.plain)
        .overlay { RoundedRectangle(cornerRadius: 10).stroke(.separator) }
//        .overlay(alignment: .topTrailing) {}
    }

    var outer: some View {
        LazyImage(request: coverThumbnailURL?.imageRequest) { state in
            if let image = state.image {
                image.resizable().scaledToFit()
                    .draggable(image)
            } else if state.error != nil {
                Color.clear.overlay { Image(systemName: "photo") }
            } else {
                Color.clear
            }
        }
        .fit(width: coverWidth, height: coverHeight)
        .contentShape(Rectangle())
        .cornerRadius(10)
    }
}

@MainActor
struct GalleryView: View {
    let mediaImagePairs: [(Media, LibraryImage?)]
    let direction: LayoutDirection = .rightToLeft
    @State private var index = 0
    @State private var showingBar = false
    
    var items: [(Media, LibraryImage?)] {
        switch direction {
        case .rightToLeft:
            mediaImagePairs.reversed()
        default:
            mediaImagePairs
        }
    }
    
    var body: some View {
        ZStack {
            #if os(iOS)
            TabView(selection: $index) {
                ForEach(items, id: \.0.pageIndex) { item in
                    imageView(item: item)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            #else
            imageView(item: mediaImagePairs.first(where: { $0.0.pageIndex == index })!)
            #endif
            
            tapDetection
        }
        .overlay(alignment: .bottom) { if showingBar { bar } }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
    
    var tapDetection: some View {
        GeometryReader { proxy in
            ZStack {
                HStack {
                    Color.clear
                        .frame(width: proxy.size.width / 2)
                        .contentShape(Rectangle())
                        .onTapGesture { if index < mediaImagePairs.endIndex - 1 { index += 1 } }
                    Color.clear
                        .frame(width: proxy.size.width / 2)
                        .contentShape(Rectangle())
                        .onTapGesture { if index > 0 { index -= 1 } }
                }
                Color.clear
                    .frame(width: proxy.size.width / 3, height: proxy.size.height / 3)
                    .contentShape(Rectangle())
                    .onTapGesture { showingBar.toggle() }
            }
        }
    }
    
    @ViewBuilder
    func imageView(item: (Media, LibraryImage?)) -> some View {
        let (media, image) = item
        let url = image?.localURL ?? image?.localThumbnailURL
        let width = image?.width ?? media.width ?? 100
        let height = image?.height ?? media.height ?? 100
        LazyImage(request: url?.imageRequest) { state in
            if let image = state.image {
                image.resizable().scaledToFit()
            } else if state.error != nil {
                Color.clear.overlay { Image(systemName: "photo") }
            } else {
                Color.clear.overlay { ProgressView() }
            }
        }
        .fit(width: width, height: height)
        #if os(iOS)
        .zoomable()
        #endif
    }
    
    var bar: some View {
        HStack(spacing: 20) {
            switch direction {
            case .rightToLeft:
                slider.flipped()
            default:
                slider
            }
            Text(String(index))
        }
        .padding(.horizontal, 15)
        .frame(height: 50)
        .background(.thinMaterial)
    }
    
    var slider: some View {
        Slider(value: .convert(from: $index), in: 0...(Float(mediaImagePairs.endIndex) - 1), step: 1)
    }
}
