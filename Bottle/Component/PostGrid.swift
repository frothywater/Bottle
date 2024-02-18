//
//  PostGrid.swift
//  Bottle
//
//  Created by Cobalt on 10/26/23.
//

import SwiftUI

struct PostGrid: View {
    let id: ID
    let loadMedia: (_ page: Int) async throws -> GeneralResponse

    @StateObject private var model: MediaViewModel
    @State private var loading = false
    @State private var columnCount = 3.0

    private var columns: [GridItem] { Array(repeating: GridItem(.flexible()), count: lround(columnCount)) }

    init(id: ID, orderByWork: Bool = false, loadMedia: @escaping (_: Int) async -> GeneralResponse) {
        self.id = id
        self.loadMedia = loadMedia
        self._model = .init(wrappedValue: MediaViewModel(orderByWork: orderByWork))
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 10) {
                if model.startedLoading {
                    ForEach(Array(model.mediaIDs.enumerated()), id: \.element) { index, mediaID in
                        if let (user, post, media, work, image) = model.entities(for: mediaID) {
                            MediaView(mediaID: mediaID, model: model, user: user, post: post, media: media, work: work, image: image)
                                .task {
                                    if index == model.mediaIDs.count - 1 { await load() }
                                }
                        }
                    }
                } else {
                    Color.clear.task(id: id) { await load() }
                }
            }
            .padding(5)
        }
        .contentMargins(.bottom, 30)
        .overlay(alignment: .bottom) { StatusBar(message: statusMessage, columnCount: $columnCount) }
        .onChange(of: self.id) { reset() }
    }

    var statusMessage: String { "\(model.page)/\(model.totalPages ?? 0) pages, \(model.totalItems ?? 0) posts in total" }

    private func load() async {
        if model.finishedLoading { return }
        defer {
            loading = false
        }
        do {
            print("Loading PostGrid \(id)")
            loading = true
            let response = try await loadMedia(model.page)
            model.update(response)
        } catch {
            print(error)
        }
    }

    private func reset() {
        print("Reset PostGrid \(id)")
        loading = false
        model.reset()
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
