//
//  Zoom.swift
//  Bottle
//
//  Created by Cobalt on 12/29/23.
//

#if os(iOS)
import SwiftUI

extension View {
    func zoomable() -> some View {
        ZoomableView {
            self
        }
    }
}

private let maxAllowedScale = 4.0

private struct ZoomableView<Content: View>: View {
    let content: () -> Content
    @State private var scale: CGFloat = 1.0

    var body: some View {
        ZoomableScrollView(scale: $scale) {
            content()
        }
    }
}

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
        scrollView.delegate = context.coordinator // for viewForZooming(in:)
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = maxAllowedScale
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.bouncesZoom = true

        // Create a UIHostingController to hold our SwiftUI content
        let hostedView = context.coordinator.hostingController.view!
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
import SwiftUI

extension View {
    func zoomable() -> some View {
        ZoomableView {
            self
        }
    }
}

private struct ZoomableView<Content: View>: View {
    let content: () -> Content

    var body: some View {
        content()
    }
}
#endif
