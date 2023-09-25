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

    @State private var loading = false
    @State private var statusMessage = ""
    @State private var showingUsers = false
    @State private var columnCount = 3.0

    private var columns: [GridItem] { Array(repeating: GridItem(.flexible()), count: lround(columnCount)) }

    var body: some View {
        ScrollView {
            VStack {
                LazyVGrid(columns: columns, spacing: 15) {
                    InfiniteScroll(id: feed.id) { media in
                        MediaView(media: media)
                    } loadAction: { page -> Pagination<PostMedia> in
                        let result = try await fetchPosts(community: feed.community, feedID: feed.feedId, page: page)
                        return result.asPostMedia
                    } onChanged: { loading, page, totalPages, totalItems in
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
        .toolbar { toolbar }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            Toggle(isOn: $showingUsers) {
                Label("Show users", systemImage: "people.2")
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
