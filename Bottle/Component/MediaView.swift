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
    let entities: MediaEntities
    let model: MediaProvider
    
    @State private var browsingUser: User?
    @State private var browsingLibraryUser = false
    @State private var browsingCommunityUser = false

    var thumbnailURL: String? {
        if entities.image?.localThumbnailURL != nil { entities.image?.localThumbnailURL } else { entities.media.thumbnailUrl }
    }

    var body: some View {
        NavigationLink {
            ImageSheet(entities: entities)
        } label: {
            content
        }
        .buttonStyle(.plain)
        .overlay { RoundedRectangle(cornerRadius: 10).stroke(.separator) }
        .overlay(alignment: .topTrailing) {
            ImportButton(media: entities.media, work: entities.work, model: model)
        }
        .contextMenu { contextMenu }
        .navigationDestination(isPresented: $browsingLibraryUser) {
            if let user = browsingUser {
                userInLibraryDestination(user: user)
            }
        }
        .navigationDestination(isPresented: $browsingCommunityUser) {
            if let user = browsingUser {
                userInCommunityDestination(user: user)
            }
        }
    }

    var content: some View {
        LazyImage(request: thumbnailURL?.imageRequest) { state in
            if let image = state.image {
                image.resizable().scaledToFit()
                    .draggable(image)
            } else if state.error != nil {
                Color.clear.overlay { Image(systemName: "photo") }
            } else {
                Color.clear
            }
        }
        .fit(width: entities.media.width, height: entities.media.height)
        .overlay(alignment: .bottom) { infoOverlay }
        .contentShape(Rectangle())
        .cornerRadius(10)
    }
    
    @ViewBuilder
    var infoOverlay: some View {
        let title = entities.post?.displayText
        let author = users.map { $0.name ?? $0.userId }.joined(separator: ", ")
        if (title != nil && !title!.isEmpty) || !author.isEmpty {
            VStack(alignment: .leading, spacing: 5) {
                if let title = title, !title.isEmpty {
                    Text(title).font(.headline)
                        .lineLimit(2, reservesSpace: false)
                        .multilineTextAlignment(.leading)
                }
                if !author.isEmpty {
                    Text(author).font(.subheadline)
                        .lineLimit(1)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
        }
    }
    
    var users: [User] {
        var result = [User]()
        if let user = entities.user { result.append(user) }
        if let users = entities.taggedUsers { result.append(contentsOf: users) }
        return result
    }
    
    @ViewBuilder
    var contextMenu: some View {
        let users = users
        if users.count == 1 {
            let user = users.first!
            Button("Browse \"\(user.name ?? user.userId)\" Works in Library", systemImage: "photo.on.rectangle") {
                browsingUser = user
                browsingLibraryUser = true
            }
            Button("Browse \"\(user.name ?? user.userId)\" Posts at \(user.community.capitalized)", systemImage: "globe") {
                browsingUser = user
                browsingCommunityUser = true
            }
        } else if users.count > 1 {
            Menu("Browse Artist Works in Library", systemImage: "photo.on.rectangle") {
                ForEach(users) { user in
                    Button(user.name ?? user.userId) {
                        browsingUser = user
                        browsingLibraryUser = true
                    }
                }
            }
            Menu("Browse Artist Posts at \(entities.media.community.capitalized)", systemImage: "globe") {
                ForEach(users) { user in
                    Button(user.name ?? user.userId) {
                        browsingUser = user
                        browsingCommunityUser = true
                    }
                }
            }
        }
    }
}

private struct ImageSheet: View {
    let entities: MediaEntities
    
    @State private var showingInspector = false
    @Environment(\.dismiss) private var dismiss
    
    var url: String? {
        if entities.image?.localURL != nil { entities.image?.localURL } else { entities.media.url }
    }

    var body: some View {
        LazyImage(request: url?.imageRequest) { state in
            if let image = state.image {
                image.resizable().scaledToFit()
                    .draggable(image)
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
                let media = entities.media
                LabeledContent("Media ID", value: media.mediaId)
                if let link = mediaLink(media: media, post: entities.post, user: entities.user) { LabeledContent("Link", value: link) }
                if let url = media.url { LabeledContent("URL", value: url) }
                if let url = media.thumbnailUrl { LabeledContent("Thumbnail URL", value: url) }
                LabeledContent("Page", value: media.pageIndex.formatted())
            }
            
            if let post = entities.post {
                Section("Post") {
                    LabeledContent("Post ID", value: post.postId)
                    LabeledContent("Created date", value: post.createdDate.formatted())
                    LabeledContent("Community", value: post.community.capitalized)
                    if !post.text.isEmpty { LabeledContent("Text", value: post.text) }
                    if let tags = post.tags, !tags.isEmpty { LabeledContent("Tags", value: tags.joined(separator: ", ")) }
                }
            }
            
            if let user = entities.user {
                Section("User") {
                    LabeledContent("User ID", value: user.userId)
                    if let link = userLink(user: user) { LabeledContent("Link", value: link) }
                    if let name = user.name, !name.isEmpty { LabeledContent("Name", value: name) }
                    if let username = user.username, !username.isEmpty { LabeledContent("Username", value: username) }
                    if let description = user.description, !description.isEmpty { LabeledContent("Description", value: description) }
                    if let url = user.url, !url.isEmpty { LabeledContent("URL", value: url) }
                }
            }
            
            if let work = entities.work {
                Section("Work") {
                    LabeledContent("Work ID", value: work.id.formatted())
                    LabeledContent("Added date", value: work.addedDate.formatted())
                    LabeledContent("Favorite", value: work.favorite.description)
                    LabeledContent("Rating", value: work.rating.formatted())
                }
            }
            
            if let image = entities.image {
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
        .multilineTextAlignment(.trailing)
    }
}

@MainActor
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
