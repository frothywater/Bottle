//
//  Legacy.swift
//  Bottle
//
//  Created by Cobalt on 9/23/23.
//

import Foundation

#if os(macOS)
    import AppKit
#elseif os(iOS)
    import UIKit
#elseif os(watchOS)
    import WatchKit
#endif

struct Legacy {
    #if os(watchOS)
        static var screenSize = WKInterfaceDevice.current().screenBounds.size
    #elseif os(iOS) || os(tvOS)
        static var screenSize = UIScreen.main.nativeBounds.size
        static var screenWidth = screenSize.width
        static var screenHeight = screenSize.height
        static var screenRatio = screenWidth / screenHeight
    #elseif os(macOS)
        static var screenSize = NSApp.keyWindow?.contentView?.bounds.size
        static var screenWidth = screenSize?.width
        static var screenHeight = screenSize?.height
        static var screenRatio = (screenWidth ?? 0) / (screenHeight ?? 1)
    #endif

    static func toggleSidebar() {
        #if os(iOS)
        #else
            NSApp.sendAction(#selector(NSSplitViewController.toggleSidebar(_:)), to: nil, from: nil)
        #endif
    }
}
