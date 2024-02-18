//
//  Client.swift
//  Bottle
//
//  Created by Cobalt on 9/8/23.
//

import Foundation

let defaultPageSize = 100

func fetchMetadata() async throws -> AppMetadata {
    let data = try await call(path: "/metadata")
    return try decode(data)
}

func fetchFeeds(communityNames: [String]) async throws -> [Feed] {
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

func fetchPosts(community: String, feedID: Int, page: Int = 0) async throws -> GeneralResponse {
    let data = try await call(path: "/\(community)/feed/\(feedID)/posts?page=\(page)&page_size=\(defaultPageSize)")
    return try decode(data)
}

func fetchCommunityWorks(community: String, page: Int = 0) async throws -> GeneralResponse {
    let data = try await call(path: "/\(community)/works?page=\(page)&page_size=\(defaultPageSize)")
    return try decode(data)
}

func fetchWorks(page: Int = 0) async throws -> GeneralResponse {
    let data = try await call(path: "/works?page=\(page)&page_size=\(defaultPageSize)")
    return try decode(data)
}

func addWork(community: String, postID: String, page: Int?) async throws -> GeneralResponse {
    let path = "/\(community)/post/\(postID)/work" + (page.map { "?page=\($0)" } ?? "")
    let data = try await call(.post, path: path)
    return try decode(data)
}

func deleteWork(workID: Int) async throws {
    _ = try await call(.delete, path: "/work/\(workID)")
}

func fetchFeedUsers(community: String, feedID: Int, page: Int = 0) async throws -> GeneralResponse {
    let data = try await call(path: "/\(community)/feed/\(feedID)/users?page=\(page)&page_size=30&recent_count=5")
    return try decode(data)
}

func fetchFeedUserPosts(community: String, feedID: Int, userID: String, page: Int = 0) async throws -> GeneralResponse {
    let data = try await call(path: "/\(community)/feed/\(feedID)/user/\(userID)?page=\(page)&page_size=\(defaultPageSize)")
    return try decode(data)
}

func fetchArchivedUsers(community: String, page: Int = 0) async throws -> GeneralResponse {
    let data = try await call(path: "/\(community)/work/users?page=\(page)&page_size=30&recent_count=5")
    return try decode(data)
}

func fetchArchivedUserPosts(community: String, userID: String, page: Int = 0) async throws -> GeneralResponse {
    let data = try await call(path: "/\(community)/work/user/\(userID)?page=\(page)&page_size=\(defaultPageSize)")
    return try decode(data)
}

// MARK: - Helper

func getServerURL() -> String? {
    UserDefaults.standard.string(forKey: "serverAddress")
}

private enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case delete = "DELETE"
}

private func call(_ method: HTTPMethod = .get, path: String) async throws -> Data {
    guard let baseURL = getServerURL() else {
        throw AppError.invalidServer
    }
    var request = URLRequest(url: URL(string: baseURL + path)!)
    request.httpMethod = method.rawValue
    let (data, response) = try await URLSession.shared.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse,
          (200 ... 299).contains(httpResponse.statusCode)
    else {
        throw AppError.badStatus(code: (response as? HTTPURLResponse)?.statusCode,
                                 content: String(data: data, encoding: .utf8))
    }
    return data
}

private func decode<T: Decodable>(_ data: Data) throws -> T {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    decoder.dateDecodingStrategy = .formatted(formatter)
    return try decoder.decode(T.self, from: data)
}
