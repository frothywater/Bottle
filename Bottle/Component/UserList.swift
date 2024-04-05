//
//  UserList.swift
//  Bottle
//
//  Created by Cobalt on 10/26/23.
//

import NukeUI
import SwiftUI

struct UserList<VM: UserProvider & ContentLoader & ObservableObject>: View {
    @Binding var selection: User.ID?
    @StateObject var model: VM

    var body: some View {
        List(selection: $selection) {
            if model.startedLoading {
                ForEach(Array(model.userIDs.enumerated()), id: \.element) { index, userID in
                    if let (user, mediaImages) = model.entities(for: userID) {
                        UserRecentRow(user: user, mediaImages: mediaImages)
                            .task {
                                if index == model.userIDs.count - 1 { await model.load() }
                            }
                    }
                }
            } else {
                Color.clear.task { await model.load() }
            }
        }
        .listStyle(.plain)
        .contentMargins(.bottom, 30)
        .scrollContentBackground(.hidden)
        .overlay(alignment: .bottom) { StatusBar(message: model.message) }
        #if os(iOS)
            .toolbar(.hidden)
        #endif
    }
}

@MainActor
private struct UserRecentRow: View {
    let user: User
    let mediaImages: [(Media, LibraryImage?)]

    var body: some View {
        VStack(alignment: .leading) {
            profile
            recent
        }
        .padding([.top, .bottom], 5)
        .fixVerticalScrolling()
        .contextMenu { contextMenu }
    }

    var profile: some View {
        HStack(spacing: 10) {
            Group {
                LazyImage(request: user.avatarUrl?.imageRequest) { state in
                    if let image = state.image {
                        image.resizable().scaledToFit()
                    } else if state.error != nil {
                        Image(systemName: "person")
                    }
                }
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
            .overlay { Circle().stroke(.separator) }

            VStack(alignment: .leading) {
                Text(user.name ?? "No name").font(.title3)
                if let username = user.username {
                    Text("@" + username).font(.caption2)
                }
            }
            .badge(user.postCount ?? 0)
        }
    }

    var recent: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 5) {
                ForEach(mediaImages, id: \.0.id) { media, image in
                    recentImage(media: media, image: image)
                }
            }
        }
    }

    @ViewBuilder
    func recentImage(media: Media, image: LibraryImage?) -> some View {
        let url = image?.localSmallThumbnailURL ?? image?.localThumbnailURL ?? media.thumbnailUrl
        LazyImage(request: url?.imageRequest) { state in
            if let image = state.image {
                image.resizable().scaledToFit()
            } else if state.error != nil {
                Color.clear.overlay { Image(systemName: "photo") }
            } else {
                Color.clear
            }
        }
        .fit(width: media.width, height: media.height)
        .frame(height: 100)
        .cornerRadius(5)
        .overlay { RoundedRectangle(cornerRadius: 5).stroke(.separator) }
    }

    @ViewBuilder
    var contextMenu: some View {
        if let params = user.feedParams {
            NavigationLink {
                MediaGrid(model: IndefiniteMediaViewModel { offset in
                    let request = EndpointRequest(params: params, offset: offset)
                    return try await fetchTemporaryFeed(community: user.community, request: request)
                })
                .id(MediaGridID.temporaryUser(user.id))
                .navigationTitle("Posts by \(user.name ?? user.userId) at \(user.community.capitalized)")
            } label: {
                Label("Browse \(user.name ?? user.userId) at \(user.community.capitalized)", systemImage: "global")
            }
        }
    }
}

// MARK: - ID

enum UserListID: Hashable {
    case library(String)
    case feed(Feed.ID)
}
