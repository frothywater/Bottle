//
//  LibraryView.swift
//  Bottle
//
//  Created by Cobalt on 9/24/23.
//

import NukeUI
import SwiftUI

struct LibraryView: View {
    @State private var images = [LocalImage]()
    @State private var page = 0
    @State private var totalPages: Int?
    @State private var totalItems: Int?
    @State private var loading = false
    @State private var columnCount = 3.0

    private var columns: [GridItem] { Array(repeating: GridItem(.flexible()), count: lround(columnCount)) }

    var body: some View {
        ScrollView {
            VStack {
                LazyVGrid(columns: columns, spacing: 15) {
                    ForEach(Array(zip(images, images.indices)), id: \.0.id) { image, index in
                        ImageView(image: image)
                            .task {
                                if index == images.count - 1 {
                                    await load()
                                }
                            }
                    }
                }
                if loading {
                    ProgressView()
                }
            }
            .padding()
            .task {
                if images.isEmpty {
                    await load()
                }
            }
        }
        .overlay(alignment: .bottom) {
            if let totalPages = totalPages, let totalItems = totalItems {
                ZStack {
                    Text("\(page)/\(totalPages) pages, \(totalItems) works in total")
                        .font(.caption).foregroundColor(.secondary)
                    Slider(value: $columnCount, in: 1 ... 10, step: 1)
                        .controlSize(.small)
                        .frame(width: 120)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding([.top, .bottom], 5)
                .padding([.leading, .trailing], 15)
                .background { Rectangle().fill(.thickMaterial) }
                .overlay(alignment: .top) { Divider() }
            }
        }
    }

    private var finishedLoading: Bool {
        if let totalPages = totalPages, page == totalPages { return true }
        return false
    }

    private func load() async {
        if finishedLoading { return }
        defer { loading = false }
        do {
            loading = true
            let result = try await fetchWorks(page: page)
            let images = result.items.flatMap { work in work.images.compactMap(\.localImage) }

            self.images.append(contentsOf: images)
            page += 1
            totalPages = result.totalPages
            totalItems = result.totalItems
        } catch {
            print(error)
        }
    }
}

private struct LocalImage {
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

private struct ImageView: View {
    let image: LocalImage

    @State private var presentingModal = false
    @State private var hovering = false

    var body: some View {
        LazyImage(url: image.url) { state in
            if let image = state.image {
                image.resizable().scaledToFit()
            } else if state.error != nil {
                Color.secondary.overlay { Image(systemName: "photo") }
            } else {
                Color.secondary
            }
        }
        .aspectRatio(CGSize(width: image.width, height: image.height), contentMode: .fit)
        .cornerRadius(20)
        .shadow(radius: hovering ? 10 : 5)
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
                Color.clear.overlay(Image(systemName: "photo"))
            } else {
                Color.clear.overlay(ProgressView())
            }
        }
        .contentShape(Rectangle())
        .frame(minWidth: modalWidth, minHeight: modalHeight)
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
