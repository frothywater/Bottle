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
        default:
            return nil
        }
    }
}
