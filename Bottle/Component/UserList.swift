//
//  UserList.swift
//  Bottle
//
//  Created by Cobalt on 10/26/23.
//

import NukeUI
import SwiftUI

struct UserList: View {
    let id: ID
    @Binding var selection: User.ID?
    let loadUsers: (_ page: Int) async throws -> GeneralResponse

    @StateObject private var model = UserViewModel()
    @State private var loading = false

    init(id: ID, selection: Binding<User.ID?>, loadUsers: @escaping (_: Int) async -> GeneralResponse) {
        self.id = id
        self._selection = selection
        self.loadUsers = loadUsers
    }

    var body: some View {
        List(selection: $selection) {
            if model.startedLoading {
                ForEach(Array(model.userIDs.enumerated()), id: \.element) { index, userID in
                    if let (user, mediaImages) = model.entities(for: userID) {
                        UserRecentRow(user: user, mediaImages: mediaImages)
                            .task {
                                if index == model.userIDs.count - 1 { await load() }
                            }
                    }
                }
            } else {
                Color.clear.task(id: id) { await load() }
            }
        }
        .listStyle(.plain)
        .contentMargins(.bottom, 30)
        .scrollContentBackground(.hidden)
        .overlay(alignment: .bottom) { StatusBar(message: statusMessage) }
        .onChange(of: self.id) { reset() }
    }

    var statusMessage: String { "\(model.page)/\(model.totalPages ?? 0) pages, \(model.totalItems ?? 0) users in total" }

    private func load() async {
        if model.finishedLoading { return }
        defer {
            loading = false
        }
        do {
            print("Loading UserList \(id)")
            loading = true
            let response = try await loadUsers(model.page)
            model.update(response)
        } catch {
            print(error)
        }
    }

    private func reset() {
        print("Reset UserList \(id)")
        loading = false
        model.reset()
    }
}

@MainActor
private struct UserRecentRow: View {
    let user: User
    let mediaImages: [(Media, LibraryImage?)]

    var body: some View {
        VStack(alignment: .leading) {
            profile
            recent
        }
        .padding([.top, .bottom], 5)
        .fixVerticalScrolling()
    }

    var profile: some View {
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
                Text(user.name ?? "No name").font(.title3)
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
                ForEach(mediaImages, id: \.0.id) { media, image in
                    recentImage(media: media, image: image)
                }
            }
        }
    }

    @ViewBuilder
    func recentImage(media: Media, image: LibraryImage?) -> some View {
        let url = if image?.path != nil { image?.localURL } else { media.thumbnailUrl }
        LazyImage(request: url?.imageRequest) { state in
            if let image = state.image {
                image.resizable().scaledToFit()
            } else if state.error != nil {
                Color.clear.overlay { Image(systemName: "photo") }
            } else {
                Color.clear
            }
        }
        .fit(width: media.width, height: media.height)
        .frame(height: 100)
        .cornerRadius(5)
        .overlay { RoundedRectangle(cornerRadius: 5).stroke(.separator) }
    }
}

// MARK: - ID

extension UserList {
    enum ID: Equatable {
        case library(String)
        case feed(Feed.ID)
    }
}
