//
//  Client.swift
//  Bottle
//
//  Created by Cobalt on 9/8/23.
//

import Foundation

let defaultPageSize = 30

struct Client {
    static func fetchMetadata() async throws -> AppMetadata {
        let data = try await call(path: "/metadata")
        return try decode(data)
    }

    static func fetchFeeds(communityNames: [String]) async throws -> [Feed] {
        return try await withThrowingTaskGroup(of: [Feed].self) { group -> [Feed] in
            for name in communityNames {
                group.addTask {
                    let data = try await call(path: "/\(name)/feeds")
                    return try decode(data)
                }
            }
            return try await group.reduce(into: [Feed]()) { partial, feeds in
                partial.append(contentsOf: feeds)
            }
        }
    }

    static func fetchPosts(community: String, feedID: Int, page: Int = 0) async throws -> GeneralResponse {
        let data = try await call(path: "/\(community)/feed/\(feedID)/posts?page=\(page)&page_size=\(defaultPageSize)")
        return try decode(data)
    }

    static func fetchCommunityWorks(community: String, page: Int = 0) async throws -> GeneralResponse {
        let data = try await call(path: "/\(community)/works?page=\(page)&page_size=\(defaultPageSize)")
        return try decode(data)
    }

    static func fetchWorks(page: Int = 0) async throws -> GeneralResponse {
        let data = try await call(path: "/works?page=\(page)&page_size=\(defaultPageSize)")
        return try decode(data)
    }

    static func addWork(community: String, postID: String, page: Int?) async throws -> GeneralResponse {
        let path = "/\(community)/post/\(postID)/work" + (page.map { "?page=\($0)" } ?? "")
        let data = try await call(.post, path: path)
        return try decode(data)
    }

    static func deleteWork(workID: Int) async throws {
        _ = try await call(.delete, path: "/work/\(workID)")
    }

    static func fetchFeedUsers(community: String, feedID: Int, page: Int = 0) async throws -> GeneralResponse {
        let data = try await call(
            path: "/\(community)/feed/\(feedID)/users?page=\(page)&page_size=\(defaultPageSize)&recent_count=5")
        return try decode(data)
    }

    static func fetchFeedUserPosts(community: String, feedID: Int, userID: String, page: Int = 0) async throws
        -> GeneralResponse
    {
        let data = try await call(
            path: "/\(community)/feed/\(feedID)/user/\(userID)?page=\(page)&page_size=\(defaultPageSize)")
        return try decode(data)
    }

    static func fetchArchivedUsers(community: String, page: Int = 0) async throws -> GeneralResponse {
        let data = try await call(
            path: "/\(community)/work/users?page=\(page)&page_size=\(defaultPageSize)&recent_count=5")
        return try decode(data)
    }

    static func fetchArchivedUserPosts(community: String, userID: String, page: Int = 0) async throws -> GeneralResponse
    {
        let data = try await call(path: "/\(community)/work/user/\(userID)?page=\(page)&page_size=\(defaultPageSize)")
        return try decode(data)
    }

    static func fetchTemporaryFeed(community: String, request: EndpointRequest) async throws -> EndpointResponse {
        let data = try await call(.post, path: "/\(community)/api", body: request)
        return try decode(data)
    }

    static func fetchPandaPost(id: String, page: Int = 0) async throws -> EndpointResponse {
        let data = try await call(path: "/panda/api/post/\(id)?page=\(page)")
        return try decode(data)
    }

    static func fetchPandaMedia(id: String, page: Int, session: URLSession = .shared) async throws -> EndpointResponse {
        let data = try await call(path: "/panda/api/post/\(id)/media/\(page)")
        return try decode(data)
    }

    static func addAlbum(name: String, folderId: Int?) async throws -> Album {
        var path = "/album?name=\(name)"
        if let folderId = folderId { path += "&folder_id=\(folderId)" }
        let data = try await call(.post, path: path)
        return try decode(data)
    }

