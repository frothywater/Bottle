//
//  PostGrid.swift
//  Bottle
//
//  Created by Cobalt on 3/27/24.
//

import SwiftUI

struct PostGrid<VM: PostProvider & ContentLoader & ObservableObject>: View {
    @StateObject var model: VM

    @AppStorage("postGridColumnCount") private var columnCount = 3.0
    private var columns: [GridItem] { Array(repeating: GridItem(.flexible()), count: lround(columnCount)) }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 10) {
                if model.startedLoading {
                    ForEach(Array(model.postIDs.enumerated()), id: \.element) { index, postID in
                        if let entities = model.entities(for: postID) {
                            PostView(entities: entities, model: model)
                                .task {
                                    if index == model.postIDs.count - 1 { await model.load() }
                                }
                        }
                    }
                } else {
                    Color.clear.task { await model.load() }
                }
            }
            .padding(5)
        }
        .contentMargins(.bottom, 30)
        .overlay(alignment: .bottom) { StatusBar(message: model.message, columnCount: $columnCount) }
        #if os(iOS)
            .toolbar(.hidden)
        #endif
    }
}

// MARK: - ID

enum PostGridID: Hashable {
    case library(String)
    case libraryByUser(User.ID)
    case feed(Feed.ID)
    case feedByUser(Feed.ID, User.ID)
    case temporaryUser(User.ID)
}
