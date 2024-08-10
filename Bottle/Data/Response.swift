//
//  Response.swift
//  Bottle
//
//  Created by Cobalt on 9/8/23.
//

import Foundation

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
    let name: String?
    let watching: Bool
    let description: String
}

struct Post: Decodable {
    let postId: String
    let community: String
    let userId: String?
    let text: String
    let mediaCount: Int?
    let thumbnailUrl: String?
    let tags: [String]?
    let createdDate: Date
    let addedDate: Date?
    let extra: PostExtra?
}

struct User: Decodable {
    let userId: String
    let community: String
    let name: String?
    let username: String?
    let tagName: String?
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
    let extra: MediaExtra?
}

struct Work: Codable, Identifiable {
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
    let smallThumbnailPath: String?
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
    let smallThumbnailPath: String?
    let width: Int?
    let height: Int?
    let size: Int?
}

struct Album: Decodable, Identifiable {
    let id: Int
    let name: String
    let folderId: Int?
    let position: Int
    let addedDate: Date
    let modifiedDate: Date
}

struct Folder: Decodable, Identifiable {
    let id: Int
    let name: String
    let parentId: Int?
    let position: Int
    let addedDate: Date
    let modifiedDate: Date
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
    var totalItems: Int? { get }
}

struct GeneralResponse: EntityContainer, PaginatedResponse, Decodable {
    let posts: [Post]?
    let media: [Media]?
    let users: [User]?
    let works: [Work]?
    let images: [LibraryImage]?

    let totalItems: Int
    let page: Int
    let pageSize: Int
}

struct EndpointResponse: EntityContainer, IndefiniteResponse, Decodable {
    let posts: [Post]?
    let media: [Media]?
    let users: [User]?
    let works: [Work]?
    let images: [LibraryImage]?

    let reachedEnd: Bool
    let nextOffset: String?
    let totalItems: Int?
}

// MARK: - Extra
enum PostExtra: Decodable {
    case pixiv(PixivIllustExtra)
    case yandere(YanderePostExtra)
    case panda(PandaGalleryExtra)

    private enum CodingKeys: String, CodingKey {
        case pixiv, yandere, panda
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let pixivExtra = try container.decodeIfPresent(PixivIllustExtra.self, forKey: .pixiv) {
            self = .pixiv(pixivExtra)
        } else if let yandereExtra = try container.decodeIfPresent(YanderePostExtra.self, forKey: .yandere) {
            self = .yandere(yandereExtra)
        } else if let pandaExtra = try container.decodeIfPresent(PandaGalleryExtra.self, forKey: .panda) {
            self = .panda(pandaExtra)
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: [], debugDescription: "Invalid PostExtra"))
        }
    }
}

enum MediaExtra: Decodable {
    case twitter(type: String)
    case panda(token: String)
}

struct PixivIllustExtra: Decodable {
    let title: String
    let type: String
    let restrict: Bool
    let sanityLevel: Int
    let seriesId: Int?
    let seriesTitle: String?
}

struct YanderePostExtra: Decodable {
    let creatorId: Int?
    let author: String
    let source: String
    let rating: String
    let fileSize: Int
    let hasChildren: Bool
    let parentId: Int?
}

struct PandaGalleryExtra: Decodable {
    let token: String
    let category: String
    let uploader: String
    let rating: Float
    let englishTitle: String?
    let parent: String?
    let visible: Bool?
    let language: String?
    let fileSize: Int?
}

// MARK: - Scheme

indirect enum Scheme {
    case null, bool, int, bigint, double, string
    case option(Scheme)
    case array(Scheme)
    case object([String: Scheme])
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
                throw DecodingError.dataCorruptedError(
                    forKey: .option, in: container, debugDescription: "Invalid scheme")
            }
        }
    }
}

// MARK: - Extensions

/// ID of community and feed for sidebar selection.
enum SidebarDestination: Hashable {
    case community(String)
    case feed(community: String, id: Int)
    case album(id: Int)
    case folder(id: Int)
}

