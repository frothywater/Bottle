//
//  Util.swift
//  Bottle
//
//  Created by Cobalt on 9/24/23.
//

import SwiftUI

extension Binding {
    static func initial(_ value: Value) -> Binding<Value> {
        return Binding(get: { value }, set: { _ in })
    }
}

extension View {
    @ViewBuilder func fit(width: Int?, height: Int?) -> some View {
        if let width = width, let height = height {
            self.aspectRatio(CGSize(width: width, height: height), contentMode: .fit)
        } else {
            self
        }
    }
}
