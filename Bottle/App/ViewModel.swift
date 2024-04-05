//
//  ViewModel.swift
//  Bottle
//
//  Created by Cobalt on 2/8/24.
//

import Foundation

// MARK: - Aggregate

protocol EntityProvider: AnyObject {
    // The dictionary of entities
    var userDict: [User.ID: User] { get set }
    var postDict: [Post.ID: Post] { get set }
    var mediaDict: [Media.ID: Media] { get set }
    var workDict: [Work.ID: Work] { get set }
    var imageDict: [LibraryImage.ID: LibraryImage] { get set }

    // The dictionary of relationships
    var postMedia: [Post.ID: [Media.ID]] { get set }
    var workImages: [Work.ID: [LibraryImage.ID]] { get set }
    var pageWork: [PageID: Work.ID] { get set }
    var postWork: [Post.ID: Work.ID] { get set }
//    var pageImage: [PageID: LibraryImage.ID] { get set }
}

extension EntityProvider {
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
        
        for work in response.works ?? [] {
            // Map page to work
            if let pageID = work.pageID {
                pageWork[pageID] = work.id
            }
            // Map post to work
            if let postID = work.postID, work.pageIndex == nil {
                postWork[postID] = work.id
            }
        }
//        // Map page to image
//        for image in response.images ?? [] {
//            guard let work = workDict[image.workId],
//                  let pageID = image.pageID(for: work) else { continue }
//            pageImage[pageID] = image.id
//        }
    }

    /// For single-image works, one media corresponds to one work and image.
    func singleImageWork(for mediaID: Media.ID) -> (Work?, LibraryImage?) {
        guard let media = mediaDict[mediaID] else { return (nil, nil) }
        let workID = pageWork[media.pageID]
        let work = workDict.at(workID)
        let imageID = workImages.at(workID)?.first
        let image = imageDict.at(imageID)
        return (work, image)
    }
    
    func multiImageWork(for postID: Post.ID) -> (Work?, [LibraryImage]) {
        let workID = postWork[postID]
        let work = workDict.at(workID)
        let imageIDs = workImages.at(workID) ?? []
        let images = imageIDs.compactMap { imageDict[$0] }
        return (work, images)
    }
}

protocol PostProvider: EntityProvider {
    var orderByWork: Bool { get }
    var postIDs: [Post.ID] { get set }
}

extension PostProvider {
    func updatePost(_ response: EntityContainer) {
        if orderByWork {
            // Reorder the post in the order of the works
            let posts = response.works?.compactMap { $0.postID }
            postIDs.append(contentsOf: posts ?? [])
        } else {
            let posts = response.posts?.map { $0.id }
            postIDs.append(contentsOf: posts ?? [])
        }
    }

    func entities(for postID: Post.ID) -> (User?, Post, Work?, [Media], [LibraryImage])? {
        guard let post = postDict[postID] else { return nil }
        let user = userDict.at(post.userID)
        let mediaIDs = postMedia[postID] ?? []
        let media = mediaIDs.compactMap { mediaDict[$0] }
        let (work, images) = multiImageWork(for: postID)
        return (user, post, work, media, images)
    }

    func deleteWork(_ workID: Work.ID, for postID: Post.ID) {
        guard let work = workDict[workID], work.pageIndex == nil else { return }
        workImages[workID]?.forEach { imageDict.removeValue(forKey: $0) }
        workImages[workID]?.removeAll()
        workDict.removeValue(forKey: workID)
        postWork.removeValue(forKey: postID)
//        postMedia[postID]?.forEach {
//            guard let media = mediaDict[$0] else { return }
//            pageImage.removeValue(forKey: media.pageID)
//        }
    }
}

protocol MediaProvider: EntityProvider {
    var orderByWork: Bool { get }
    var mediaIDs: [Media.ID] { get set }
    var pageMedia: [PageID: Media.ID] { get set }
}

extension MediaProvider {
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

