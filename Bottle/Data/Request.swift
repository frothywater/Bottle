//
//  Request.swift
//  Bottle
//
//  Created by Cobalt on 2/20/24.
//

import Foundation

struct EndpointRequest: Encodable {
    let params: EndpointParams
    let offset: String?
}

enum EndpointParams: Encodable {
    case twitter(TwitterParams)
    case pixiv(PixivParams)
    case yandere(YandereParams)
    case panda(PandaParams)

    // Flatten the enum for encoding
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .twitter(params):
            try container.encode(params)
        case let .pixiv(params):
            try container.encode(params)
        case let .yandere(params):
            try container.encode(params)
        case let .panda(params):
            try container.encode(params)
        }
    }
}

enum TwitterParams: Encodable {
    case timeline
    case bookmarks
    case likes(userId: Int)
    case posts(userId: Int)
    case list(listId: Int)
    case search(query: String)
}

enum PixivParams: Encodable {
    case timeline(restriction: FollowingRestriction)
    case bookmarks(userId: Int, tag: String?, restriction: Restriction)
    case posts(userId: Int, type: IllustType)
    case search(query: String)

    enum Restriction: String, Encodable {
        case `public` = "Public", `private` = "Private"
    }

    enum FollowingRestriction: String, Encodable {
        case `public` = "Public", `private` = "Private", all = "All"
    }

    enum IllustType: String, Encodable {
        case illust = "Illust", manga = "Manga", ugoira = "Ugoira"
    }
}

enum YandereParams: Encodable {
    case search(query: String)
    case pool(poolId: Int)
}

enum PandaParams: Encodable {
    case search(option: SearchOption)
    case favorites(option: FavoriteSearchOption)
    
    struct SearchOption: Encodable {
        let keyword: String?
        let categories: [GalleryCategory]
        let searchName: Bool
        let searchTags: Bool
        let searchDescription: Bool
        let searchTorrent: Bool
        let searchLowPowerTags: Bool
        let searchDownvotedTags: Bool
        let searchExpunged: Bool
        let requireTorrent: Bool
        let disableLanguageFilter: Bool
        let disableUploaderFilter: Bool
        let disableTagsFilter: Bool
        let minRating: Int?
        let minPages: Int?
        let maxPages: Int?
        
        init(keyword: String? = nil, categories: [PandaParams.GalleryCategory] = GalleryCategory.allCases, searchName: Bool = true, searchTags: Bool = true, searchDescription: Bool = false, searchTorrent: Bool = false, searchLowPowerTags: Bool = false, searchDownvotedTags: Bool = false, searchExpunged: Bool = false, requireTorrent: Bool = false, disableLanguageFilter: Bool = false, disableUploaderFilter: Bool = false, disableTagsFilter: Bool = false, minRating: Int? = nil, minPages: Int? = nil, maxPages: Int? = nil) {
            self.keyword = keyword
            self.categories = categories
            self.searchName = searchName
            self.searchTags = searchTags
            self.searchDescription = searchDescription
            self.searchTorrent = searchTorrent
            self.searchLowPowerTags = searchLowPowerTags
            self.searchDownvotedTags = searchDownvotedTags
            self.searchExpunged = searchExpunged
            self.requireTorrent = requireTorrent
            self.disableLanguageFilter = disableLanguageFilter
            self.disableUploaderFilter = disableUploaderFilter
            self.disableTagsFilter = disableTagsFilter
            self.minRating = minRating
            self.minPages = minPages
            self.maxPages = maxPages
        }
    }
    
    struct FavoriteSearchOption: Encodable {
        let keyword: String?
        let categoryIndex: Int?
        let searchName: Bool
        let searchTags: Bool
        let searchNote: Bool
        
        init(keyword: String? = nil, categoryIndex: Int? = nil, searchName: Bool = true, searchTags: Bool = true, searchNote: Bool = true) {
            self.keyword = keyword
            self.categoryIndex = categoryIndex
            self.searchName = searchName
            self.searchTags = searchTags
            self.searchNote = searchNote
        }
    }
    
    enum GalleryCategory: String, Encodable, CaseIterable {
        case misc = "Misc"
        case doujinshi = "Doujinshi"
        case manga = "Manga"
        case artistCG = "ArtistCG"
        case gameCG = "GameCG"
        case imageSet = "ImageSet"
        case cosplay = "Cosplay"
        case asianPorn = "AsianPorn"
        case nonH = "NonH"
        case western = "Western"
    }
}

// MARK: - Helpers

extension User {
    var feedParams: EndpointParams? {
        switch community {
        case "twitter":
            guard let username = username else { return nil }
            return .twitter(.search(query: "from:\(username) filter:media -filter:replies -filter:retweets -filter:quotes"))
        case "pixiv":
            guard let userId = Int(userId) else { return nil }
            return .pixiv(.posts(userId: userId, type: .illust))
        case "yandere":
            return .yandere(.search(query: userId))
        case "panda":
            return .panda(.search(option: .init(keyword: "artist:\"\(userId)$\"")))
        default:
            return nil
        }
    }
}
