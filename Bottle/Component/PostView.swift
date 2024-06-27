//
//  PostView.swift
//  Bottle
//
//  Created by Cobalt on 3/27/24.
//

import Nuke
import NukeUI
import SwiftUI

@MainActor
struct PostView: View {
    let entities: PostEntities
    let model: PostProvider
    
    @State private var browsingUser: User?
    @State private var browsingLibraryUser = false
    @State private var browsingCommunityUser = false

    var body: some View {
        NavigationLink {
            GalleryView(entities: entities, outerModel: model)
        } label: {
            outer
        }
        .buttonStyle(.plain)
        .overlay { RoundedRectangle(cornerRadius: 10).stroke(.separator) }
        .overlay(alignment: .topTrailing) {
            ImportButton(post: entities.post, work: entities.work, outerModel: model)
        }
        .contextMenu { contextMenu }
        .navigationDestination(isPresented: $browsingLibraryUser) {
            if let user = browsingUser {
                userInLibraryDestination(user: user)
            }
        }
        .navigationDestination(isPresented: $browsingCommunityUser) {
            if let user = browsingUser {
                userInCommunityDestination(user: user)
            }
        }
    }

    @ViewBuilder
    private var outer: some View {
        let media = entities.media.first
        let image = entities.images.first { $0.pageIndex == media?.pageIndex }
        let width = media?.width ?? image?.width
        let height = media?.height ?? image?.height
        let url = entities.work?.localThumbnailURL ?? entities.post.thumbnailUrl
        
        LazyImage(request: url?.imageRequest) { state in
            if let image = state.image {
                image.resizable().scaledToFit()
                    .draggable(image)
            } else if state.error != nil {
                Color.clear.overlay { Image(systemName: "photo") }
                    .frame(minHeight: 300)
            } else {
                Color.clear
                    .frame(minHeight: 300)
            }
        }
        .fit(width: width, height: height)
        .overlay(alignment: .bottom) { infoOverlay }
        .contentShape(Rectangle())
        .cornerRadius(10)
    }
    
