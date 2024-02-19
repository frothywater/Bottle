//
//  ViewModel.swift
//  Bottle
//
//  Created by Cobalt on 2/8/24.
//

import Foundation

// MARK: - Aggregate

protocol EntityAggregate: AnyObject {
    // The dictionary of entities
    var userDict: [User.ID: User] { get set }
    var postDict: [Post.ID: Post] { get set }
    var mediaDict: [Media.ID: Media] { get set }
    var workDict: [Work.ID: Work] { get set }
    var imageDict: [LibraryImage.ID: LibraryImage] { get set }

    // The dictionary of relationships
    var postMedia: [Post.ID: [Media.ID]] { get set }
    var workImages: [Work.ID: [LibraryImage.ID]] { get set }
    /// Currently only support single-image works
    var pageWork: [PageID: Work.ID] { get set }
}

extension EntityAggregate {
    func updateEntities(_ response: EntityContainer) {
        userDict.merge(response.users)
        postDict.merge(response.posts)
        mediaDict.merge(response.media)
        workDict.merge(response.works)
        imageDict.merge(response.images)

        // Map post to media
        postMedia.merge(response.media?.map { ($0.postID, $0.id) })
        // Map work to images
        workImages.merge(response.images?.map { ($0.workId, $0.id) })
        // Map page to work
        for work in response.works ?? [] {
            guard let pageID = work.pageID else { continue }
            pageWork[pageID] = work.id
        }
    }

    func resetEntities() {
        userDict = [:]
        postDict = [:]
        mediaDict = [:]
        workDict = [:]
        imageDict = [:]
        postMedia = [:]
        workImages = [:]
        pageWork = [:]
    }

    func workImage(for mediaID: Media.ID) -> (Work?, LibraryImage?) {
        guard let media = mediaDict[mediaID] else { return (nil, nil) }
        let workID = pageWork[media.pageID]
        let work = workDict.at(workID)
        /// Currently only support single-image works
        let imageID = workImages.at(workID)?.first
        let image = imageDict.at(imageID)
        return (work, image)
    }
}

protocol MediaAggregate: EntityAggregate {
    var orderByWork: Bool { get }
    var mediaIDs: [Media.ID] { get set }
    var pageMedia: [PageID: Media.ID] { get set }
}

extension MediaAggregate {
    func updateMedia(_ response: EntityContainer) {
        if orderByWork {
            // Map page to media
            for media in response.media ?? [] {
                pageMedia[media.pageID] = media.id
            }
            // Reorder the media in the order of the works
            let pageIDs = response.works?.compactMap(\.pageID) ?? []
            let media = pageIDs.compactMap { pageMedia[$0] }
            mediaIDs.append(contentsOf: media)
        } else {
            // Reorder the media in the order of the posts
            let media = response.posts?.flatMap { postMedia[$0.id] ?? [] }
            mediaIDs.append(contentsOf: media ?? [])
        }
    }

    func resetMedia() {
        mediaIDs = []
        pageMedia = [:]
    }

    func entities(for mediaID: Media.ID) -> (User?, Post?, Media, Work?, LibraryImage?)? {
        guard let media = mediaDict[mediaID] else { return nil }
        let post = postDict[media.postID]
        let user = userDict.at(post?.userID)
        let (work, image) = workImage(for: mediaID)
        return (user, post, media, work, image)
    }

    func deleteWork(_ workID: Work.ID, for mediaID: Media.ID) {
        guard let media = mediaDict[mediaID] else { return }
        workImages[workID]?.forEach { imageDict.removeValue(forKey: $0) }
        workImages[workID]?.removeAll()
        workDict.removeValue(forKey: workID)
        pageWork.removeValue(forKey: media.pageID)
    }
}

protocol UserAggregate: EntityAggregate {
    var userIDs: [User.ID] { get set }
    var userPosts: [User.ID: [Post.ID]] { get set }
}

extension UserAggregate {
    func updateUser(_ response: GeneralResponse) {
        // Map user to posts
        userPosts.merge(response.posts?.map { ($0.userID, $0.id) })
        userIDs.append(contentsOf: response.users?.map(\.id) ?? [])
    }

    func resetUser() {
        userIDs = []
        userPosts = [:]
    }

    func entities(for userID: User.ID) -> (User, [(Media, LibraryImage?)])? {
        guard let user = userDict[userID] else { return nil }
        let postIDs = userPosts.at(userID) ?? []
        let mediaIDs = postIDs.flatMap { postMedia[$0] ?? [] }
        let mediaImages = mediaIDs.map { mediaID in
            let media = mediaDict[mediaID]!
            let (_, image) = workImage(for: mediaID)
            return (media, image)
        }
        return (user, mediaImages)
    }
}

