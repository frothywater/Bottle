//
//  LibraryGroupView.swift
//  Bottle
//
//  Created by Cobalt on 10/26/23.
//

import SwiftUI

struct LibraryGroupView: View {
    let community: String
    
    var body: some View {
        GroupedUserPostView(id: community) { image in
            LocalImageView(image: image)
        } loadUsers: { page in
            try await fetchArchivedUsers(community: community, page: page)
        } loadMedia: { userID, page in
            let result = try await fetchArchivedUserPosts(community: community, userID: userID, page: page)
            return result.asLocalImage
        }
    }
}
