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

    @State private var posts = [Post]()
    @State private var page = 0
    @State private var totalPages: Int?
    @State private var totalPosts: Int?
    @State private var loading = false
    @State private var columnCount = 3.0

    private var columns: [GridItem] { Array(repeating: GridItem(.flexible()), count: lround(columnCount)) }

    var body: some View {
        ScrollView {
            VStack {
                LazyVGrid(columns: columns, spacing: 15) {
                    ForEach(Array(zip(posts, posts.indices)), id: \.0.id) { post, postIndex in
                        ForEach(Array(zip(post.media, post.media.indices)), id: \.0.id) { media, mediaIndex in
                            MediaView(media: media, postID: post.postId, page: mediaIndex)
                                .task {
                                    if postIndex == indexOfLastNotEmptyPost && mediaIndex == post.media.endIndex - 1 {
                                        await load()
                                    }
                                }
                        }
                    }
                }
                if loading {
                    ProgressView()
                }
            }
            .padding()
            .task(id: feed.id) {
                reset()
                await load()
            }
        }
        .overlay(alignment: .bottom) {
            if let totalPages = totalPages, let totalPosts = totalPosts {
                ZStack {
                    Text("\(page)/\(totalPages) pages, \(totalPosts) posts in total")
                        .font(.caption).foregroundColor(.secondary)
                    Slider(value: $columnCount, in: 1 ... 10, step: 1)
                        .controlSize(.small)
                        .frame(width: 120)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding([.top, .bottom], 5)
                .padding([.leading, .trailing], 15)
                .background { Rectangle().fill(.thickMaterial) }
                .overlay(alignment: .top) { Divider() }
            }
        }
    }

    private var finishedLoading: Bool {
        if let totalPages = totalPages, page == totalPages { return true }
        return false
    }

    private var indexOfLastNotEmptyPost: Int {
        posts.lastIndex { !$0.media.isEmpty } ?? 0
    }

    private func reset() {
        posts.removeAll()
        page = 0
        totalPages = nil
        totalPosts = nil
        loading = false
    }

    private func load() async {
        if finishedLoading { return }
        defer { loading = false }
        do {
            loading = true
            let result = try await fetchPosts(community: feed.community, feedID: feed.feedId, page: page)

            posts.append(contentsOf: result.items)
            page += 1
            totalPages = result.totalPages
            totalPosts = result.totalItems
        } catch {
            print(error)
        }
    }
}

struct FeedView_Previews: PreviewProvider {
    static var previews: some View {
        FeedView(feed: Feed(feedId: 1, community: "twitter", name: "Likes"))
            .frame(minWidth: 800)
    }
}