// MARK: - Loading

protocol ContentLoader: AnyObject {
    associatedtype Request
    associatedtype Response: EntityContainer
    var nextRequest: Request { get }
    var fetch: (_: Request) async throws -> Response { get }

    var startedLoading: Bool { get }
    var finishedLoading: Bool { get }
    var loading: Bool { get set }
    var message: String { get }

    func update(_ response: Response)
    func reset()
}

extension ContentLoader {
    func load() async {
        if finishedLoading { return }
        defer {
            loading = false
        }
        do {
            loading = true
            let response = try await fetch(nextRequest)
            update(response)
        } catch {
            print(error)
        }
    }
}

protocol PaginatedLoader: ContentLoader {
    var page: Int { get set }
    var pageSize: Int? { get set }
    var totalItems: Int? { get set }
}

extension PaginatedLoader {
    var nextRequest: Int { page }

    var totalPages: Int? {
        if let totalItems = totalItems, let pageSize = pageSize, pageSize > 0 {
            return (totalItems + pageSize - 1) / pageSize
        }
        return nil
    }

    var startedLoading: Bool { totalItems != nil }

    var finishedLoading: Bool {
        if let totalPages = totalPages, page == totalPages { return true }
        return false
    }

    var message: String { "\(page)/\(totalPages ?? 0) pages, \(totalItems ?? 0) items in total" }

    func updateLoader(_ response: PaginatedResponse) {
        page = response.page + 1
        if !startedLoading {
            pageSize = response.pageSize
            totalItems = response.totalItems
        }
    }

    func resetLoader() {
        page = 0
        pageSize = nil
        totalItems = nil
        loading = false
    }
}

protocol IndefiniteLoader: ContentLoader {
    var startedLoading: Bool { get set }
    var reachedEnd: Bool { get set }
    var nextOffset: String? { get set }
}

extension IndefiniteLoader {
    var nextRequest: String? { nextOffset }

    var finishedLoading: Bool { reachedEnd }

    var message: String { reachedEnd ? "No more items" : "More items" }

    func updateLoader(_ response: IndefiniteResponse) {
        startedLoading = true
        reachedEnd = response.reachedEnd
        nextOffset = response.nextOffset
    }

    func resetLoader() {
        reachedEnd = false
        nextOffset = nil
        loading = false
    }
}

// MARK: - View model

class PaginatedMediaViewModel: MediaAggregate, PaginatedLoader, ObservableObject {
    let orderByWork: Bool
    let fetch: (_: Int) async throws -> GeneralResponse

    var userDict = [User.ID: User]()
    var postDict = [Post.ID: Post]()
    var mediaDict = [Media.ID: Media]()
    var workDict = [Work.ID: Work]()
    var imageDict = [LibraryImage.ID: LibraryImage]()

    var postMedia = [Post.ID: [Media.ID]]()
    var workImages = [Work.ID: [LibraryImage.ID]]()
    var pageMedia = [PageID: Media.ID]()

    @Published var mediaIDs = [Media.ID]()
    @Published var pageWork = [PageID: Work.ID]()

    @Published var page = 0
    @Published var pageSize: Int?
    @Published var totalItems: Int?
    @Published var loading = false

    init(orderByWork: Bool = false, fetch: @escaping (_: Int) async throws -> GeneralResponse) {
        self.orderByWork = orderByWork
        self.fetch = fetch
    }

    func update(_ response: GeneralResponse) {
        updateEntities(response)
        updateMedia(response)
        updateLoader(response)
    }

    func reset() {
        resetEntities()
        resetMedia()
        resetLoader()
    }
}

class PaginatedUserViewModel: UserAggregate, PaginatedLoader, ObservableObject {
    let fetch: (_: Int) async throws -> GeneralResponse

    var userDict = [User.ID: User]()
    var postDict = [Post.ID: Post]()
    var mediaDict = [Media.ID: Media]()
    var workDict = [Work.ID: Work]()
    var imageDict = [LibraryImage.ID: LibraryImage]()

    var postMedia = [Post.ID: [Media.ID]]()
    var workImages = [Work.ID: [LibraryImage.ID]]()
    var userPosts = [User.ID: [Post.ID]]()

    @Published var userIDs = [User.ID]()
    @Published var pageWork = [PageID: Work.ID]()

    @Published var page = 0
    @Published var pageSize: Int?
    @Published var totalItems: Int?
    @Published var loading = false

    init(fetch: @escaping (_: Int) async throws -> GeneralResponse) {
        self.fetch = fetch
    }

    func update(_ response: GeneralResponse) {
        updateEntities(response)
        updateUser(response)
        updateLoader(response)
    }

    func reset() {
        resetEntities()
        resetUser()
        resetLoader()
    }
}
