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
    @State private var hovering = false

    var body: some View {
        LazyImage(request: media.inner.thumbnailRequest) { state in
            if let image = state.image {
                image.resizable().scaledToFit()
            } else if state.error != nil {
                Color.secondary.overlay { Image(systemName: "photo") }
            } else {
                Color.secondary
            }
        }
        .aspectRatio(CGSize(width: media.inner.width, height: media.inner.height), contentMode: .fit)
        .cornerRadius(20)
        .shadow(radius: hovering ? 10 : 5)
        .sheet(isPresented: $presentingModal) {
            ImageSheet(media: media, presentingModal: $presentingModal)
        }
        .overlay(alignment: .topTrailing) {
            ImportButton(media: media, selected: $hovering)
        }
        .onTapGesture { presentingModal = true }
        .onHover { hovering = $0 }
        .animation(.default, value: hovering)
    }
}

private struct ImageSheet: View {
    let media: PostMedia
    @Binding var presentingModal: Bool

    @State private var hovering = false

    var body: some View {
        LazyImage(request: media.inner.urlRequest) { state in
            if let image = state.image {
                image.resizable().scaledToFit()
            } else if state.error != nil {
                Color.clear.overlay(Image(systemName: "photo"))
            } else {
                Color.clear.overlay(ProgressView())
            }
        }
        .contentShape(Rectangle())
        .overlay(alignment: .topTrailing) {
            ImportButton(media: media, selected: $hovering)
        }
        .frame(minWidth: modalWidth, minHeight: modalHeight)
        .onTapGesture { presentingModal = false }
        .onHover { hovering = $0 }
        .animation(.default, value: hovering)
    }

    private var mediaRatio: CGFloat { CGFloat(media.inner.width) / CGFloat(media.inner.height) }
    private var maxWidth: CGFloat { Legacy.screenWidth ?? 800 }
    private var maxHeight: CGFloat { (Legacy.screenHeight ?? 600) * 0.95 }
    private var modalWidth: CGFloat { mediaRatio > Legacy.screenRatio ? maxWidth : maxHeight * mediaRatio }
    private var modalHeight: CGFloat { mediaRatio > Legacy.screenRatio ? maxWidth / mediaRatio : maxHeight }
}

private struct ImportButton: View {
    let media: PostMedia
    @Binding var selected: Bool

    @State var hovering = false
    @State var operating = false
    @State var work: Work?

    init(media: PostMedia, selected: Binding<Bool>) {
        self.media = media
        _selected = selected
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
        .frame(width: 32, height: 32)
        .padding(8)
        .opacity(imported || selected || operating ? 1 : 0)
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.default, value: selected)
        .animation(.default, value: hovering)
        .animation(.default, value: imported)
        .animation(.default, value: operating)
    }

    private var symbol: String { hovering != imported ? "bookmark.fill" : "bookmark" }

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
        ImageSheet(media: example, presentingModal: .constant(true))
        ImportButton(media: example, selected: .constant(true))
    }
}
