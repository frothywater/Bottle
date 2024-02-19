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
    
    @State private var destinationSelection: SidebarDestination?
    @State private var userSelection: User.ID?
    @State private var showingSetting = false
    @State private var showingGroupedUser = false
    
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
        .toolbar { toolbar }
        .sheet(isPresented: $showingSetting) { settingSheet }
    }

    private var librarySection: some View {
        Section("Bottle") {
            DisclosureGroup(isExpanded: .initial(true)) {
                ForEach(appState.metadata?.communities ?? [], id: \.destination) { community in
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
                    ForEach(feeds, id: \.destination) { feed in
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
    private func destination(for selection: SidebarDestination?) -> some View {
        if case .community(let community) = selection {
            if showingGroupedUser {
                libraryUserList(community: community, selection: $userSelection)
            } else {
                libraryView(community: community)
            }
        } else if case .feed = selection,
                  let feed = appState.feeds.first(where: { $0.destination == selection! })
        {
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
    private func thirdDestination(for selection: SidebarDestination?) -> some View {
        if case .community(let community) = selection {
            libraryUserView(community: community, selection: userSelection)
        } else if case .feed = selection,
                  let feed = appState.feeds.first(where: { $0.destination == selection! })
        {
            feedUserView(feed: feed, selection: userSelection)
        } else {
            Text("Select a user")
        }
    }
        
    private func libraryView(community: String) -> some View {
        PostGrid(id: .library(community), model: PaginatedMediaViewModel(orderByWork: true) { page in
            try await fetchCommunityWorks(community: community, page: page)
        })
    }
    
    private func libraryUserList(community: String, selection: Binding<User.ID?>) -> some View {
        UserList(id: .library(community), selection: selection, model: PaginatedUserViewModel { page in
            try await fetchArchivedUsers(community: community, page: page)
        })
    }
    
    @ViewBuilder
    private func libraryUserView(community: String, selection: User.ID?) -> some View {
        if let userID = selection {
            PostGrid(id: .libraryByUser(userID), model: PaginatedMediaViewModel(orderByWork: true) { page in
                try await fetchArchivedUserPosts(community: community, userID: userID.userId, page: page)
            })
        }
    }
    
    private func feedView(feed: Feed) -> some View {
        PostGrid(id: .feed(feed.id), model: PaginatedMediaViewModel { page in
            try await fetchPosts(community: feed.community, feedID: feed.feedId, page: page)
        })
    }
    
    private func feedUserList(feed: Feed, selection: Binding<User.ID?>) -> some View {
        UserList(id: .feed(feed.id), selection: selection, model: PaginatedUserViewModel { page in
            try await fetchFeedUsers(community: feed.community, feedID: feed.feedId, page: page)
        })
    }
    
    @ViewBuilder
    private func feedUserView(feed: Feed, selection: User.ID?) -> some View {
        if let userID = selection {
            PostGrid(id: .feedByUser(feed.id, userID), model: PaginatedMediaViewModel { page in
                try await fetchFeedUserPosts(community: feed.community, feedID: feed.feedId, userID: userID.userId, page: page)
            })
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
        ToolbarItem(placement: .automatic) {
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