extension CommunityMetadata {
    var destination: SidebarDestination { .community(name) }
}

extension Feed {
    var displayName: String { name ?? description }
    var destination: SidebarDestination { .feed(community: community, id: feedId) }
}

extension CommunityMetadata: Identifiable {
    var id: String { name }
}

extension Feed: Identifiable {
    struct FeedID: Hashable {
        let community: String
        let feedId: Int
    }

    var id: FeedID { .init(community: community, feedId: feedId) }
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

extension Post {
    var displayText: String {
        let result =
            if text.contains("https://") {
                String(text.split(separator: "https://", omittingEmptySubsequences: false).first ?? "")
            } else {
                text
            }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension Media: Identifiable {
    struct MediaID: Hashable {
        let community: String
        let mediaId: String
    }

    var id: MediaID { .init(community: community, mediaId: mediaId) }
    var postID: Post.ID { .init(community: community, postId: postId) }
}

extension Media {
    var displayWidth: Int? { community != "pixiv" ? width : nil }
    var displayHeight: Int? { community != "pixiv" ? height : nil }
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

extension Work {
    var localThumbnailURL: String? {
        guard let baseURL = Client.getServerURL(), let thumbnailPath = thumbnailPath else { return nil }
        return "\(baseURL)/image/\(thumbnailPath.percentEncoded)"
    }

    var localSmallThumbnailURL: String? {
        guard let baseURL = Client.getServerURL(), let smallThumbnailPath = smallThumbnailPath else { return nil }
        return "\(baseURL)/image/\(smallThumbnailPath.percentEncoded)"
    }
}

extension LibraryImage {
    var localURL: String? {
        guard let baseURL = Client.getServerURL(), let path = path else { return nil }
        return "\(baseURL)/image/\(path.percentEncoded)"
    }

    var localThumbnailURL: String? {
        guard let baseURL = Client.getServerURL(), let thumbnailPath = thumbnailPath else { return nil }
        return "\(baseURL)/image/\(thumbnailPath.percentEncoded)"
    }

    var localSmallThumbnailURL: String? {
        guard let baseURL = Client.getServerURL(), let smallThumbnailPath = smallThumbnailPath else { return nil }
        return "\(baseURL)/image/\(smallThumbnailPath.percentEncoded)"
    }
}

enum LibraryEntry: Hashable, Identifiable {
    case album(AlbumEntry)
    case folder(FolderEntry)

    var id: SidebarDestination {
        switch self {
        case .album(let album): return .album(id: album.id)
        case .folder(let folder): return .folder(id: folder.id)
        }
    }
    
    var children: [LibraryEntry]? {
        switch self {
        case .album(_): return nil
        case .folder(let folder): return folder.children
        }
    }
}

struct AlbumEntry: Identifiable, Hashable {
    let id: Int
    let name: String
    let position: Int
    let addedDate: Date
    let modifiedDate: Date
}

struct FolderEntry: Identifiable, Hashable {
    let id: Int
    let name: String
    let position: Int
    let addedDate: Date
    let modifiedDate: Date
    var folders: [FolderEntry]
    var albums: [AlbumEntry]

    var children: [LibraryEntry] {
        folders.map { .folder($0) } + albums.map { .album($0) }
    }
    
    var isRoot: Bool { id == 0 }

    static let root = FolderEntry(
        id: 0, name: "Albums", position: 0, addedDate: Date(), modifiedDate: Date(), folders: [], albums: [])
}

extension Album {
    var entry: AlbumEntry {
        AlbumEntry(id: id, name: name, position: position, addedDate: addedDate, modifiedDate: modifiedDate)
    }
}

extension Folder {
    var entry: FolderEntry {
        FolderEntry(
            id: id, name: name, position: position, addedDate: addedDate, modifiedDate: modifiedDate, folders: [],
            albums: [])
    }
}
