//
//  ContentView.swift
//  Bottle
//
//  Created by Cobalt on 9/8/23.
//

import SwiftUI

struct ContentView: View {
    let appState: AppState

    var body: some View {
        NavigationSplitView {
            Sidebar(appState: appState)
        } detail: {
            Text("Select a feed")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(appState: AppState())
    }
}
