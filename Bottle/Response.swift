//
//  Response.swift
//  Bottle
//
//  Created by Cobalt on 9/8/23.
//

import CoreTransferable
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
    let thumbnailUrl: String?
    let media: [Media]?
    let work: Work?
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
    let url: String?
    let width: Int?
    let height: Int?
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
    let posts: [Post]
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

extension CommunityMetadata: Identifiable {
    var id: String { "community_" + name }
}

extension CommunityMetadata: Hashable {
    static func == (lhs: CommunityMetadata, rhs: CommunityMetadata) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension Account: Identifiable {
    var id: String {
        community + String(accountId)
    }
}

extension Feed: Identifiable {
    var id: String {
        "feed_\(community)_\(feedId)"
    }
}

extension Feed: Hashable {
    static func == (lhs: Feed, rhs: Feed) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
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
    let index: Int?

    var id: String {
        if let index = index { "\(inner.id):\(index)" } else { inner.id }
    }
}

struct LocalImage: Decodable, Identifiable {
    let id: Int
    let width: Int
    let height: Int
    let filename: String

    var url: URL? {
        guard let baseURL = getServerURL() else { return nil }
        return URL(string: baseURL + "/image/\(id)")
    }
}

extension Post {
    var postMedia: [PostMedia] {
        if let media = media {
            return media.enumerated().map { index, media in PostMedia(inner: media, postID: postId, index: index) }
        } else {
            // Temporary workaround for posts that have no media (panda)
            return [PostMedia(
                inner: Media(mediaId: community + postId, community: community, url: nil, width: nil, height: nil, thumbnailUrl: thumbnailUrl, work: nil),
                postID: postId, index: nil)]
        }
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
    var localURL: String? {
        if let image = work?.images.first, image.path != nil {
            guard let baseURL = getServerURL() else { return nil }
            return baseURL + "/image/\(image.id)"
        } else {
            return url
        }
    }

    var localThumbnailURL: String? {
        if let image = work?.images.first, image.path != nil {
            guard let baseURL = getServerURL() else { return nil }
            return baseURL + "/image/\(image.id)"
        } else {
            return thumbnailUrl
        }
    }
}

extension LibraryImage {
    var localImage: LocalImage? {
        guard let width = width, let height = height else { return nil }
        return LocalImage(id: id, width: width, height: height, filename: filename)
    }
}

extension String {
    var imageRequest: ImageRequest? {
        guard let url = URL(string: self) else { return nil }
        if contains("pximg.net") {
            var urlRequest = URLRequest(url: url)
            urlRequest.setValue("https://www.pixiv.net", forHTTPHeaderField: "Referer")
            return ImageRequest(urlRequest: urlRequest)
        } else {
            return ImageRequest(url: url)
        }
    }

    var filename: String? {
        guard let url = URL(string: self) else { return nil }
        return url.lastPathComponent
    }
}

extension UserWithRecent: Identifiable {
    var id: String { user.id }
}

extension UserWithRecent: Hashable {
    static func == (lhs: UserWithRecent, rhs: UserWithRecent) -> Bool {
        lhs.user.community == rhs.user.community && lhs.user.userId == rhs.user.userId
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(user.community)
        hasher.combine(user.userId)
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

extension Paginated where Item == Post {
    var asPostMedia: Pagination<PostMedia> {
        Pagination<PostMedia>(
            items: items.flatMap { post in post.postMedia },
            page: page, pageSize: pageSize, totalItems: totalItems, totalPages: totalPages)
    }
}

extension Pagination<Work> {
    var asLocalImage: Pagination<LocalImage> {
        Pagination<LocalImage>(
            items: items.flatMap { work in work.images.compactMap(\.localImage) },
            page: page, pageSize: pageSize, totalItems: totalItems, totalPages: totalPages)
    }
}

extension UserPostPagination {
    var asLocalImage: Pagination<LocalImage> {
        let media = items.compactMap(\.media).joined()
        let images = media.compactMap(\.work).flatMap(\.images)
        return Pagination<LocalImage>(
            items: images.compactMap(\.localImage),
            page: page, pageSize: pageSize, totalItems: totalItems, totalPages: totalPages)
    }
}
