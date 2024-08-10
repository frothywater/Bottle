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
    @Environment(\.appModel) var appModel

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear { initialize() }
                .task { await appModel.fetchAll() }
        }
        #if os(macOS)
        .windowToolbarStyle(.unifiedCompact)
        #endif
        .commands {
            InspectorCommands()
        }
    }

    private func initialize() {
        if UserDefaults.standard.string(forKey: "serverAddress") == nil {
            UserDefaults.standard.set("http://127.0.0.1:6000", forKey: "serverAddress")
        }
        
        ImagePipeline.shared = makeDefaultImagePipeline()
    }
}

extension EnvironmentValues {
    @Entry var appModel = AppModel()
}
