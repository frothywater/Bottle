//
//  PostGrid.swift
//  Bottle
//
//  Created by Cobalt on 10/26/23.
//

import SwiftUI

struct PostGrid<VM: MediaAggregate & ContentLoader & ObservableObject>: View {
    let id: ID
    @StateObject var model: VM
    
    @State private var columnCount = 3.0
    private var columns: [GridItem] { Array(repeating: GridItem(.flexible()), count: lround(columnCount)) }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 10) {
                if model.startedLoading {
                    ForEach(Array(model.mediaIDs.enumerated()), id: \.element) { index, mediaID in
                        if let (user, post, media, work, image) = model.entities(for: mediaID) {
                            MediaView(mediaID: mediaID, model: model,
                                      user: user, post: post, media: media, work: work, image: image)
                                .task {
                                    if index == model.mediaIDs.count - 1 { await model.load() }
                                }
                        }
                    }
                } else {
                    Color.clear.task(id: id) { await model.load() }
                }
            }
            .padding(5)
        }
        .contentMargins(.bottom, 30)
        .overlay(alignment: .bottom) { StatusBar(message: model.message, columnCount: $columnCount) }
        .onChange(of: self.id) { model.reset() }
        #if os(iOS)
        .toolbar(.hidden)
        #endif
    }
}

// MARK: - ID

extension PostGrid {
    enum ID: Equatable {
        case library(String)
        case libraryByUser(User.ID)
        case feed(Feed.ID)
        case feedByUser(Feed.ID, User.ID)
    }
}
