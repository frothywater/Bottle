//
//  Sidebar.swift
//  Bottle
//
//  Created by Cobalt on 9/25/23.
//

import SwiftUI

struct Sidebar: View {
    let appState: AppState

    private var communityFeeds: [(String, [Feed])] {
        var result = [(String, [Feed])]()
        for feed in appState.feeds {
            if let index = result.firstIndex(where: { $0.0 == feed.community }) {
                result[index].1.append(feed)
            } else {
                result.append((feed.community, [feed]))
            }
        }
        result.sort { $0.0 < $1.0 }
        return result
    }
    
    var body: some View {
        List {
            Section("Bottle") {
                DisclosureGroup(isExpanded: .initial(true)) {
                    ForEach(appState.metadata?.communities ?? []) { community in
                        NavigationLink {
                            LibraryGroupView(community: community.name)
                        } label: {
                            Label(community.name.capitalized, systemImage: "square.stack")
                                .foregroundColor(.primary)
                        }
                    }
                } label: {
                    NavigationLink {
                        LibraryView()
                    } label: {
                        Label("Library", systemImage: "photo.on.rectangle")
                    }
                }
            }

            Section("Feeds") {
                ForEach(communityFeeds, id: \.0) { community, feeds in
                    DisclosureGroup(isExpanded: .initial(true)) {
                        ForEach(feeds) { feed in
                            NavigationLink {
                                FeedView(feed: feed)
                            } label: {
                                Label(feed.name.capitalized, systemImage: "doc.text.image")
                                    .foregroundColor(.primary)
                            }
                        }
                    } label: {
                        Label(community.capitalized, systemImage: "person.2")
                            .foregroundColor(.primary)
                    }
                }
            }
        }
    }
}

struct Sidebar_Previews: PreviewProvider {
    static var previews: some View {
        Sidebar(appState: AppState())
    }
}
