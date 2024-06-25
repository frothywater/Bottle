//
//  StatusBar.swift
//  Bottle
//
//  Created by Cobalt on 9/25/23.
//

import SwiftUI

struct StatusBar: View {
    let message: String
    @Binding var columnCount: Double
    
    private let hasSlider: Bool
    
    init(message: String, columnCount: Binding<Double>? = nil) {
        self.message = message
        _columnCount = columnCount ?? .constant(0)
        hasSlider = columnCount != nil
    }
    
    var body: some View {
        Group {
            Text(message)
                .font(.caption).foregroundColor(.secondary)
            if hasSlider {
                Slider(value: $columnCount, in: 1 ... 6, step: 1)
                    .controlSize(.mini)
                    .frame(width: 120)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .frame(height: 30)
        .frame(maxWidth: .infinity)
        .padding([.leading, .trailing], 15)
        .background { Rectangle().fill(.bar) }
    }
}

struct StatusBar_Previews: PreviewProvider {
    static var previews: some View {
        StatusBar(message: "message")
        StatusBar(message: "message", columnCount: .initial(3))
    }
}