    @ViewBuilder
    var infoOverlay: some View {
        let title = entities.post.displayText
        let author = users.map { $0.name ?? $0.userId }.joined(separator: ", ")
        if !title.isEmpty || !author.isEmpty {
            VStack(alignment: .leading, spacing: 5) {
                if !title.isEmpty {
                    Text(title).font(.headline)
                        .lineLimit(2, reservesSpace: false)
                        .multilineTextAlignment(.leading)
                }
                if !author.isEmpty {
                    Text(author).font(.subheadline)
                        .lineLimit(1)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
        }
    }
    
    var users: [User] {
        var result = [User]()
        if let user = entities.user { result.append(user) }
        if let users = entities.taggedUsers { result.append(contentsOf: users) }
        return result
    }
    
    @ViewBuilder
    var contextMenu: some View {
        let users = users
        if users.count == 1 {
            let user = users.first!
            Button("Browse \"\(user.name ?? user.userId)\" Works in Library", systemImage: "photo.on.rectangle") {
                browsingUser = user
                browsingLibraryUser = true
            }
            Button("Browse \"\(user.name ?? user.userId)\" Posts at \(user.community.capitalized)", systemImage: "globe") {
                browsingUser = user
                browsingCommunityUser = true
            }
        } else if users.count > 1 {
            Menu("Browse Artist Works in Library", systemImage: "photo.on.rectangle") {
                ForEach(users) { user in
                    Button(user.name ?? user.userId) {
                        browsingUser = user
                        browsingLibraryUser = true
                    }
                }
            }
            Menu("Browse Artist Posts at \(entities.post.community.capitalized)", systemImage: "globe") {
                ForEach(users) { user in
                    Button(user.name ?? user.userId) {
                        browsingUser = user
                        browsingCommunityUser = true
                    }
                }
            }
        }
    }
}

@MainActor
private struct GalleryView: View {
    let entities: PostEntities
    fileprivate var model: GalleryViewModel
    let outerModel: PostProvider
    
    @AppStorage("postViewGridColumnCount") private var columnCount = 3.0
    private var columns: [GridItem] { Array(repeating: GridItem(.flexible()), count: lround(columnCount)) }
    
    init(entities: PostEntities, outerModel: PostProvider) {
        self.entities = entities
        self.model = GalleryViewModel(entities: entities, outerModel: outerModel)
        self.outerModel = outerModel
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                infoArea
                
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(model.items, id: \.index) { item in
                        thumbnail(item: item)
                    }
                }
            }
            .padding(20)
        }
        .safeAreaPadding(.bottom, 10)
        .overlay(alignment: .bottom) { StatusBar(message: model.message, columnCount: $columnCount) }
        .navigationTitle(entities.post.text)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            if !model.hasDetail {
                await model.fetchDetail()
            }
        }
    }
    
    var tagGroups: [(String, [String])] {
        var dict = [String: [String]]()
        
        if let tags = model.post.tags {
            for tag in tags {
                let parts = tag.split(separator: ":")
                let namespace = parts.count == 2 ? String(parts[0]) : "misc"
                let name = parts.count == 2 ? String(parts[1]) : tag
                if dict[namespace] == nil {
                    dict[namespace] = []
                }
                dict[namespace]?.append(name)
            }
        }
        
        for (namespace, _) in dict {
            dict[namespace] = dict[namespace]?.sorted(by: <)
        }
        return dict.sorted { $0.key < $1.key }
    }
    
    @ViewBuilder
    var infoArea: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(model.post.text).font(.system(.title, weight: .semibold))
                    if let englishTitle = model.info?.englishTitle {
                        Text(englishTitle).font(.title3).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                ImportButton(post: entities.post, work: entities.work, outerModel: outerModel)
            }
            
            HStack(alignment: .firstTextBaseline, spacing: 20) {
                VStack(alignment: .leading, spacing: 5) {
                    LabeledContent("Post ID", value: model.post.postId)
                    LabeledContent("Created date", value: model.post.createdDate.formatted())
                    if let work = model.work {
                        LabeledContent("Work ID", value: work.id.formatted())
                        LabeledContent("Added date", value: work.addedDate.formatted())
                    }
                    if let info = model.info {
                        LabeledContent("Category", value: info.category)
                        if !info.uploader.isEmpty { LabeledContent("Uploader", value: info.uploader) }
                        LabeledContent("Media count", value: model.items.count.formatted())
                        if let parent = info.parent, parent != "" { LabeledContent("Parent", value: parent) }
                        if let visible = info.visible { LabeledContent("Visible", value: visible.description) }
                        if let language = info.language { LabeledContent("Language", value: language) }
                        if let fileSize = info.fileSize { LabeledContent("File size", value: fileSize.formatted()) }
                        LabeledContent("Link", value: "\(Const.pandaBaseURL)/g/\(model.post.postId)/\(info.token)")
                    }
                }
                
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(tagGroups, id: \.0) { (namespace, tags) in
                        LabeledContent(namespace.capitalized, value: tags.joined(separator: ", "))
                    }
                }
            }
            .multilineTextAlignment(.trailing)
        }
        .textSelection(.enabled)
    }
    
    func thumbnail(item: GalleryItem) -> some View {
        NavigationLink {
            GalleryReader(model: model, index: item.index)
        } label: {
            VStack(spacing: 10) {
                Group {
                    if item.hasPreview {
                        LazyImage(request: item.previewImageURL?.imageRequest) { state in
                            if let image = state.image {
                                image.resizable().scaledToFit()
                                    .draggable(image)
                            } else if state.error != nil {
                                Color.clear.overlay { Image(systemName: "photo") }
                                    .frame(minHeight: 300)
                            } else {
                                Color.clear.overlay {
                                    VStack(spacing: 10) {
                                        ProgressView()
                                        Text("Loading…").foregroundStyle(.secondary)
                                    }
                                }
                                .frame(minHeight: 300)
                            }
                        }
                        .fit(width: item.width, height: item.height)
                    } else {
                        VStack(spacing: 10) {
                            ProgressView()
                            Text("Fetching…").foregroundStyle(.secondary)
                        }
                        .frame(minHeight: 300)
                        .task(id: item.index) {
                            if model.needFetchPreview(index: item.index) {
                                await model.fetchPreview(index: item.index)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .cornerRadius(10)
                .overlay { RoundedRectangle(cornerRadius: 10).stroke(.separator) }
                
                Text(item.readableIndex.formatted()).font(.caption).foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

@MainActor
private struct GalleryReader: View {
    fileprivate var model: GalleryViewModel
    
    let direction: LayoutDirection = .rightToLeft
    @State private var index: Int
    @State private var showingBar = false
    @State private var prefetched: [Bool]
    
    private let imagePrefetcher: ImagePrefetcher
    
    init(model: GalleryViewModel, index: Int = 0) {
        self.model = model
        self.index = index
        self.prefetched = Array(repeating: false, count: model.items.count)
        self.imagePrefetcher = ImagePrefetcher(maxConcurrentRequestCount: 10)
        self.imagePrefetcher.priority = .normal
    }
    
    private var items: [GalleryItem] {
        switch direction {
        case .rightToLeft:
            model.items.reversed()
        default:
            model.items
        }
    }
    
    var currentItem: GalleryItem { items.first(where: { $0.index == index })! }
    
    var body: some View {
        ZStack {
            #if os(iOS)
            TabView(selection: $index) {
                ForEach(items, id: \.index) { item in
                    GalleryMediaView(item: item, model: model)
                        .onAppear {
                            // Use detached task to avoid cancellation
                            Task { await fetch(index: index) }
                        }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            #else
            GalleryMediaView(item: currentItem, model: model)
                .onAppear {
                    Task { await fetch(index: index) }
                }
            #endif
            
            tapDetection
        }
        .onChange(of: index) {
            Task { await fetch(index: index) }
        }
        .overlay(alignment: .bottom) { if showingBar { bar } }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
    
    private var tapDetection: some View {
        GeometryReader { proxy in
            ZStack {
                HStack {
                    Color.clear
                        .frame(width: proxy.size.width / 2)
                        .contentShape(Rectangle())
                        .onTapGesture { if index < items.count - 1 { index += 1 } }
                    Color.clear
                        .frame(width: proxy.size.width / 2)
                        .contentShape(Rectangle())
                        .onTapGesture { if index > 0 { index -= 1 } }
                }
                Color.clear
                    .frame(width: proxy.size.width / 3, height: proxy.size.height / 3)
                    .contentShape(Rectangle())
                    .onTapGesture { showingBar.toggle() }
            }
        }
    }
    
    private var bar: some View {
        HStack(spacing: 20) {
            switch direction {
            case .rightToLeft:
                slider.flipped()
            default:
                slider
            }
            Text((index + 1).formatted())
        }
        .padding(.horizontal, 15)
        .frame(height: 50)
        .background(.thinMaterial)
    }
    
    private var slider: some View {
        Slider(value: Binding<Float>(get: { Float($index.wrappedValue) }, set: { $index.wrappedValue = Int($0) }),
               in: 0...Float(items.count - 1), step: 1)
    }
    
    private func fetch(index: Int, prefetchCount: Int = 10) async {
        let endIndex = min(index + prefetchCount, items.count)
            
        await withTaskGroup(of: Void.self) { group in
            group.addTask(priority: .high) { await fetchOne(index: index) }
            for index in (index + 1)..<endIndex {
                group.addTask { await fetchOne(index: index) }
            }
        }
    }
    
    private func fetchOne(index: Int) async {
        if model.needFetchImage(index: index) {
            await model.fetchImage(index: index)
        }
        prefetchImage(index: index)
    }
    
    private func prefetchImage(index: Int) {
        if !prefetched[index], let request = model.items[index].imageURL?.imageRequest {
            if !ImagePipeline.shared.cache.containsCachedImage(for: request) {
                print("Prefetching image \(index)")
                imagePrefetcher.startPrefetching(with: [request])
            }
            prefetched[index] = true
        }
    }
}

@MainActor
private struct GalleryMediaView: View {
    let item: GalleryItem
    fileprivate var model: GalleryViewModel
    
    var body: some View {
        if let url = item.imageURL {
            LazyImage(request: url.imageRequest) { state in
                if let image = state.image {
                    image.resizable().scaledToFit()
                        .draggable(image)
                } else if state.error != nil {
                    Image(systemName: "photo")
                } else {
                    VStack(spacing: 10) {
                        Text(item.readableIndex.formatted()).font(.headline)
                        ProgressView()
                        Text("Loading…").foregroundStyle(.secondary)
                    }
                }
            }
            .zoomable()
        } else {
            VStack(spacing: 10) {
                Text(item.readableIndex.formatted()).font(.headline)
                ProgressView()
                Text("Fetching…").foregroundStyle(.secondary)
            }
        }
    }
}

@MainActor
private struct ImportButton: View {
    let post: Post
    let work: Work?
    let outerModel: PostProvider
    @State var operating = false

    private var imported: Bool { work != nil }
    private var symbol: String { imported ? "bookmark.fill" : "bookmark" }

    var body: some View {
        Button(action: toggle) {
            Circle().fill(.thinMaterial)
                .overlay {
                    if operating {
                        ProgressView().scaleEffect(0.5)
                    } else {
                        Image(systemName: symbol)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.orange)
                    }
                }
        }
        .buttonStyle(.plain)
        .frame(width: 32, height: 32)
        .padding(5)
        .animation(.default, value: imported)
        .animation(.default, value: operating)
        .disabled(operating)
    }

    private func toggle() {
        guard !operating else { return }
        Task {
            defer { operating = false }
            operating = true
            do {
                if imported {
                    guard let workID = work?.id else { return }
                    try await Client.deleteWork(workID: workID)
                    outerModel.deleteWork(workID, for: post.id)
                } else {
                    let response = try await Client.addWork(community: post.community, postID: post.postId, page: nil)
                    outerModel.updateEntities(response)
                }
            } catch {
                print(error)
            }
        }
    }
}

// MARK: - ViewModel

private struct GalleryItem {
    let index: Int
    let media: Media?
    let image: LibraryImage?
    
    var previewImageURL: String? { image?.localThumbnailURL ?? image?.localSmallThumbnailURL ?? media?.thumbnailUrl }
    var imageURL: String? { image?.localURL ?? image?.localThumbnailURL ?? media?.url }
    
    var hasPreview: Bool { previewImageURL != nil }
    var hasImage: Bool { imageURL != nil }
    
    var width: Int? { image?.width ?? media?.width }
    var height: Int? { image?.height ?? media?.height }
    
    var readableIndex: Int { index + 1 }
    
    func withMedia(_ newMedia: Media) -> GalleryItem {
        GalleryItem(index: index, media: newMedia, image: image)
    }

    func withUpdatedMedia(_ newMedia: Media) -> GalleryItem {
        GalleryItem(index: index, media: Media(
            mediaId: media?.mediaId ?? newMedia.mediaId,
            community: media?.community ?? newMedia.community,
            postId: media?.postId ?? newMedia.postId,
            pageIndex: media?.pageIndex ?? newMedia.pageIndex,
            url: newMedia.url,
            width: newMedia.width,
            height: newMedia.height,
            thumbnailUrl: media?.thumbnailUrl ?? newMedia.thumbnailUrl,
            extra: media?.extra ?? newMedia.extra
        ), image: image)
    }
}

private enum GalleryPreviewPageState {
    case empty, loading, loaded
}

@Observable
@MainActor
private class GalleryViewModel {
    var user: User?
    var post: Post
    var work: Work?
    var items: [GalleryItem]
    
    var outerModel: PostProvider
    
    var pageSize: Int
    var loadingItem: [Bool] = []
    var pageStates: [GalleryPreviewPageState]
    
    private static let defaultPageSize = 20
    
    init(entities: PostEntities, outerModel: PostProvider) {
        self.user = entities.user
        self.post = entities.post
        self.work = entities.work
        self.outerModel = outerModel
        
        // Put media and images into an item array in correct order
        let items = Self.getItems(post: entities.post, media: entities.media, images: entities.images)
        self.items = items
        self.loadingItem = Array(repeating: false, count: entities.post.mediaCount ?? entities.media.count)
        // Prepare preview page states
        self.pageSize = Self.defaultPageSize
        self.pageStates = Self.getPageStates(items: items, pageSize: Self.defaultPageSize)
    }
    
    var info: PandaGalleryExtra? {
        if case .some(.panda(let extra)) = post.extra {
            return extra
        }
        return nil
    }
    
    var hasDetail: Bool { info?.fileSize != nil }
    
    var thumbnailURL: String? { work?.localThumbnailURL ?? post.thumbnailUrl }
    
    var message: String {
        let hasPreviewItems = items.filter(\.hasPreview).count
        let hasImageItems = items.filter(\.hasImage).count
        let loadedPages = pageStates.filter { $0 == .loaded }.count
        return "\(loadedPages)/\(pageStates.count) pages, \(items.count) items. (\(hasPreviewItems) previews, \(hasImageItems) images)"
    }
    
    private static func getItems(post: Post, media: [Media], images: [LibraryImage]) -> [GalleryItem] {
        let mediaCount = post.mediaCount ?? media.count
        let mediaDict = media.reduce(into: [Int: Media]()) { dict, media in dict[media.pageIndex] = media }
        let imageDict = images.reduce(into: [Int: LibraryImage]()) { dict, image in dict[image.pageIndex] = image }
        return (0..<mediaCount).map { index in GalleryItem(index: index, media: mediaDict[index], image: imageDict[index]) }
    }
    
    private static func getPageStates(items: [GalleryItem], pageSize: Int) -> [GalleryPreviewPageState] {
        let pageCount = Int(max((items.count + pageSize - 1) / pageSize, 1))

        return (0..<pageCount).map { page in
            let start = page * pageSize
            let end = min(start + pageSize, items.count)
            let anyWithoutPreview = items[start..<end].contains { !$0.hasPreview }
            return anyWithoutPreview ? .empty : .loaded
        }
    }
    
    func fetchDetail() async {
        guard !pageStates.isEmpty, pageStates[0] == .empty else { return }
        
        do {
            pageStates[0] = .loading
            print("Fetching detail for post \(post.postId)")
            let response = try await Client.fetchPandaPost(id: post.postId)
            
            if let post = response.posts?.first {
                self.post = post
            }
            if let media = response.media {
                updateMedia(media: media)
            }
            if let count = response.media?.count, count > pageSize {
                // Update actual page count and initialize page states again
                pageSize = count
                pageStates = Self.getPageStates(items: items, pageSize: pageSize)
            }
            
            // Update post and media in outer post view model
            outerModel.updateEntities(responseToUpdate)
            
            pageStates[0] = .loaded
        } catch {
            print(error)
            pageStates[0] = .empty
        }
    }
    
    func needFetchPreview(index: Int) -> Bool {
        let pageIndex = Int(index / pageSize)
        return pageStates.indices.contains(pageIndex) && pageStates[pageIndex] == .empty
    }
    
    func fetchPreview(index: Int) async {
        let pageIndex = Int(index / pageSize)
        guard needFetchPreview(index: index) else { return }
        
        do {
            pageStates[pageIndex] = .loading
            print("Fetching preview for post \(post.postId), page \(pageIndex), media, \(index)")
            let response = try await Client.fetchPandaPost(id: post.postId, page: pageIndex)
            
            if let media = response.media {
                updateMedia(media: media)
            }
            
            // Update media in outer post view model
            outerModel.updateEntities(responseToUpdate)
            
            pageStates[pageIndex] = .loaded
        } catch {
            print(error)
            pageStates[pageIndex] = .empty
        }
    }
    
    func needFetchImage(index: Int) -> Bool {
        let pageIndex = Int(index / pageSize)
        return pageStates.indices.contains(pageIndex) && pageStates[pageIndex] == .loaded &&
            items.indices.contains(index) && !loadingItem[index] && !items[index].hasImage
    }
    
    func fetchImage(index: Int) async {
        let pageIndex = Int(index / pageSize)
        guard pageStates.indices.contains(pageIndex) else { return }
        if pageStates[pageIndex] == .empty {
            await fetchPreview(index: index)
        }
        
        guard needFetchImage(index: index) else { return }

        do {
            loadingItem[index] = true
            print("Fetching image for post \(post.postId), media \(index)")
            let response = try await Client.fetchPandaMedia(id: post.postId, page: index)
            
            if let media = response.media?.first {
                updateSingleMedia(media: media)
            }
            
            // Update media in outer post view model
            outerModel.updateEntities(responseToUpdate)
            
            loadingItem[index] = false
        } catch {
            print(error)
            loadingItem[index] = false
        }
    }
    
    private func updateMedia(media: [Media]) {
        if items.count != post.mediaCount {
            // Inconsistent media count, initialize items again
            let allMedia = items.compactMap(\.media) + media
            let images = items.compactMap(\.image)
            items = Self.getItems(post: post, media: allMedia, images: images)
        } else {
            // Number correct, update the items
            for m in media {
                guard items.indices.contains(m.pageIndex) else { continue }
                items[m.pageIndex] = items[m.pageIndex].withMedia(m)
            }
        }
    }
    
    private func updateSingleMedia(media: Media) {
        guard items.indices.contains(media.pageIndex) else { return }
        items[media.pageIndex] = items[media.pageIndex].withUpdatedMedia(media)
    }
    
    private var responseToUpdate: EndpointResponse {
        .init(posts: [post], media: items.compactMap(\.media), users: nil, works: nil, images: nil, reachedEnd: false, nextOffset: nil, totalItems: nil)
    }
}
