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
    @State private var hovering = false

    var body: some View {
        LazyImage(url: image.url) { state in
            if let image = state.image {
                image.resizable()
                    .draggable(image)
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
                    .draggable(image)
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
