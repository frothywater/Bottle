//
//  MediaView.swift
//  Bottle
//
//  Created by Cobalt on 9/13/23.
//

import NukeUI
import SwiftUI

struct MediaView: View {
    let media: PostMedia

    @State private var presentingModal = false

    var body: some View {
        NavigationLink {
            ImageSheet(media: media)
        } label: {
            LazyImage(request: media.inner.localThumbnailURL?.imageRequest) { state in
                if let image = state.image {
                    image.resizable().scaledToFit()
                        .draggable(image)
                } else if state.error != nil {
                    Color.clear.overlay { Image(systemName: "photo") }
                } else {
                    Color.clear
                }
            }
            .fit(width: media.inner.width, height: media.inner.height)
            .contentShape(Rectangle())
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
        .overlay { RoundedRectangle(cornerRadius: 10).stroke(.separator) }
        .overlay(alignment: .topTrailing) {
            ImportButton(media: media)
        }
    }
}

private struct ImageSheet: View {
    let media: PostMedia

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        LazyImage(request: (media.inner.localURL ?? "").imageRequest) { state in
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
        .overlay(alignment: .topTrailing) {
            ImportButton(media: media)
        }
    }
}

private struct ImportButton: View {
    let media: PostMedia
    @State var operating = false
    @State var work: Work?

    init(media: PostMedia) {
        self.media = media
        _work = State(initialValue: media.inner.work)
    }

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
    }

    private var symbol: String { imported ? "bookmark.fill" : "bookmark" }

    private var imported: Bool { work != nil }

    private func toggle() {
        guard !operating else { return }
        Task {
            defer { operating = false }
            operating = true
            do {
                if imported {
                    guard let workID = work?.id else { return }
                    try await deleteWork(workID: workID)
                    work = nil
                } else {
                    work = try await addWork(community: media.inner.community, postID: media.postID, page: media.index)
                }
            } catch {
                print(error)
            }
        }
    }
}

struct ImageView_Previews: PreviewProvider {
    static let example = PostMedia(
        inner: Media(mediaId: "", community: "",
                     url: "https://pbs.twimg.com/media/F2NVpflbwAEU8lB.jpg?name=orig",
                     width: 2711, height: 1500,
                     thumbnailUrl: "https://pbs.twimg.com/media/F2NVpflbwAEU8lB.jpg?name=small", work: nil),
        postID: "1685284918182682624", index: 0)

    static var previews: some View {
        MediaView(media: example)
        ImageSheet(media: example)
        ImportButton(media: example)
    }
}
