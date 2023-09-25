//
//  InfiniteScroll.swift
//  Bottle
//
//  Created by Cobalt on 9/11/23.
//

import SwiftUI

struct InfiniteScroll<Item: Identifiable, Content: View, LoadResult: Paginated, ID: Equatable>: View
    where LoadResult.Item == Item
{
    let id: ID
    let loadAction: (_ page: Int) async throws -> LoadResult
    let onChanged: (_ loading: Bool, _ page: Int, _ totalPages: Int?, _ totalItems: Int?) -> Void
    @ViewBuilder let content: (_ item: Item) -> Content

    init(id: ID, _ content: @escaping (_ item: Item) -> Content,
         loadAction: @escaping (_ page: Int) async throws -> LoadResult,
         onChanged: @escaping (_ loading: Bool, _ page: Int, _ totalPages: Int?, _ totalItems: Int?) -> Void = { _, _, _, _ in })
    {
        self.id = id
        self.loadAction = loadAction
        self.onChanged = onChanged
        self.content = content
    }

    @State private var items = [Item]()
    @State private var page = 0
    @State private var totalPages: Int?
    @State private var totalItems: Int?
    @State private var loading = false

    var body: some View {
        if startedLoading {
            ForEach(Array(zip(items, items.indices)), id: \.0.id) { item, index in
                content(item)
                    .task {
                        if index == items.count - 1 {
                            await load()
                        }
                    }
            }
        } else {
            Color.clear
                .task(id: id) {
                    reset()
                    await load()
                }
        }
    }

    private var startedLoading: Bool { totalPages != nil }

    private var finishedLoading: Bool {
        if let totalPages = totalPages, page == totalPages { return true }
        return false
    }

    private func reset() {
        items.removeAll()
        page = 0
        totalPages = nil
        totalItems = nil
        loading = false
    }

    private func load() async {
        if finishedLoading { return }
        defer { loading = false }
        do {
            loading = true
            onChanged(loading, page, totalPages, totalItems)

            let result = try await loadAction(page)

            items.append(contentsOf: result.items)
            page += 1
            totalPages = result.totalPages
            totalItems = result.totalItems
            onChanged(loading, page, totalPages, totalItems)
        } catch {
            print(error)
        }
    }
}
