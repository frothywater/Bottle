//
//  GroupedUserView.swift
//  Bottle
//
//  Created by Cobalt on 10/26/23.
//

import NukeUI
import SwiftUI

struct GroupedUserPostView<Media: Identifiable & Decodable, Content: View>: View {
    let id: String
    @ViewBuilder let content: (_ media: Media) -> Content
    let loadUsers: (_ page: Int) async throws -> Pagination<UserWithRecent>
    let loadMedia: (_ userID: String, _ page: Int) async throws -> Pagination<Media>
    @State private var selection: UserWithRecent?

    var body: some View {
        HSplitView {
            UserList(id: id, selection: $selection) { page in
                try await loadUsers(page)
            }
            .frame(minWidth: 300, idealWidth: 300, maxWidth: 600)
            Group {
                if let userID = selection?.user.userId {
                    PostGrid(id: id + userID) { media in
                        content(media)
                    } loadMedia: { page in
                        try await loadMedia(userID, page)
                    }
                } else {
                    Text("Select a artist")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .layoutPriority(1)
        }
    }
}

private struct UserList: View {
    let id: String
    @Binding var selection: UserWithRecent?
    let loadUsers: (_ page: Int) async throws -> Pagination<UserWithRecent>

    @State private var selectedID: String?
    @State private var loading = false
    @State private var items = [UserWithRecent]()
    @State private var statusMessage = ""

    var body: some View {
        List(selection: $selectedID) {
            InfiniteScroll(id: id) { item in
                UserRecentRow(item: item)
                    .padding([.top, .bottom], 5)
            } loadAction: { page in
                try await loadUsers(page)
            } onChanged: { loading, items, page, totalPages, totalItems in
                self.loading = loading
                self.items = items
                if let totalPages = totalPages, let totalItems = totalItems {
                    statusMessage = "\(page)/\(totalPages) pages, \(totalItems) users in total"
                }
            }
        }
        .scrollContentBackground(.hidden)
        .overlay(alignment: .bottom) {
            StatusBar(message: statusMessage)
        }
        .onChange(of: selectedID) { id in
            selection = items.first { $0.id == id }
        }
    }
}

private struct UserRecentRow: View {
    let item: UserWithRecent

    var body: some View {
        VStack(alignment: .leading) {
            HStack(spacing: 10) {
                Group {
                    LazyImage(request: item.user.avatarUrl?.imageRequest) { state in
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
                    Text(item.user.name ?? "No name").font(.title3)
                    if let username = item.user.username {
                        Text("@" + username).font(.caption2)
                    }
                }
                .badge(item.totalPosts)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 5) {
                    ForEach(item.posts.flatMap(\.media)) { media in
                        LazyImage(request: media.localThumbnailURL?.imageRequest) { state in
                            if let image = state.image {
                                image.resizable().scaledToFit()
                            } else if state.error != nil {
                                Color.clear.overlay { Image(systemName: "photo") }
                            } else {
                                Color.clear
                            }
                        }
                        .aspectRatio(CGSize(width: media.width, height: media.height), contentMode: .fit)
                        .frame(height: 100)
                        .cornerRadius(5)
                        .overlay { RoundedRectangle(cornerRadius: 5).stroke(.separator) }
                    }
                }
            }
        }
    }
}
