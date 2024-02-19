//
//  Response.swift
//  Bottle
//
//  Created by Cobalt on 9/8/23.
//

import CoreTransferable
import Foundation
import Nuke

// MARK: - Entities

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
    let userId: String?
    let text: String
    let thumbnailUrl: String?
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
    let postCount: Int?
}

struct Media: Decodable {
    let mediaId: String
    let community: String
    let postId: String
    let pageIndex: Int
    let url: String?
    let width: Int?
    let height: Int?
    let thumbnailUrl: String?
}

struct Work: Decodable, Identifiable {
    let id: Int
    let community: String?
    let postId: String?
    let pageIndex: Int?
    let asArchive: Bool
    let name: String?
    let caption: String?
    let favorite: Bool
    let rating: Int
    let thumbnailPath: String?
    let addedDate: Date
    let modifiedDate: Date
    let viewedDate: Date?
}

struct LibraryImage: Decodable, Identifiable {
    let id: Int
    let workId: Int
    let pageIndex: Int?
    let filename: String
    let remoteUrl: String?
    let path: String?
    let thumbnailPath: String?
    let width: Int?
    let height: Int?
    let size: Int?
}

// MARK: - Response

protocol EntityContainer {
    var posts: [Post]? { get }
    var media: [Media]? { get }
    var users: [User]? { get }
    var works: [Work]? { get }
    var images: [LibraryImage]? { get }
}

protocol PaginatedResponse {
    var totalItems: Int { get }
    var page: Int { get }
    var pageSize: Int { get }
}

protocol IndefiniteResponse {
    var reachedEnd: Bool { get }
    var nextOffset: String? { get }
}

struct GeneralResponse: EntityContainer, PaginatedResponse, Decodable  {
    let posts: [Post]?
    let media: [Media]?
    let users: [User]?
    let works: [Work]?
    let images: [LibraryImage]?

    let totalItems: Int
    let page: Int
    let pageSize: Int

    static let empty = GeneralResponse(posts: nil, media: nil, users: nil, works: nil, images: nil,
                                       totalItems: 0, page: 0, pageSize: 0)
}

struct EndpointResponse: EntityContainer, IndefiniteResponse, Decodable {
    let posts: [Post]?
    let media: [Media]?
    let users: [User]?
    let works: [Work]?
    let images: [LibraryImage]?

    let reachedEnd: Bool
    let nextOffset: String?

    static let empty = EndpointResponse(posts: nil, media: nil, users: nil, works: nil, images: nil,
                                        reachedEnd: false, nextOffset: nil)
}

// MARK: - Scheme

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

// MARK: - Extensions

/// ID of community and feed for sidebar selection.
enum SidebarDestination: Hashable {
    case community(String)
    case feed(community: String, id: Int)
}

extension CommunityMetadata {
    var destination: SidebarDestination { .community(name) }
}

extension Feed {
    var destination: SidebarDestination { .feed(community: community, id: feedId) }
}

extension CommunityMetadata: Identifiable {
    var id: String { name }
}

extension Feed: Identifiable {
    struct FeedID: Hashable {
        let community: String
        let name: String
    }

    var id: FeedID { .init(community: community, name: name) }
}

extension User: Identifiable {
    struct UserID: Hashable {
        let community: String
        let userId: String
    }

    var id: UserID { .init(community: community, userId: userId) }
}

extension Post: Identifiable {
    struct PostID: Hashable {
        let community: String
        let postId: String
    }

    var id: PostID { .init(community: community, postId: postId) }
    var userID: User.ID? { userId.map { .init(community: community, userId: $0) } }
}

extension Media: Identifiable {
    struct MediaID: Hashable {
        let community: String
        let mediaId: String
    }

    var id: MediaID { .init(community: community, mediaId: mediaId) }
    var postID: Post.ID { .init(community: community, postId: postId) }
}

extension Work {
    var postID: Post.ID? {
        guard let community = community, let postId = postId else { return nil }
        return .init(community: community, postId: postId)
    }
}

/// Global page ID for media and work.
struct PageID: Hashable {
    let community: String
    let postId: String
    let pageIndex: Int
}

extension Media {
    var pageID: PageID { PageID(community: community, postId: postId, pageIndex: pageIndex) }
}

extension Work {
    var pageID: PageID? {
        guard let community = community, let postId = postId, let pageIndex = pageIndex else { return nil }
        return PageID(community: community, postId: postId, pageIndex: pageIndex)
    }
}

extension LibraryImage {
    func pageID(for work: Work) -> PageID? {
        guard let community = work.community, let postId = work.postId, let pageIndex = pageIndex else { return nil }
        return PageID(community: community, postId: postId, pageIndex: pageIndex)
    }
}

extension LibraryImage {
    var localURL: String? {
        guard let baseURL = getServerURL() else { return nil }
        return "\(baseURL)/image/\(id)"
    }
}
