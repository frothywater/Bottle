//
//  ContentView.swift
//  Bottle
//
//  Created by Cobalt on 9/8/23.
//

import Nuke
import SwiftUI

struct ContentView: View {
    @Environment(\.appModel) var appModel

    @State private var destinationSelection: SidebarDestination?
    @State private var userSelection: User.ID?
    @State private var showingSetting = false
    @State private var showingJobs = false
    @State private var showingGroupedUser = false

    @State private var expandedLibraryCommunity = true

    @AppStorage("safeMode") private var safeMode: Bool = true

    var body: some View {
        Group {
            if showingGroupedUser {
                // Show 3-column layout when showing grouped users.
                NavigationSplitView {
                    sidebar
                } content: {
                    destination(for: destinationSelection)
                } detail: {
                    NavigationStack {
                        thirdDestination(for: destinationSelection)
                    }
                }
            } else {
                // Show 2-column layout otherwise.
                NavigationSplitView {
                    sidebar
                } detail: {
                    NavigationStack {
                        destination(for: destinationSelection)
                    }
                }
            }
        }
    }

    private var sidebar: some View {
        List(selection: $destinationSelection) {
            librarySection
            feedSection
        }
        .navigationTitle("Bottle")
        .toolbar { toolbar }
        .sheet(isPresented: $showingSetting) {
            Settings()
                .onSubmit {
                    // Register URLSession for Nuke again, since proxy may changed
                    ImagePipeline.shared = makeDefaultImagePipeline()
                    setPandaCookies()
                    
                    Task { await appModel.fetchAll() }
                    showingSetting = false
                }
        }
        .sheet(isPresented: $showingJobs) {
            JobsView()
        }
    }

    private var librarySection: some View {
        Section("Library") {
            libraryTreeSection

            DisclosureGroup(isExpanded: $expandedLibraryCommunity) {
                ForEach(appModel.metadata?.communities ?? [], id: \.destination) { community in
                    // Click each community in the library to view all posts in that community.
                    // Always show grouped user view.
                    if !safeMode || community.name.isSafeCommunity {
                        Label(community.name.capitalized, systemImage: "square.stack")
                            .foregroundColor(.primary)
                    }
                }
            } label: {
                Label("Community", systemImage: "globe")
            }
        }
    }

    @ViewBuilder
    private var libraryTreeSection: some View {
        if let libraryTree = appModel.libraryTree {
            OutlineGroup(libraryTree, children: \.children) { entry in
                LibraryTreeRow(entry: entry)
            }
        }
    }

    private var feedSection: some View {
        Section("Feeds") {
            ForEach(appModel.communityFeeds, id: \.0) { community, feeds in
                if !safeMode || community.isSafeCommunity {
                    FeedDisclosureGroup(feeds: feeds, community: community)
                }
            }
        }
    }

    @ViewBuilder
    private func destination(for selection: SidebarDestination?) -> some View {
        if case .community(let community) = selection {
            if showingGroupedUser {
                libraryUserList(community: community, selection: $userSelection)
            } else {
                libraryView(community: community)
            }
        } else if case .feed = selection,
            let feed = appModel.feeds.first(where: { $0.destination == selection! })
        {
            if showingGroupedUser {
                feedUserList(feed: feed, selection: $userSelection)
            } else {
                feedView(feed: feed)
            }
        } else if case .album(let id) = selection {
            albumView(id: id)
        } else if case .folder(let id) = selection {
            folderView(id: id)
        } else {
            if showingGroupedUser {
                Text("Select a community")
            } else {
                Text("Select a feed")
            }
        }
    }

    @ViewBuilder
    private func thirdDestination(for selection: SidebarDestination?) -> some View {
        if case .community(let community) = selection {
            libraryUserView(community: community, selection: userSelection)
        } else if case .feed = selection,
            let feed = appModel.feeds.first(where: { $0.destination == selection! })
        {
            feedUserView(feed: feed, selection: userSelection)
        } else {
            Text("Select a user")
        }
    }

