//
//  Zoom.swift
//  Bottle
//
//  Created by Cobalt on 12/29/23.
//

import SwiftUI

private let maxAllowedScale = 4.0

extension View {
    func zoomable() -> some View {
        ZoomableView {
            self
        }
    }
}

private struct ZoomableView<Content: View>: View {
    let content: () -> Content
    @State private var scale: CGFloat = 1.0

    var body: some View {
        ZoomableScrollView(scale: $scale) {
            content()
        }
    }
}

#if os(iOS)

    private struct ZoomableScrollView<Content: View>: UIViewRepresentable {
        private var content: Content
        @Binding private var scale: CGFloat

        init(scale: Binding<CGFloat>, @ViewBuilder content: () -> Content) {
            self._scale = scale
            self.content = content()
        }

        func makeUIView(context: Context) -> UIScrollView {
            // set up the UIScrollView
            let scrollView = UIScrollView()
            scrollView.delegate = context.coordinator  // for viewForZooming(in:)
            scrollView.minimumZoomScale = 1
            scrollView.maximumZoomScale = maxAllowedScale
            scrollView.showsVerticalScrollIndicator = false
            scrollView.showsHorizontalScrollIndicator = false
            scrollView.bouncesZoom = true

            // Create a UIHostingController to hold our SwiftUI content
            let hostedView = context.coordinator.hostingController.view!
            // TODO: Layout without pillar/letter-box
            hostedView.translatesAutoresizingMaskIntoConstraints = true
            hostedView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            hostedView.frame = scrollView.bounds
            scrollView.addSubview(hostedView)

            return scrollView
        }

        func makeCoordinator() -> Coordinator {
            return Coordinator(hostingController: UIHostingController(rootView: content), scale: $scale)
        }

        func updateUIView(_ uiView: UIScrollView, context: Context) {
            // update the hosting controller's SwiftUI content
            context.coordinator.hostingController.rootView = content
            uiView.zoomScale = scale
            assert(context.coordinator.hostingController.view.superview == uiView)
        }

        class Coordinator: NSObject, UIScrollViewDelegate {
            var hostingController: UIHostingController<Content>
            @Binding var scale: CGFloat

            init(hostingController: UIHostingController<Content>, scale: Binding<CGFloat>) {
                self.hostingController = hostingController
                self._scale = scale
            }

            func viewForZooming(in scrollView: UIScrollView) -> UIView? {
                return hostingController.view
            }

            func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
                self.scale = scale
            }
        }
    }

#else

    private struct ZoomableScrollView<Content: View>: NSViewRepresentable {
        private var content: Content
        @Binding private var scale: CGFloat

        init(scale: Binding<CGFloat>, @ViewBuilder content: () -> Content) {
            self._scale = scale
            self.content = content()
        }

        func makeNSView(context: Context) -> NSScrollView {
            // set up the UIScrollView
            let scrollView = NSScrollView()
            scrollView.allowsMagnification = true
            scrollView.minMagnification = 1
            scrollView.maxMagnification = maxAllowedScale

            scrollView.hasVerticalScroller = false
            scrollView.hasHorizontalScroller = false
            scrollView.usesPredominantAxisScrolling = false

            NotificationCenter.default.addObserver(
                context.coordinator,
                selector: #selector(Coordinator.scrollViewDidEndZooming),
                name: NSScrollView.didEndLiveMagnifyNotification,
                object: scrollView)

            // Create a UIHostingController to hold our SwiftUI content
            let hostedView = context.coordinator.hostingController.view
            // TODO: Layout without pillar/letter-box
            hostedView.translatesAutoresizingMaskIntoConstraints = true
            hostedView.autoresizingMask = [.width, .height]
            hostedView.frame = scrollView.bounds
            scrollView.documentView = hostedView

            return scrollView
        }

        func makeCoordinator() -> Coordinator {
            return Coordinator(hostingController: NSHostingController(rootView: content), scale: $scale)
        }

        func updateNSView(_ uiView: NSScrollView, context: Context) {
            // update the hosting controller's SwiftUI content
            context.coordinator.hostingController.rootView = content
            uiView.magnification = scale
            assert(context.coordinator.hostingController.view.enclosingScrollView == uiView)
        }

        class Coordinator: NSObject {
            var hostingController: NSHostingController<Content>
            @Binding var scale: CGFloat

            init(hostingController: NSHostingController<Content>, scale: Binding<CGFloat>) {
                self.hostingController = hostingController
                self._scale = scale
            }

            func viewForZooming(in scrollView: NSScrollView) -> NSView? {
                return hostingController.view
            }

            @objc func scrollViewDidEndZooming(notification: Notification) {
                self.scale = (notification.object as! NSScrollView).magnification
            }
        }
    }

#endif
