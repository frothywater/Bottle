//
//  ContentView.swift
//  Bottle
//
//  Created by Cobalt on 9/8/23.
//

import SwiftUI

struct ContentView: View {
    @Binding var appState: AppState
    
    @AppStorage("serverAddress") var serverAddress: String = ""
    
    @State private var communityOrFeedSelection: String?
    @State private var userSelection: UserWithRecent?
    @State private var showingSetting = false
    @State private var showingGroupedUser = true
    
    var body: some View {
        Group {
            if showingGroupedUser {
                // Show 3-column layout when showing grouped users.
                NavigationSplitView {
                    sidebar
                } content: {
                    destination(id: communityOrFeedSelection)
                } detail: {
                    NavigationStack {
                        thirdDestination(id: communityOrFeedSelection)
                    }
                }
            } else {
                // Show 2-column layout otherwise.
                NavigationSplitView {
                    sidebar
                } detail: {
                    NavigationStack {
                        destination(id: communityOrFeedSelection)
                    }
                }
            }
        }
    }
    
    private var sidebar: some View {
        List(selection: $communityOrFeedSelection) {
            librarySection
            feedSection
        }
        .toolbar { toolbar }
        .sheet(isPresented: $showingSetting) { settingSheet }
    }

    private var librarySection: some View {
        Section("Bottle") {
            DisclosureGroup(isExpanded: .initial(true)) {
                ForEach(appState.metadata?.communities ?? []) { community in
                    // Click each community in the library to view all posts in that community.
                    // Always show grouped user view.
                    Label(community.name.capitalized, systemImage: "square.stack")
                        .foregroundColor(.primary)
                }
            } label: {
                Label("Library", systemImage: "photo.on.rectangle")
            }
        }
    }

    private var feedSection: some View {
        Section("Feeds") {
            ForEach(appState.communityFeeds, id: \.0) { community, feeds in
                DisclosureGroup(isExpanded: .initial(true)) {
                    ForEach(feeds) { feed in
                        // Click each feed to view all posts in that feed.
                        // Grouped view available.
                        Label(feed.name.capitalized, systemImage: "doc.text.image")
                            .foregroundColor(.primary)
                    }
                } label: {
                    Label(community.capitalized, systemImage: "person.2")
                        .foregroundColor(.primary)
                }
            }
        }
    }

    @ViewBuilder
    private func destination(id: String?) -> some View {
        if let community = appState.metadata?.communities.first(where: { $0.id == id }) {
            if showingGroupedUser {
                libraryUserList(community: community.name, selection: $userSelection)
            } else {
                // TODO: library view for each community
                Text("Gomen!")
            }
        } else if let feed = appState.communityFeeds.flatMap(\.1).first(where: { $0.id == id }) {
            if showingGroupedUser {
                feedUserList(feed: feed, selection: $userSelection)
            } else {
                feedView(feed: feed)
            }
        } else {
            if showingGroupedUser {
                Text("Select a community")
            } else {
                Text("Select a feed")
            }
        }
    }
    
    @ViewBuilder
    private func thirdDestination(id: String?) -> some View {
        if let community = appState.metadata?.communities.first(where: { $0.id == id }) {
            libraryUserView(community: community.name, selection: userSelection)
        } else if let feed = appState.communityFeeds.flatMap(\.1).first(where: { $0.id == id }) {
            feedUserView(feed: feed, selection: userSelection)
        } else {
            Text("Select a user")
        }
    }
        
    private func libraryUserList(community: String, selection: Binding<UserWithRecent?>) -> some View {
        UserList(id: community, selection: selection) { page in
            do {
                return try await fetchArchivedUsers(community: community, page: page)
            } catch {
                print(error)
                return Pagination(items: [], page: 0, pageSize: 0, totalItems: 0, totalPages: 0)
            }
        }
    }
    
    @ViewBuilder
    private func libraryUserView(community: String, selection: UserWithRecent?) -> some View {
        if let userID = selection?.user.userId {
            PostGrid(id: community + userID) { image in
                LocalImageView(image: image)
            } loadMedia: { page in
                do {
                    let result = try await fetchArchivedUserPosts(community: community, userID: userID, page: page)
                    return result.asLocalImage
                } catch {
                    print(error)
                    return Pagination(items: [], page: 0, pageSize: 0, totalItems: 0, totalPages: 0)
                }
            }
        }
    }
    
    private func feedView(feed: Feed) -> some View {
        PostGrid(id: feed.id) { media in
            MediaView(media: media)
        } loadMedia: { page in
            do {
                let result = try await fetchPosts(community: feed.community, feedID: feed.feedId, page: page)
                return result.asPostMedia
            } catch {
                print(error)
                return Pagination(items: [], page: 0, pageSize: 0, totalItems: 0, totalPages: 0)
            }
        }
    }
    
    private func feedUserList(feed: Feed, selection: Binding<UserWithRecent?>) -> some View {
        UserList(id: feed.id, selection: selection) { page in
            do {
                return try await fetchFeedUsers(community: feed.community, feedID: feed.feedId, page: page)
            } catch {
                print(error)
                return Pagination(items: [], page: 0, pageSize: 0, totalItems: 0, totalPages: 0)
            }
        }
    }
    
    @ViewBuilder
    private func feedUserView(feed: Feed, selection: UserWithRecent?) -> some View {
        if let userID = selection?.user.userId {
            PostGrid(id: feed.id + userID) { media in
                MediaView(media: media)
            } loadMedia: { page in
                do {
                    let result = try await fetchFeedUserPosts(community: feed.community, feedID: feed.feedId, userID: userID, page: page)
                    return result.asPostMedia
                } catch {
                    print(error)
                    return Pagination(items: [], page: 0, pageSize: 0, totalItems: 0, totalPages: 0)
                }
            }
        }
    }
    
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem {
            Toggle(isOn: $showingGroupedUser) {
                Label("Show users", systemImage: "person.2")
            }
            .toggleStyle(.button)
        }
        ToolbarItem {
            Button {
                showingSetting = true
            } label: {
                Label("Menu", systemImage: "ellipsis.circle")
            }
        }
    }
    
    @ViewBuilder
    private var settingSheet: some View {
        Spacer()
        HStack {
            Spacer()
            Form {
                Section(header: Text("Server")) {
                    TextField("Address", text: $serverAddress)
                        .autocorrectionDisabled()
                        .onSubmit {
                            Task { await refetch() }
                            showingSetting = false
                        }
                }
            }
            Spacer()
        }
        Spacer()
    }
    
    private func refetch() async {
        do {
            appState = AppState()
            let metadata = try await fetchMetadata()
            let feeds = try await fetchFeeds(communityNames: metadata.communities.map(\.name))
            appState = AppState(metadata: metadata, feeds: feeds)
        } catch {
            print(error)
        }
    }
}
