//
//  LibraryTreeRow.swift
//  Bottle
//
//  Created by Cobalt Velvet on 2024/6/25.
//

import SwiftUI

struct LibraryTreeRow: View {
    let entry: LibraryEntry

    var body: some View {
        switch entry {
        case .album(let album): AlbumRow(album: album)
        case .folder(let folder): FolderRow(folder: folder)
        }
    }
}

private struct FolderRow: View {
    let folder: FolderEntry
    
    @State private var renaming = false
    @Environment(\.appModel) var appModel

    var body: some View {
        Group {
            if folder.isRoot {
                Label(folder.name, systemImage: "folder")
            } else {
                RenamableLabel(folder.name, systemImage: "folder", renaming: $renaming) { name in
                    _ = try await Client.renameFolder(folderId: folder.id, name: name)
                    await appModel.fetchLibrary()
                }
            }
        }
        .id(renaming)
        .contextMenu {
            if !folder.isRoot {
                Button("Rename") { renaming = true }
                Button("Delete", action: delete)
            }
            Button("New Album", action: newAlbum)
            Button("New Folder", action: newFolder)
        }
    }

    private func delete() {
        Task {
            do {
                try await Client.deleteFolder(folderId: folder.id)
                await appModel.fetchLibrary()
            } catch {
                print(error)
            }
        }
    }

    private func newAlbum() {
        Task {
            do {
                _ = try await Client.addAlbum(name: "Untitled Album", folderId: folder.isRoot ? nil : folder.id)
                await appModel.fetchLibrary()
            } catch {
                print(error)
            }
        }
    }

    private func newFolder() {
        Task {
            do {
                _ = try await Client.addFolder(name: "Untitled Folder", parentId: folder.isRoot ? nil : folder.id)
                await appModel.fetchLibrary()
            } catch {
                print(error)
            }
        }
    }
}

private struct AlbumRow: View {
    let album: AlbumEntry
    
    @State private var renaming = false
    @State private var targeted = false
    @Environment(\.appModel) var appModel

    var body: some View {
        RenamableLabel(album.name, systemImage: "photo.on.rectangle", renaming: $renaming) { name in
            _ = try await Client.renameAlbum(albumId: album.id, name: name)
            await appModel.fetchLibrary()
        }
        .id(renaming)
        .contextMenu {
            Button("Rename") { renaming = true }
            Button("Delete", action: delete)
        }
        .dropDestination(for: Work.self) { works, location in
            if !works.isEmpty {
                addWorks(works.map(\.id))
                return true
            }
            return false
        } isTargeted: { targeted = $0 }
    }

    private func delete() {
        Task {
            do {
                try await Client.deleteAlbum(albumId: album.id)
                await appModel.fetchLibrary()
            } catch {
                print(error)
            }
        }
    }
    
    private func addWorks(_ ids: [Int]) {
        Task {
            do {
                try await Client.addWorks(albumId: album.id, workIds: ids)
            } catch {
                print(error)
            }
        }
    }
}

private struct RenamableLabel: View {
    let name: String
    let systemImage: String
    @Binding var renaming: Bool
    let action: (String) async throws -> Void

    @State private var draftName: String
    @FocusState private var focused: Bool

    init(_ name: String, systemImage: String, renaming: Binding<Bool>, action: @escaping (String) async throws -> Void) {
        self.name = name
        self.systemImage = systemImage
        self._renaming = renaming
        self.action = action
        self.draftName = name
    }

    var body: some View {
        Group {
            if renaming {
                LabeledContent {
                    TextField("Name", text: $draftName)
                        .focused($focused)
                        .onSubmit {
                            rename()
                        }
                } label: {
                    Image(systemName: systemImage).foregroundColor(.primary)
                }
            } else {
                Group {
                    Label(name, systemImage: systemImage).foregroundColor(.primary)
                }
            }
        }
        .onChange(of: $renaming.wrappedValue, initial: true) {
            if renaming {
                focused = true
            }
        }
        .onChange(of: focused) {
            if !focused {
                renaming = false
            }
        }
    }

    private func rename() {
        Task {
            do {
                try await action(draftName)
            } catch {
                print(error)
                renaming = false
                draftName = name
            }
        }
    }
}

// MARK: Environment

extension EnvironmentValues {
    @Entry var albumID: Album.ID?
}