    private func libraryView(community: String) -> some View {
        Group {
            if community == "panda" {
                PostGrid(
                    model: PaginatedPostViewModel(orderByWork: true) { page in
                        try await Client.fetchCommunityWorks(community: community, page: page)
                    }
                )
                .id(PostGridID.library(community))
            } else {
                MediaGrid(
                    model: PaginatedMediaViewModel(orderByWork: true) { page in
                        try await Client.fetchCommunityWorks(community: community, page: page)
                    }
                )
                .id(MediaGridID.library(community))
            }
        }
        .navigationTitle("\(community.capitalized) Works in Library")
    }

    private func libraryUserList(community: String, selection: Binding<User.ID?>) -> some View {
        UserList(
            selection: selection,
            model: PaginatedUserViewModel { page in
                try await Client.fetchArchivedUsers(community: community, page: page)
            }
        )
        .id(UserListID.library(community))
        .navigationTitle("\(community.capitalized) Artists in Library")
    }

    @ViewBuilder
    private func libraryUserView(community: String, selection: User.ID?) -> some View {
        if let userID = selection {
            Group {
                if community == "panda" {
                    PostGrid(
                        model: PaginatedPostViewModel { page in
                            try await Client.fetchArchivedUserPosts(
                                community: community, userID: userID.userId, page: page)
                        }
                    )
                    .id(PostGridID.libraryByUser(userID))
                } else {
                    MediaGrid(
                        model: PaginatedMediaViewModel { page in
                            try await Client.fetchArchivedUserPosts(
                                community: community, userID: userID.userId, page: page)
                        }
                    )
                    .id(MediaGridID.libraryByUser(userID))
                }
            }
            .navigationTitle("\(community.capitalized) Works by Artist in Library")
        }
    }

    private func feedView(feed: Feed) -> some View {
        Group {
            if feed.community == "panda" {
                PostGrid(
                    model: PaginatedPostViewModel { page in
                        try await Client.fetchPosts(community: feed.community, feedID: feed.feedId, page: page)
                    }
                )
                .id(PostGridID.feed(feed.id))
            } else {
                MediaGrid(
                    model: PaginatedMediaViewModel { page in
                        try await Client.fetchPosts(community: feed.community, feedID: feed.feedId, page: page)
                    }
                )
                .id(MediaGridID.feed(feed.id))
            }
        }
        .navigationTitle("\(feed.community.capitalized) Feed \(feed.displayName)")
    }

    private func feedUserList(feed: Feed, selection: Binding<User.ID?>) -> some View {
        UserList(
            selection: selection,
            model: PaginatedUserViewModel { page in
                try await Client.fetchFeedUsers(community: feed.community, feedID: feed.feedId, page: page)
            }
        )
        .id(UserListID.feed(feed.id))
        .navigationTitle("\(feed.community.capitalized) Artists in Feed \(feed.displayName)")
    }

    @ViewBuilder
    private func feedUserView(feed: Feed, selection: User.ID?) -> some View {
        if let userID = selection {
            Group {
                if feed.community == "panda" {
                    PostGrid(
                        model: PaginatedPostViewModel { page in
                            try await Client.fetchFeedUserPosts(
                                community: feed.community, feedID: feed.feedId, userID: userID.userId, page: page)
                        }
                    )
                    .id(PostGridID.feedByUser(feed.id, userID))
                } else {
                    MediaGrid(
                        model: PaginatedMediaViewModel { page in
                            try await Client.fetchFeedUserPosts(
                                community: feed.community, feedID: feed.feedId, userID: userID.userId, page: page)
                        }
                    )
                    .id(MediaGridID.feedByUser(feed.id, userID))
                }
            }
            .navigationTitle("\(feed.community.capitalized) Posts by Artist in Feed \(feed.displayName)")
        }
    }

