//
//  MediaView.swift
//  Bottle
//
//  Created by Cobalt on 9/13/23.
//

import NukeUI
import SwiftUI

@MainActor
struct MediaView: View {
    let mediaID: Media.ID
    let model: MediaProvider
    let user: User?
    let post: Post?
    let media: Media
    let work: Work?
    let image: LibraryImage?

    var thumbnailURL: String? { if image?.localThumbnailURL != nil { image?.localThumbnailURL } else { media.thumbnailUrl } }

    var body: some View {
        NavigationLink {
            ImageSheet(user: user, post: post, media: media, work: work, image: image)
        } label: {
            content
        }
        .buttonStyle(.plain)
        .overlay { RoundedRectangle(cornerRadius: 10).stroke(.separator) }
        .overlay(alignment: .topTrailing) {
            ImportButton(media: media, work: work, model: model)
        }
    }
    
    var tempContent: String {
        if let link = mediaLink(media: media, post: post, user: user), let thumbnailURL = media.thumbnailUrl {
            return "\n\(link)\n\(thumbnailURL)\n"
        } else {
            return ""
        }
    }

    var content: some View {
        LazyImage(request: thumbnailURL?.imageRequest) { state in
            if let image = state.image {
                image.resizable().scaledToFit()
                    .draggable(tempContent)
            } else if state.error != nil {
                Color.clear.overlay { Image(systemName: "photo") }
            } else {
                Color.clear
            }
        }
        .fit(width: media.width, height: media.height)
        .contentShape(Rectangle())
        .cornerRadius(10)
    }
}

private struct ImageSheet: View {
    let user: User?
    let post: Post?
    let media: Media
    let work: Work?
    let image: LibraryImage?
    
    @State private var showingInspector = false
    @Environment(\.dismiss) private var dismiss
    
    var url: String? { if image?.localURL != nil { image?.localURL } else { media.url } }

    var body: some View {
        LazyImage(request: url?.imageRequest) { state in
            if let image = state.image {
                image.resizable().scaledToFit()
                    .zoomable()
            } else if state.error != nil {
                Image(systemName: "photo")
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { dismiss() }
        .toolbar { toolbar }
        .inspector(isPresented: $showingInspector) { inspectorPanel }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
    
    @ToolbarContentBuilder
    var toolbar: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            Button {
                showingInspector.toggle()
            } label: {
                Label("Show Info", systemImage: "info.circle")
            }
        }
    }
    
    var inspectorPanel: some View {
        List {
            Section("Media") {
                LabeledContent("Media ID", value: media.mediaId)
                if let link = mediaLink(media: media, post: post, user: user) { LabeledContent("Link", value: link) }
                if let url = media.url { LabeledContent("URL", value: url) }
                if let url = media.thumbnailUrl { LabeledContent("Thumbnail URL", value: url) }
                LabeledContent("Page", value: media.pageIndex.formatted())
            }
            
            if let post = post {
                Section("Post") {
                    LabeledContent("Post ID", value: post.postId)
                    LabeledContent("Created date", value: post.createdDate.formatted())
                    LabeledContent("Community", value: post.community.capitalized)
                    LabeledContent("Text", value: post.text)
                }
            }
            
            if let user = user {
                Section("User") {
                    LabeledContent("User ID", value: user.userId)
                    if let link = userLink(user: user) { LabeledContent("Link", value: link) }
                    if let name = user.name { LabeledContent("Name", value: name) }
                    if let username = user.username { LabeledContent("Username", value: username) }
                    if let description = user.description { LabeledContent("Description", value: description) }
                    if let url = user.url { LabeledContent("URL", value: url) }
                }
            }
            
            if let work = work {
                Section("Work") {
                    LabeledContent("Work ID", value: work.id.formatted())
                    LabeledContent("Added date", value: work.addedDate.formatted())
                    LabeledContent("Favorite", value: work.favorite.description)
                    LabeledContent("Rating", value: work.rating.formatted())
                }
            }
            
            if let image = image {
                Section("Image") {
                    LabeledContent("Image ID", value: image.id.formatted())
                    LabeledContent("Filename", value: image.filename)
                    if let path = image.path { LabeledContent("Path", value: path) }
                    if let path = image.thumbnailPath { LabeledContent("Thumbnail path", value: path) }
                    if let path = image.smallThumbnailPath { LabeledContent("Small thumbnail path", value: path) }
                    if let width = image.width, let height = image.height { LabeledContent("Dimension", value: "\(width)×\(height)") }
                    if let size = image.size { LabeledContent("File Size", value: size.formatted()) }
                }
            }
        }
        .listStyle(.inset)
        .textSelection(.enabled)
    }
}

private struct ImportButton: View {
    let media: Media
    let work: Work?
    let model: MediaProvider
    @State var operating = false

    private var imported: Bool { work != nil }
    private var symbol: String { imported ? "bookmark.fill" : "bookmark" }

    var body: some View {
        Button(action: toggle) {
            Circle().fill(.thinMaterial)
                .overlay {
                    if operating {
                        ProgressView().scaleEffect(0.5)
                    } else {
                        Image(systemName: symbol)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.orange)
                    }
                }
        }
        .buttonStyle(.plain)
        .frame(width: 32, height: 32)
        .padding(5)
        .animation(.default, value: imported)
        .animation(.default, value: operating)
        .disabled(operating)
    }

    private func toggle() {
        guard !operating else { return }
        Task {
            defer { operating = false }
            operating = true
            do {
                if imported {
                    guard let workID = work?.id else { return }
                    try await deleteWork(workID: workID)
                    model.deleteWork(workID, for: media.id)
                } else {
                    let response = try await addWork(community: media.community, postID: media.postId, page: media.pageIndex)
                    model.updateEntities(response)
                    model.updateMedia(response)
                }
            } catch {
                print(error)
            }
        }
    }
}

private func mediaLink(media: Media, post: Post?, user: User?) -> String? {
    guard let post = post else { return nil }
    switch post.community {
    case "twitter":
        guard let user = user, let username = user.username else { return nil }
        return "https://twitter.com/\(username)/status/\(post.postId)/photo/\(media.pageIndex + 1)"
    case "pixiv":
        return "https://www.pixiv.net/artworks/\(post.postId)"
    case "yandere":
        return "https://yande.re/post/show/\(post.postId)"
    default:
        return nil
    }
}

private func userLink(user: User?) -> String? {
    guard let user = user else { return nil }
    switch user.community {
    case "twitter":
        guard let username = user.username else { return nil }
        return "https://twitter.com/\(username)"
    case "pixiv":
        return "https://www.pixiv.net/users/\(user.userId)"
    default:
        return nil
    }
}
