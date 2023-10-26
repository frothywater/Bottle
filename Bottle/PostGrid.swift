//
//  PostGrid.swift
//  Bottle
//
//  Created by Cobalt on 10/26/23.
//

import SwiftUI

struct PostGrid<Media: Identifiable & Decodable, Content: View>: View {
    let id: String
    @ViewBuilder let content: (_ media: Media) -> Content
    let loadMedia: (_ page: Int) async throws -> Pagination<Media>

    @State private var loading = false
    @State private var statusMessage = ""
    @State private var columnCount = 3.0

    private var columns: [GridItem] { Array(repeating: GridItem(.flexible()), count: lround(columnCount)) }

    var body: some View {
        ScrollView {
            VStack {
                LazyVGrid(columns: columns, spacing: 10) {
                    InfiniteScroll(id: id) { media in
                        content(media)
                    } loadAction: { page in
                        try await loadMedia(page)
                    } onChanged: { loading, _, page, totalPages, totalItems in
                        self.loading = loading
                        if let totalPages = totalPages, let totalItems = totalItems {
                            statusMessage = "\(page)/\(totalPages) pages, \(totalItems) posts in total"
                        }
                    }
                }
                if loading {
                    ProgressView()
                }
            }
            .padding()
        }
        .overlay(alignment: .bottom) {
            StatusBar(message: statusMessage, columnCount: $columnCount)
        }
    }
}
