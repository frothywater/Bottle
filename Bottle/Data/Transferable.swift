//
//  Transferable.swift
//  Bottle
//
//  Created by Cobalt Velvet on 2024/6/27.
//

import CoreTransferable
import UniformTypeIdentifiers
import SwiftUI

struct DraggableWork: Transferable {
    let image: Image
    let work: Work
    
    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation(exporting: \.work)
        ProxyRepresentation(exporting: \.image)
    }
}

extension Work: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .work)
    }
}

extension UTType {
    static var work: UTType { UTType(exportedAs: "com.frothywater.bottle.work") }
}
