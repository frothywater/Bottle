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
            ContentView(appState: $appState)
                .onAppear { initialize() }
                .task { await fetch() }
        }
        #if os(macOS)
        .windowToolbarStyle(.unifiedCompact)
        #endif
    }

    private func initialize() {
        if UserDefaults.standard.string(forKey: "serverAddress") == nil {
            UserDefaults.standard.set("http://127.0.0.1:6000", forKey: "serverAddress")
        }
        ImagePipeline.shared = ImagePipeline(configuration: .withDataCache(name: "com.frothywater.Bottle.DataCache", sizeLimit: 1024))
    }

    private func fetch() async {
        do {
            let metadata = try await fetchMetadata()
            let feeds = try await fetchFeeds(communityNames: metadata.communities.map(\.name))
            appState = AppState(metadata: metadata, feeds: feeds)
        } catch {
            print(error)
        }
    }
}
