//
//  ContentView.swift
//  Bottle
//
//  Created by Cobalt on 9/8/23.
//

import SwiftUI

struct ContentView: View {
    let feeds: [Feed]

    private var communityFeeds: [(String, [Feed])] {
        var result = [(String, [Feed])]()
        for feed in feeds {
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
        NavigationSplitView {
            List {
                Section("Bottle") {
                    NavigationLink {
                        LibraryView()
                    } label: {
                        Label("Library", systemImage: "photo.on.rectangle")
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
        } detail: {
            Text("Select a feed")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(feeds: [])
    }
}
