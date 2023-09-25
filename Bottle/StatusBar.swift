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
    
    var body: some View {
        ZStack {
            Text(message)
                .font(.caption).foregroundColor(.secondary)
            Slider(value: $columnCount, in: 1 ... 10, step: 1)
                .controlSize(.small)
                .frame(width: 120)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding([.top, .bottom], 5)
        .padding([.leading, .trailing], 15)
        .background { Rectangle().fill(.thickMaterial) }
        .overlay(alignment: .top) { Divider() }
    }
}

struct StatusBar_Previews: PreviewProvider {
    static var previews: some View {
        StatusBar(message: "message", columnCount: .initial(3))
    }
}
