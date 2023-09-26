//
//  FeedView.swift
//  Bottle
//
//  Created by Cobalt on 9/9/23.
//

import NukeUI
import SwiftUI

struct FeedView: View {
    let feed: Feed

    @State private var showingUsers = false

    var body: some View {
        Group {
            if showingUsers {
                UserPostView(feed: feed)
            } else {
                PostGrid(id: feed.id) { page in
                    let result = try await fetchPosts(community: feed.community, feedID: feed.feedId, page: page)
                    return result.asPostMedia
                }
            }
        }
        .toolbar { toolbar }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Toggle(isOn: $showingUsers) {
                Label("Show users", systemImage: "person.2")
            }
            .toggleStyle(.button)
        }
    }
}

private struct PostGrid: View {
    let id: String
    let loadAction: (_ page: Int) async throws -> Pagination<PostMedia>

    @State private var loading = false
    @State private var statusMessage = ""
    @State private var columnCount = 3.0

    private var columns: [GridItem] { Array(repeating: GridItem(.flexible()), count: lround(columnCount)) }

    var body: some View {
        ScrollView {
            VStack {
                LazyVGrid(columns: columns, spacing: 10) {
                    InfiniteScroll(id: id) { media in
                        MediaView(media: media)
                    } loadAction: { page in
                        try await loadAction(page)
                    } onChanged: { loading, _, page, totalPages, totalItems in
                        self.loading = loading
                        if let totalPages = totalPages, let totalItems = totalItems {
                            statusMessage = "\(page)/\(totalPages) pages, \(totalItems) posts in total"
                        }
                    }
                }
                if loading {
                    ProgressView()
                }
            }
            .padding()
        }
        .overlay(alignment: .bottom) {
            StatusBar(message: statusMessage, columnCount: $columnCount)
        }
    }
}

private struct UserPostView: View {
    let feed: Feed
    @State private var selection: UserWithRecent?

    var body: some View {
        HSplitView {
            UserList(feed: feed, selection: $selection)
                .frame(minWidth: 300, idealWidth: 300, maxWidth: 600)
            Group {
                if let userID = selection?.user.userId {
                    PostGrid(id: userID) { page in
                        let result = try await fetchUserPosts(community: feed.community, feedID: feed.feedId, userID: userID, page: page)
                        return result.asPostMedia
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
    let feed: Feed
    @Binding var selection: UserWithRecent?
    
    @State private var selectedID: String?
    @State private var loading = false
    @State private var items = [UserWithRecent]()
    @State private var statusMessage = ""

    var body: some View {
        List(selection: $selectedID) {
            InfiniteScroll(id: feed.id + "users") { item in
                UserRecentRow(item: item)
                    .padding([.top, .bottom], 5)
            } loadAction: { page in
                try await fetchUsers(community: feed.community, feedID: feed.feedId, page: page)
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
                    if let avatarURL = item.user.avatarUrl {
                        LazyImage(url: URL(string: avatarURL)) { state in
                            if let image = state.image {
                                image.resizable().scaledToFit()
                            } else if state.error != nil {
                                Image(systemName: "person")
                            }
                        }
                    } else {
                        Image(systemName: "person")
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
                        LazyImage(request: media.thumbnailRequest) { state in
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

struct FeedView_Previews: PreviewProvider {
    static var previews: some View {
        FeedView(feed: Feed(feedId: 1, community: "twitter", name: "Likes"))
            .frame(minWidth: 800)
    }
}
