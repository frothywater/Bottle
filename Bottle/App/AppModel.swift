//
//  AppState.swift
//  Bottle
//
//  Created by Cobalt on 12/31/23.
//

import Foundation
import Observation

@Observable
class AppModel {
    var metadata: AppMetadata?
    var feeds = [Feed]()
    var folders = [Folder]()
    var albums = [Album]()
    
    var communityFeeds: [(String, [Feed])] {
        let dict = feeds.reduce(into: [:]) { result, feed in
            result[feed.community, default: []].append(feed)
        }
        return Array(dict).sorted { $0.key < $1.key }
    }
    
    var libraryTree: LibraryEntry? {
        do {
            return try getLibraryTree(albums: albums, folders: folders)
        } catch {
            print(error)
        }
        return nil
    }
    
    func fetchFeeds() async {
        do {
            let metadata = try await Client.fetchMetadata()
            self.metadata = metadata
            feeds = try await Client.fetchFeeds(communityNames: metadata.communities.map(\.name))
        } catch {
            print(error)
        }
    }
    
    func fetchLibrary() async {
        do {
            folders = try await Client.fetchFolders()
            albums = try await Client.fetchAlbums()
        } catch {
            print(error)
        }
    }
    
    func fetchAll() async {
        await fetchFeeds()
        await fetchLibrary()
    }
    
    func album(_ id: Album.ID) -> Album? {
        albums.first { $0.id == id }
    }
    
    func folder(_ id: Folder.ID) -> Folder? {
        folders.first { $0.id == id }
    }
}

// MARK: Helpers

private func getLibraryTree(albums: [Album], folders: [Folder]) throws -> LibraryEntry {
    // Folder dict for quick access
    var folderDict: [Int: Folder] = [:]
    folders.forEach { folderDict[$0.id] = $0 }

    // Create folder tree, nil for the root
    var folderTree: [Int?: FolderEntry] = [nil: .root]
    folders.forEach { folderTree[$0.id] = $0.entry }

    // Add albums to the tree first
    try albums.forEach { album in
        guard folderTree.keys.contains(album.folderId) else {
            throw AppError.invalidData(
                "Album \(String(describing: album.id)) has invalid parent ID \(String(describing: album.folderId))")
        }
        folderTree[album.folderId]!.albums.append(album.entry)
    }
    // Sort folders' albums
    folderTree.keys.forEach { folderID in
        folderTree[folderID]!.albums.sort { $0.position < $1.position }
    }

    // Build folder children relationship, nil for the root
    var childrenIDMap: [Int?: Set<Int>] = [nil: Set()]
    folders.forEach { childrenIDMap[$0.id] = Set() }

    try folders.forEach { folder in
        guard childrenIDMap.keys.contains(folder.parentId) else {
            throw AppError.invalidData(
                "Folder \(String(describing: folder.id)) has invalid parent ID \(String(describing: folder.parentId))")
        }
        childrenIDMap[folder.parentId]!.insert(folder.id)
    }

    // Topological sort to build the tree: iteratively insert leafs to their parent
    var leafIDs = childrenIDMap.keys.filter { childrenIDMap[$0]!.isEmpty }  // A queue of leafs to process
    while !leafIDs.isEmpty {
        guard let currentID = leafIDs.removeFirst() else { break }
        let folder = folderDict[currentID]!
        let parentID = folder.parentId

        // Add folder entry to parent entry in the tree
        let entry = folderTree.removeValue(forKey: currentID)!
        folderTree[parentID]!.folders.append(entry)

        // Remove current node from its parent in childrenIDMap, marking it already added into the tree
        childrenIDMap[parentID]!.remove(currentID)

        if childrenIDMap[parentID]!.isEmpty {
            // If parent is now a leaf, add it to the leafIDs (except the root)
            if parentID != nil { leafIDs.append(parentID) }
            // By the way, sort its children
            folderTree[parentID]!.folders.sort { $0.position < $1.position }
        }
    }

    // Convert root folder to library entry
    return .folder(folderTree[nil]!)
}
