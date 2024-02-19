//
//  MediaView.swift
//  Bottle
//
//  Created by Cobalt on 9/13/23.
//

import NukeUI
import SwiftUI

@MainActor
struct MediaView: View {
    let mediaID: Media.ID
    let model: MediaAggregate
    let user: User?
    let post: Post?
    let media: Media
    let work: Work?
    let image: LibraryImage?

    var thumbnailURL: String? { if image?.path != nil { image?.localURL } else { media.thumbnailUrl } }
    var url: String? { if image?.path != nil { image?.localURL } else { media.url } }

    var body: some View {
        NavigationLink {
            ImageSheet(url: url)
        } label: {
            content
        }
        .buttonStyle(.plain)
        .overlay { RoundedRectangle(cornerRadius: 10).stroke(.separator) }
        .overlay(alignment: .topTrailing) {
            ImportButton(media: media, work: work, model: model)
        }
    }

    var content: some View {
        LazyImage(request: thumbnailURL?.imageRequest) { state in
            if let image = state.image {
                image.resizable().scaledToFit()
                    .draggable(image)
            } else if state.error != nil {
                Color.clear.overlay { Image(systemName: "photo") }
            } else {
                Color.clear
            }
        }
        .fit(width: media.width, height: media.height)
        .contentShape(Rectangle())
        .cornerRadius(10)
    }
}

private struct ImageSheet: View {
    let url: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        LazyImage(request: url?.imageRequest) { state in
            if let image = state.image {
                image.resizable().scaledToFit()
                    .draggable(image)
                #if os(iOS)
                    .zoomable()
                #endif
            } else if state.error != nil {
                Image(systemName: "photo")
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { dismiss() }
        #if os(iOS)
        .toolbar(.hidden)
        #endif
    }
}

private struct ImportButton: View {
    let media: Media
    let work: Work?
    let model: MediaAggregate
    @State var operating = false

    private var imported: Bool { work != nil }
    private var symbol: String { imported ? "bookmark.fill" : "bookmark" }

    var body: some View {
        Button(action: toggle) {
            Circle().fill(.thinMaterial)
                .overlay {
                    if operating {
                        ProgressView().scaleEffect(0.5)
                    } else {
                        Image(systemName: symbol)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.orange)
                    }
                }
        }
        .buttonStyle(.plain)
        .frame(width: 32, height: 32)
        .padding(5)
        .animation(.default, value: imported)
        .animation(.default, value: operating)
        .disabled(operating)
    }

    private func toggle() {
        guard !operating else { return }
        Task {
            defer { operating = false }
            operating = true
            do {
                if imported {
                    guard let workID = work?.id else { return }
                    try await deleteWork(workID: workID)
                    model.deleteWork(workID, for: media.id)
                } else {
                    let response = try await addWork(community: media.community, postID: media.postId, page: media.pageIndex)
                    model.updateEntities(response)
                    model.updateMedia(response)
                }
            } catch {
                print(error)
            }
        }
    }
}
