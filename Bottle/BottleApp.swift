//
//  BottleApp.swift
//  Bottle
//
//  Created by Cobalt on 9/8/23.
//

import Nuke
import SwiftUI

@main
struct BottleApp: App {
    @State var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView(feeds: appState.feeds)
                .onAppear {
                    ImagePipeline.shared = ImagePipeline(configuration: .withDataCache)
                }
                .task {
                    do {
                        let metadata = try await fetchMetadata()
                        let feeds = try await fetchFeeds(communityNames: metadata.communities.map(\.name))
                        appState = AppState(metadata: metadata, feeds: feeds)
                    } catch {
                        print(error)
                    }
                }
        }
        .windowToolbarStyle(.unifiedCompact)
    }
}