    @ViewBuilder
    private func albumView(id: Album.ID) -> some View {
        MediaGrid(
            model: PaginatedMediaViewModel(orderByWork: true) { page in
                try await Client.fetchWorks(albumId: id, page: page)
            }
        )
        .id(MediaGridID.album(id))
        .environment(\.albumID, id)
    }

    @ViewBuilder
    private func folderView(id: Folder.ID) -> some View {
        if let folder = appModel.folder(id) {
            Text("Folder \(folder.name)")
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Toggle(isOn: $showingGroupedUser) {
                Label("Show users", systemImage: "person.2")
            }
            .toggleStyle(.button)
        }
        ToolbarItem(placement: .primaryAction) {
            Button {
                showingJobs = true
            } label: {
                Label("Jobs", systemImage: "arrow.clockwise")
            }
        }
        ToolbarItem(placement: .secondaryAction) {
            Button {
                showingSetting = true
            } label: {
                Label("Menu", systemImage: "ellipsis.circle")
            }
        }
    }

    private func setPandaCookies() {
        guard let ipbMemberID = UserDefaults.standard.string(forKey: "pandaMemberID"),
            let ipbPassHash = UserDefaults.standard.string(forKey: "pandaPassHash"),
            let igneous = UserDefaults.standard.string(forKey: "pandaIgneous")
        else { return }
        let cookies = Client.pandaCookies(ipbMemberID: ipbMemberID, ipbPassHash: ipbPassHash, igneous: igneous)
        cookies.forEach { HTTPCookieStorage.shared.setCookie($0) }
        print("Panda cookies set. \(cookies)")
    }
}

// MARK: - Components

struct FeedDisclosureGroup: View {
    let feeds: [Feed]
    let community: String
    @State private var expanded = true

    @AppStorage("safeMode") private var safeMode: Bool = true

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            ForEach(feeds, id: \.destination) { feed in
                // Click each feed to view all posts in that feed.
                // Grouped view available.
                if !safeMode || feed.displayName.isSafeFeed {
                    Label(feed.displayName, systemImage: "doc.text.image")
                        .foregroundColor(.primary)
                }
            }
        } label: {
            Label(community.capitalized, systemImage: "person.2")
        }
    }
}

// MARK: - Global Destinations

@ViewBuilder
func userInCommunityDestination(user: User) -> some View {
    let community = user.community
    if let params = user.feedParams {
        Group {
            if community == "panda" {
                PostGrid(
                    model: IndefinitePostViewModel { offset in
                        let request = EndpointRequest(params: params, offset: offset)
                        return try await Client.fetchTemporaryFeed(community: community, request: request)
                    }
                )
                .id(PostGridID.temporaryUser(user.id))

            } else {
                MediaGrid(
                    model: IndefiniteMediaViewModel { offset in
                        let request = EndpointRequest(params: params, offset: offset)
                        return try await Client.fetchTemporaryFeed(community: community, request: request)
                    }
                )
                .id(MediaGridID.temporaryUser(user.id))
            }
        }
        .navigationTitle("\(community.capitalized) Posts by \"\(user.name ?? user.userId)\"")
    }
}

@ViewBuilder
func userInLibraryDestination(user: User) -> some View {
    let community = user.community
    Group {
        if user.community == "panda" {
            PostGrid(
                model: PaginatedPostViewModel { page in
                    try await Client.fetchArchivedUserPosts(community: community, userID: user.userId, page: page)
                }
            )
            .id(PostGridID.libraryByUser(user.id))
        } else {
            MediaGrid(
                model: PaginatedMediaViewModel { page in
                    try await Client.fetchArchivedUserPosts(community: community, userID: user.userId, page: page)
                }
            )
            .id(MediaGridID.libraryByUser(user.id))
        }
    }
    .navigationTitle("\(community.capitalized) Works by \"\(user.name ?? user.userId)\" in Library")
}
