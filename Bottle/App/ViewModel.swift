//
//  ViewModel.swift
//  Bottle
//
//  Created by Cobalt on 2/8/24.
//

import Foundation

class ViewModel: ObservableObject {
    var userDict = [User.ID: User]()
    var postDict = [Post.ID: Post]()
    var mediaDict = [Media.ID: Media]()
    var workDict = [Work.ID: Work]()
    var imageDict = [LibraryImage.ID: LibraryImage]()

    var postMedia = [Post.ID: [Media.ID]]()
    var workImages = [Work.ID: [LibraryImage.ID]]()
    /// Currently only support single-image works
    var pageWork = [PageID: Work.ID]()

    @Published var page = 0
    @Published var pageSize: Int?
    @Published var totalItems: Int?

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

    func update(_ response: GeneralResponse) {
        page = response.page + 1
        if !startedLoading {
            pageSize = response.pageSize
            totalItems = response.totalItems
        }

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

    func reset() {
        userDict = [:]
        postDict = [:]
        mediaDict = [:]
        workDict = [:]
        imageDict = [:]
        postMedia = [:]
        workImages = [:]
        page = 0
        pageSize = nil
        totalItems = nil
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

class MediaViewModel: ViewModel {
    let orderByWork: Bool
    @Published var mediaIDs = [Media.ID]()
    var postWorks = [Post.ID: [Work.ID]]()
    var pageMedia = [PageID: Media.ID]()
    
    init(orderByWork: Bool) {
        self.orderByWork = orderByWork
    }

    override func update(_ response: GeneralResponse) {
        super.update(response)
        
        // Map post to works
        postWorks.merge(response.works?.map { ($0.postID, $0.id) })

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

    override func reset() {
        super.reset()
        mediaIDs = []
        postWorks = [:]
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
        postWorks[media.postID]?.removeAll { $0 == workID }
    }
}

class UserViewModel: ViewModel {
    @Published var userIDs = [User.ID]()
    var userPosts = [User.ID: [Post.ID]]()

    override func update(_ response: GeneralResponse) {
        super.update(response)
        
        // Map user to posts
        userPosts.merge(response.posts?.map { ($0.userID, $0.id) })
        
        userIDs.append(contentsOf: response.users?.map(\.id) ?? [])
    }
    
    override func reset() {
        super.reset()
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
