//
//  LocalImageView.swift
//  Bottle
//
//  Created by Cobalt on 10/26/23.
//

import NukeUI
import SwiftUI

struct LocalImageView: View {
    let image: LocalImage

    @State private var presentingModal = false

    var body: some View {
        NavigationLink {
            ImageSheet(image: image)
        } label: {
            LazyImage(url: image.url) { state in
                if let fetchedImage = state.image {
                    fetchedImage.resizable()
                    // TODO: draggable
                } else if state.error != nil {
                    Color.clear.overlay { Image(systemName: "photo") }
                } else {
                    Color.clear
                }
            }
            .aspectRatio(CGSize(width: image.width, height: image.height), contentMode: .fit)
            .contentShape(Rectangle())
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
        .overlay { RoundedRectangle(cornerRadius: 10).stroke(.separator) }
        .onTapGesture { presentingModal = true }
    }
}

private struct ImageSheet: View {
    let image: LocalImage

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        LazyImage(url: image.url) { state in
            if let fetchedImage = state.image {
                fetchedImage.resizable().scaledToFit()
                #if os(iOS)
                    .zoomable()
                #endif
                // TODO: draggable
            } else if state.error != nil {
                Image(systemName: "photo")
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { dismiss() }
    }
}

private struct DraggableImage: Transferable {
    let image: LocalImage
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .image) {
            let tempURL = FileManager.default.temporaryDirectory.appending(component: $0.image.filename)
            try $0.data.write(to: tempURL)
            return SentTransferredFile(tempURL)
        }
    }
}
