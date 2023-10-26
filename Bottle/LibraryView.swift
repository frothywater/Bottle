//
//  LibraryView.swift
//  Bottle
//
//  Created by Cobalt on 9/24/23.
//

import SwiftUI

struct LibraryView: View {
    var body: some View {
        PostGrid(id: "Library") { image in
            LocalImageView(image: image)
        } loadMedia: { page in
            let result = try await fetchWorks(page: page)
            return result.asLocalImage
        }
    }
}



struct LibraryView_Previews: PreviewProvider {
    static var previews: some View {
        LibraryView()
    }
}
