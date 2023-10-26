//
//  FeedView.swift
//  Bottle
//
//  Created by Cobalt on 9/9/23.
//

import SwiftUI

struct FeedView: View {
    let feed: Feed

    @State private var showingUsers = false

    var body: some View {
        Group {
            if showingUsers {
                GroupedUserPostView(id: feed.id) { media in
                    MediaView(media: media)
                } loadUsers: { page in
                    try await fetchFeedUsers(community: feed.community, feedID: feed.feedId, page: page)
                } loadMedia: { userID, page in
                    let result = try await fetchFeedUserPosts(community: feed.community, feedID: feed.feedId, userID: userID, page: page)
                    return result.asPostMedia
                }
            } else {
                PostGrid(id: feed.id) { media in
                    MediaView(media: media)
                } loadMedia: { page in
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

struct FeedView_Previews: PreviewProvider {
    static var previews: some View {
        FeedView(feed: Feed(feedId: 1, community: "twitter", name: "Likes"))
            .frame(minWidth: 800)
    }
}
