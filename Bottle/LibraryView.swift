//
//  LibraryView.swift
//  Bottle
//
//  Created by Cobalt on 9/24/23.
//

import NukeUI
import SwiftUI

struct LibraryView: View {
    @State private var loading = false
    @State private var statusMessage = ""
    @State private var columnCount = 3.0

    private var columns: [GridItem] { Array(repeating: GridItem(.flexible()), count: lround(columnCount)) }

    var body: some View {
        ScrollView {
            VStack {
                LazyVGrid(columns: columns, spacing: 10) {
                    InfiniteScroll(id: "library") { image in
                        ImageView(image: image)
                    } loadAction: { page -> Pagination<LocalImage> in
                        let result = try await fetchWorks(page: page)
                        return result.asLocalImage
                    } onChanged: { loading, _, page, totalPages, totalItems in
                        self.loading = loading
                        if let totalPages = totalPages, let totalItems = totalItems {
                            statusMessage = "\(page)/\(totalPages) pages, \(totalItems) works in total"
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

private struct LocalImage: Decodable, Identifiable {
    let id: Int
    let width: Int
    let height: Int

    var url: URL? {
        URL(string: baseURL + "/image/\(id)")
    }
}

private extension LibraryImage {
    var localImage: LocalImage? {
        guard let width = width, let height = height else { return nil }
        return LocalImage(id: id, width: width, height: height)
    }
}

private extension Pagination<Work> {
    var asLocalImage: Pagination<LocalImage> {
        Pagination<LocalImage>(
            items: items.flatMap { work in work.images.compactMap(\.localImage) },
            page: page, pageSize: pageSize, totalItems: totalItems, totalPages: totalPages)
    }
}

private struct ImageView: View {
    let image: LocalImage

    @State private var presentingModal = false
    @State private var hovering = false

    var body: some View {
        LazyImage(url: image.url) { state in
            if let image = state.image {
                image.resizable()
            } else if state.error != nil {
                Color.clear.overlay { Image(systemName: "photo") }
            } else {
                Color.clear
            }
        }
        .aspectRatio(CGSize(width: image.width, height: image.height), contentMode: .fit)
        .contentShape(Rectangle())
        .cornerRadius(10)
        .overlay { RoundedRectangle(cornerRadius: 10).stroke(.separator) }
        .sheet(isPresented: $presentingModal) {
            ImageSheet(image: image, presentingModal: $presentingModal)
        }
        .onTapGesture { presentingModal = true }
        .onHover { hovering = $0 }
        .animation(.default, value: hovering)
    }
}

private struct ImageSheet: View {
    let image: LocalImage
    @Binding var presentingModal: Bool

    var body: some View {
        LazyImage(url: image.url) { state in
            if let image = state.image {
                image.resizable().scaledToFit()
            } else if state.error != nil {
                Image(systemName: "photo")
            } else {
                ProgressView()
            }
        }
        .frame(minWidth: modalWidth, minHeight: modalHeight)
        .contentShape(Rectangle())
        .onTapGesture { presentingModal = false }
    }

    private var mediaRatio: CGFloat { CGFloat(image.width) / CGFloat(image.height) }
    private var maxWidth: CGFloat { Legacy.screenWidth ?? 800 }
    private var maxHeight: CGFloat { (Legacy.screenHeight ?? 600) * 0.95 }
    private var modalWidth: CGFloat { mediaRatio > Legacy.screenRatio ? maxWidth : maxHeight * mediaRatio }
    private var modalHeight: CGFloat { mediaRatio > Legacy.screenRatio ? maxWidth / mediaRatio : maxHeight }
}

struct LibraryView_Previews: PreviewProvider {
    static var previews: some View {
        LibraryView()
    }
}
