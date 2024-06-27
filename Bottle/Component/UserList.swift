//
//  UserList.swift
//  Bottle
//
//  Created by Cobalt on 10/26/23.
//

import NukeUI
import SwiftUI

struct UserList<VM: UserProvider & ContentLoader & ObservableObject>: View {
    @Binding var selection: User.ID?
    @StateObject var model: VM

    var body: some View {
        List(selection: $selection) {
            if model.startedLoading {
                ForEach(Array(model.userIDs.enumerated()), id: \.element) { index, userID in
                    if let entities = model.entities(for: userID) {
                        UserRecentRow(entities: entities)
                            .task {
                                if index == model.userIDs.count - 1 { await model.load() }
                            }
                    }
                }
            } else {
                Color.clear.task { await model.load() }
            }
        }
        .listStyle(.inset)
        .safeAreaPadding(.bottom, 30)
        .scrollContentBackground(.hidden)
        .overlay(alignment: .bottom) { StatusBar(message: model.message) }
        #if os(iOS)
            .toolbar(.hidden)
        #endif
    }
}

@MainActor
private struct UserRecentRow: View {
    let entities: UserEntities
    
    @State private var browsingCommunity = false

    var body: some View {
        VStack(alignment: .leading) {
            profile
            recent
        }
        .padding([.top, .bottom], 5)
        .fixVerticalScrolling()
        .contextMenu { contextMenu }
        .navigationDestination(isPresented: $browsingCommunity) {
            userInCommunityDestination(user: entities.user)
        }
    }

    @ViewBuilder
    var profile: some View {
        let user = entities.user
        HStack(spacing: 10) {
            Group {
                LazyImage(request: user.avatarUrl?.imageRequest) { state in
                    if let image = state.image {
                        image.resizable().scaledToFit()
                    } else if state.error != nil {
                        Image(systemName: "person")
                    }
                }
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
            .overlay { Circle().stroke(.separator) }

            VStack(alignment: .leading) {
                Text(user.name ?? user.userId).font(.title3)
                if let username = user.username {
                    Text("@" + username).font(.caption2)
                }
            }
            .badge(user.postCount ?? 0)
        }
    }

    var recent: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 5) {
                ForEach(entities.items, id: \.media.id) { item in
                    recentImage(item: item)
                }
            }
        }
    }

    @ViewBuilder
    func recentImage(item: UserEntities.RecentItem) -> some View {
        let url = item.image?.localSmallThumbnailURL ?? item.image?.localThumbnailURL ?? item.media.thumbnailUrl
        LazyImage(request: url?.imageRequest) { state in
            if let image = state.image {
                image.resizable().scaledToFit()
            } else if state.error != nil {
                Color.clear.overlay { Image(systemName: "photo") }
            } else {
                Color.clear
            }
        }
        .fit(width: item.media.width, height: item.media.height)
        .frame(height: 100)
        .cornerRadius(5)
        .overlay { RoundedRectangle(cornerRadius: 5).stroke(.separator) }
    }

    @ViewBuilder
    var contextMenu: some View {
        let user = entities.user
        Button {
            browsingCommunity.toggle()
        } label: {
            Label("Browse \"\(user.name ?? user.userId)\" Posts at \(user.community.capitalized)", systemImage: "globe")
        }
    }
}

// MARK: - ID

enum UserListID: Hashable {
    case library(String)
    case feed(Feed.ID)
}
