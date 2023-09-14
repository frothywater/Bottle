//
//  InfiniteScroll.swift
//  Bottle
//
//  Created by Cobalt on 9/11/23.
//

import SwiftUI

struct InfiniteScroll: View {
    @State var items = [Int]()
    @State var page = 0
    @State var totalPages: Int?
    @State var totalPosts: Int?
    @State var loading = false

    private let columns = [GridItem(.adaptive(minimum: 100, maximum: 200))]

    var body: some View {
        VStack {
            HStack {
                Text("\(page)/\(totalPages ?? 0) page" + (loading ? " loading..." : ""))
                Button("Reset") {
                    items.removeAll()
                    page = 0
                    totalPages = nil
                    totalPosts = nil
                    loading = false
                    Task { await load() }
                }
            }
            ScrollView {
                VStack {
                    LazyVGrid(columns: columns) {
                        ForEach(items, id: \.self) { item in
                            Text(String(item))
                                .font(.system(size: 48, weight: .heavy))
                                .task {
                                    if items.index(after: item) == items.endIndex {
                                        await load()
                                    }
                                }
                                .frame(height: 100)
                        }
                    }
                    if loading {
                        ProgressView()
                    }
                }
            }
        }
        .frame(width: 600, height: 300)
        .task { await load() }
    }

    private func load() async {
        do {
            if let totalPages = totalPages, page == totalPages { return }
            loading = true

            try await Task.sleep(for: .seconds(1))

            items.append(contentsOf: (page * 10 + 1) ... (page * 10 + 10))
            page += 1
            totalPages = 10
            totalPosts = 200
            loading = false
        } catch {}
    }
}

struct InfiniteScroll_Previews: PreviewProvider {
    static var previews: some View {
        InfiniteScroll()
    }
}
