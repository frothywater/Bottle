//
//  Response.swift
//  Bottle
//
//  Created by Cobalt on 9/8/23.
//

import Foundation
import Nuke

indirect enum Scheme {
    case null, bool, int, bigint, double, string, option(Scheme), array(Scheme), object([String: Scheme])
}

extension Scheme: Decodable {
    enum NestingKeys: String, CodingKey {
        case option = "Optional"
        case array = "Array"
        case object = "Object"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            switch value {
            case "Null": self = .null
            case "Bool": self = .bool
            case "Int": self = .int
            case "Bigint": self = .bigint
            case "Double": self = .double
            case "String": self = .string
            default: throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid scheme")
            }
        } else {
            let container = try decoder.container(keyedBy: NestingKeys.self)
            if let value = try container.decodeIfPresent(Scheme.self, forKey: .option) {
                self = .option(value)
            } else if let value = try container.decodeIfPresent(Scheme.self, forKey: .array) {
                self = .array(value)
            } else if let value = try container.decodeIfPresent([String: Scheme].self, forKey: .object) {
                self = .object(value)
            } else {
                throw DecodingError.dataCorruptedError(forKey: .option, in: container, debugDescription: "Invalid scheme")
            }
        }
    }
}

struct AppMetadata: Decodable {
    let communities: [CommunityMetadata]
}

struct CommunityMetadata: Decodable {
    let name: String
    let feeds: [FeedMetadata]
    let account: AccountMetadata?
}

struct AccountMetadata: Decodable {
    let credentialScheme: Scheme
    let canFetchInfo: Bool
    let needRefresh: Bool
}

struct FeedMetadata: Decodable {
    let name: String
    let scheme: Scheme
    let needAuth: Bool
}

struct Account: Decodable {
    let accountId: Int
    let community: String
}

struct AccountInfo: Decodable {
    let name: String?
    let username: String?
    let avatarUrl: String?
}

struct Feed: Decodable {
    let feedId: Int
    let community: String
    let name: String
}

struct Post: Decodable {
    let postId: String
    let community: String
    let user: User?
    let text: String
    let media: [Media]
    let createdDate: Date
    let addedDate: Date
}

struct User: Decodable {
    let userId: String
    let community: String
    let name: String?
    let username: String?
    let avatarUrl: String?
    let description: String?
    let url: String?
}

struct Media: Decodable {
    let mediaId: String
    let community: String
    let url: String
    let width: Int
    let height: Int
    let thumbnailUrl: String?
    let work: Work?
}

struct Work: Decodable {
    let id: Int
    let community: String?
    let postId: String?
    let pageIndex: Int?
    let images: [LibraryImage]
    let asArchive: Bool
    let name: String?
    let caption: String?
    let favorite: Bool
    let rating: Int
    let thumbnailPath: String?
    let addedDate: Date
    let modifiedDate: Date
    let viewdDate: Date?
}

struct LibraryImage: Decodable {
    let id: Int
    let pageIndex: Int?
    let filename: String
    let remoteUrl: String?
    let path: String?
    let thumbnailPath: String?
    let width: Int?
    let height: Int?
    let size: Int?
}

struct UserWithRecent: Decodable {
    let user: User
    let post: [Post]
    let totalPosts: Int
}

struct Pagination<T: Decodable>: Decodable {
    let items: [T]
    let page: Int
    let pageSize: Int
    let totalItems: Int
    let totalPages: Int
}

struct UserPostPagination: Decodable {
    let user: User
    let items: [Post]
    let page: Int
    let pageSize: Int
    let totalItems: Int
    let totalPages: Int
}

// MARK: - Extensions

extension Account: Identifiable {
    var id: String {
        community + String(accountId)
    }
}

extension Feed: Identifiable {
    var id: String {
        community + String(feedId)
    }
}

extension Feed: Hashable {
    static func == (lhs: Feed, rhs: Feed) -> Bool {
        lhs.community == rhs.community && lhs.feedId == rhs.feedId
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(community)
        hasher.combine(feedId)
    }
}

extension Post: Identifiable {
    var id: String {
        community + postId
    }
}

struct PostMedia: Decodable, Identifiable {
    let inner: Media
    let postID: String
    let index: Int
    
    var id: String {
        "\(inner.id):\(index)"
    }
}

extension Post {
    var postMedia: [PostMedia] {
        media.enumerated().map { index, media in PostMedia(inner: media, postID: postId, index: index) }
    }
}

extension User: Identifiable {
    var id: String {
        community + userId
    }
}

extension Media: Identifiable {
    var id: String {
        community + mediaId
    }
}

extension Media {
    var thumbnailRequest: ImageRequest? {
        guard let thumbnailUrl = thumbnailUrl, let url = URL(string: thumbnailUrl) else { return nil }
        if thumbnailUrl.contains("pximg.net") {
            var urlRequest = URLRequest(url: url)
            urlRequest.setValue("https://www.pixiv.net", forHTTPHeaderField: "Referer")
            return ImageRequest(urlRequest: urlRequest)
        } else {
            return ImageRequest(url: url)
        }
    }

    var urlRequest: ImageRequest? {
        guard let url = URL(string: url) else { return nil }
        if self.url.contains("pximg.net") {
            var urlRequest = URLRequest(url: url)
            urlRequest.setValue("https://www.pixiv.net", forHTTPHeaderField: "Referer")
            return ImageRequest(urlRequest: urlRequest)
        } else {
            return ImageRequest(url: url)
        }
    }
}

protocol Paginated {
    associatedtype Item
    var items: [Item] { get }
    var page: Int { get }
    var pageSize: Int { get }
    var totalItems: Int { get }
    var totalPages: Int { get }
}

extension Pagination: Paginated {}

extension UserPostPagination: Paginated {}

extension Pagination<Post> {
    var asPostMedia: Pagination<PostMedia> {
        Pagination<PostMedia>(
            items: items.flatMap { post in post.postMedia },
            page: page, pageSize: pageSize, totalItems: totalItems, totalPages: totalPages)
    }
}