    func entities(for mediaID: Media.ID) -> (User?, Post?, Media, Work?, LibraryImage?)? {
        guard let media = mediaDict[mediaID] else { return nil }
        let post = postDict[media.postID]
        let user = userDict.at(post?.userID)
        let (work, image) = singleImageWork(for: mediaID)
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

protocol UserProvider: EntityProvider {
    var userIDs: [User.ID] { get set }
    var userPosts: [User.ID: [Post.ID]] { get set }
}

extension UserProvider {
    func updateUser(_ response: GeneralResponse) {
        // Map user to posts
        userPosts.merge(response.posts?.map { ($0.userID, $0.id) })
        userIDs.append(contentsOf: response.users?.map(\.id) ?? [])
    }

    func entities(for userID: User.ID) -> (User, [(Media, LibraryImage?)])? {
        guard let user = userDict[userID] else { return nil }
        let postIDs = userPosts.at(userID) ?? []
        
        var mediaImages = [(Media, LibraryImage?)]()
        for postID in postIDs {
            let workID = postWork[postID]
            let work = workDict.at(workID)
            if work?.pageIndex != nil {
                // Single-image work
                for mediaID in postMedia[postID] ?? [] {
                    let media = mediaDict[mediaID]!
                    let (_, image) = singleImageWork(for: mediaID)
                    mediaImages.append((media, image))
                }
            } else {
                // Multi-image work
                if let mediaID = postMedia[postID]?.first, let media = mediaDict[mediaID] {
                    let (_, images) = multiImageWork(for: postID)
                    mediaImages.append((media, images.first))
                }
            }
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
}

extension ContentLoader {
    func load() async {
        if finishedLoading { return }
        do {
            await MainActor.run { loading = true }
            let response = try await fetch(nextRequest)
            await MainActor.run {
                update(response)
                loading = false
            }
        } catch {
            print(error)
            await MainActor.run { loading = false }
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
}

// MARK: - View model

class PaginatedPostViewModel: PostProvider, PaginatedLoader, ObservableObject {
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
    var pageWork = [PageID: Work.ID]()
    
    @Published var postIDs = [Post.ID]()
    @Published var postWork = [Post.ID: Work.ID]()

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
        updatePost(response)
        updateLoader(response)
    }
}

class PaginatedMediaViewModel: MediaProvider, PaginatedLoader, ObservableObject {
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
    var postWork = [Post.ID: Work.ID]()
    
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
}

class PaginatedUserViewModel: UserProvider, PaginatedLoader, ObservableObject {
    let fetch: (_: Int) async throws -> GeneralResponse

    var userDict = [User.ID: User]()
    var postDict = [Post.ID: Post]()
    var mediaDict = [Media.ID: Media]()
    var workDict = [Work.ID: Work]()
    var imageDict = [LibraryImage.ID: LibraryImage]()

    var postMedia = [Post.ID: [Media.ID]]()
    var workImages = [Work.ID: [LibraryImage.ID]]()
    var userPosts = [User.ID: [Post.ID]]()
    var postWork = [Post.ID: Work.ID]()
    
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
}

class IndefiniteMediaViewModel: MediaProvider, IndefiniteLoader, ObservableObject {
    let orderByWork: Bool
    let fetch: (_: String?) async throws -> EndpointResponse

    var userDict = [User.ID: User]()
    var postDict = [Post.ID: Post]()
    var mediaDict = [Media.ID: Media]()
    var workDict = [Work.ID: Work]()
    var imageDict = [LibraryImage.ID: LibraryImage]()

    var postMedia = [Post.ID: [Media.ID]]()
    var workImages = [Work.ID: [LibraryImage.ID]]()
    var pageMedia = [PageID: Media.ID]()
    var postWork = [Post.ID: Work.ID]()
    
    @Published var mediaIDs = [Media.ID]()
    @Published var pageWork = [PageID: Work.ID]()

    @Published var startedLoading = false
    @Published var reachedEnd = false
    @Published var loading = false
    var nextOffset: String?

    init(orderByWork: Bool = false, fetch: @escaping (_: String?) async throws -> EndpointResponse) {
        self.orderByWork = orderByWork
        self.fetch = fetch
    }

    func update(_ response: EndpointResponse) {
        updateEntities(response)
        updateMedia(response)
        updateLoader(response)
    }
}
