//
//  VerticalScrollFix.swift
//  Bottle
//
//  Created by Cobalt on 10/28/23.
//  https://stackoverflow.com/questions/64920744/swiftui-nested-scrollviews-problem-on-macos

import SwiftUI

#if os(macOS)

// this is the NSView that implements proper `wantsForwardedScrollEvents` method
final class VerticalScrollingFixHostingView<Content>: NSHostingView<Content> where Content: View {
    override func wantsForwardedScrollEvents(for axis: NSEvent.GestureAxis) -> Bool {
        return axis == .vertical
    }
}

// this is the SwiftUI wrapper for our NSView
struct VerticalScrollingFixViewRepresentable<Content>: NSViewRepresentable where Content: View {
    let content: Content

    func makeNSView(context: Context) -> NSHostingView<Content> {
        return VerticalScrollingFixHostingView<Content>(rootView: content)
    }

    func updateNSView(_ nsView: NSHostingView<Content>, context: Context) {}
}

// this is the SwiftUI wrapper that makes it easy to insert the view
// into the existing SwiftUI view builders structure
struct VerticalScrollingFixWrapper<Content>: View where Content: View {
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        VerticalScrollingFixViewRepresentable(content: self.content())
    }
}
#endif

extension View {
    @ViewBuilder func fixVerticalScrolling() -> some View {
        #if os(macOS)
        VerticalScrollingFixWrapper { self }
        #else
        self
        #endif
    }
}