    static func fetchAlbums() async throws -> [Album] {
        let data = try await call(path: "/albums")
        return try decode(data)
    }

    static func renameAlbum(albumId: Int, name: String) async throws -> Album {
        let data = try await call(.post, path: "/album/\(albumId)/rename?name=\(name)")
        return try decode(data)
    }

    static func deleteAlbum(albumId: Int) async throws {
        _ = try await call(.delete, path: "/album/\(albumId)")
    }

    static func addWorks(albumId: Int, workIds: [Int]) async throws {
        let ids = workIds.map { String($0) }.joined(separator: ",")
        _ = try await call(.post, path: "/album/\(albumId)/works?work_ids=\(ids)")
    }

    static func fetchWorks(albumId: Int, page: Int = 0) async throws -> GeneralResponse {
        let data = try await call(path: "/album/\(albumId)/works?page=\(page)&page_size=\(defaultPageSize)")
        return try decode(data)
    }

    static func removeWorks(albumId: Int, workIds: [Int]) async throws {
        let ids = workIds.map { String($0) }.joined(separator: ",")
        _ = try await call(.delete, path: "/album/\(albumId)/works?work_ids=\(ids)")
    }

    static func addFolder(name: String, parentId: Int?) async throws -> Folder {
        var path = "/folder?name=\(name)"
        if let parentId = parentId { path += "&parent_id=\(parentId)" }
        let data = try await call(.post, path: path)
        return try decode(data)
    }

    static func fetchFolders() async throws -> [Folder] {
        let data = try await call(path: "/folders")
        return try decode(data)
    }

    static func renameFolder(folderId: Int, name: String) async throws -> Folder {
        let data = try await call(.post, path: "/folder/\(folderId)/rename?name=\(name)")
        return try decode(data)
    }

    static func deleteFolder(folderId: Int) async throws {
        _ = try await call(.delete, path: "/folder/\(folderId)")
    }

    // MARK: - Helper

    static func getServerURL() -> String? {
        UserDefaults.standard.string(forKey: "serverAddress")
    }

    static func newCookie(key: String, value: String, domain: String) -> HTTPCookie {
        HTTPCookie(properties: [
            .name: key,
            .value: value,
            .domain: domain,
            .path: "/",
            .secure: "TRUE",
            .expires: NSDate(timeIntervalSinceNow: TimeInterval(60 * 60 * 24 * 365)),
        ])!
    }

    static func pandaCookies(ipbMemberID: String, ipbPassHash: String, igneous: String?) -> [HTTPCookie] {
        var result = [HTTPCookie]()
        result.append(newCookie(key: "ipb_member_id", value: ipbMemberID, domain: Const.pandaDomain))
        result.append(newCookie(key: "ipb_pass_hash", value: ipbPassHash, domain: Const.pandaDomain))
        if let igneous = igneous {
            result.append(newCookie(key: "igneous", value: igneous, domain: Const.pandaDomain))
        }
        return result
    }
}

private enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case delete = "DELETE"
}

private func call(_ method: HTTPMethod = .get, path: String, body: Encodable? = nil, session: URLSession = .shared) async throws -> Data {
    guard let baseURL = Client.getServerURL() else {
        throw AppError.invalidServer
    }
    var request = URLRequest(url: URL(string: baseURL + path)!)
    request.httpMethod = method.rawValue
    if let body = body {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        print(String(data: request.httpBody!, encoding: .utf8)!)
    }
    let (data, response) = try await session.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse,
        (200...299).contains(httpResponse.statusCode)
    else {
        throw AppError.badStatus(
            code: (response as? HTTPURLResponse)?.statusCode,
            content: String(data: data, encoding: .utf8))
    }
    return data
}

private func decode<T: Decodable>(_ data: Data) throws -> T {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    //    decoder.dateDecodingStrategy = .formatted(formatter)
    decoder.dateDecodingStrategy = .iso8601
    return try decoder.decode(T.self, from: data)
}
