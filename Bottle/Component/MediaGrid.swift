//
//  MediaGrid.swift
//  Bottle
//
//  Created by Cobalt on 10/26/23.
//

import SwiftUI

struct MediaGrid<VM: MediaProvider & ContentLoader & ObservableObject>: View {
    @StateObject var model: VM

    @AppStorage("postGridColumnCount") private var columnCount = 3.0
    private var columns: [GridItem] { Array(repeating: GridItem(.flexible()), count: lround(columnCount)) }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 10) {
                if model.startedLoading {
                    ForEach(Array(model.mediaIDs.enumerated()), id: \.element) { index, mediaID in
                        if let entities = model.entities(for: mediaID) {
                            MediaView(entities: entities, model: model)
                                .task {
                                    if index == model.mediaIDs.count - 1 { await model.load() }
                                }
                        }
                    }
                } else {
                    Color.clear.task { await model.load() }
                }
            }
        }
        .safeAreaPadding(.bottom, 30)
        .overlay(alignment: .bottom) { StatusBar(message: model.message, columnCount: $columnCount) }
    }
}

// MARK: - ID

enum MediaGridID: Hashable {
    case library(String)
    case libraryByUser(User.ID)
    case feed(Feed.ID)
    case feedByUser(Feed.ID, User.ID)
    case temporaryUser(User.ID)
    case album(Album.ID)
}
