//
//  GroupedUserView.swift
//  Bottle
//
//  Created by Cobalt on 10/26/23.
//

import NukeUI
import SwiftUI

struct UserList: View {
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
                    .fixVerticalScrolling()
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
        .listStyle(.plain)
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
                    ForEach(item.posts.compactMap(\.media).flatMap { $0 }) { media in
                        LazyImage(request: media.localThumbnailURL?.imageRequest) { state in
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
                }
            }
        }
    }
}
