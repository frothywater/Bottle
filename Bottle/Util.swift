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
