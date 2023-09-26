//
//  ContentView.swift
//  Bottle
//
//  Created by Cobalt on 9/8/23.
//

import SwiftUI

struct ContentView: View {
    let feeds: [Feed]

    var body: some View {
        NavigationSplitView {
            Sidebar(feeds: feeds)
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
