# Bottle.app

An iOS/macOS client built with SwiftUI that provides a unified interface for browsing feeds, organizing media collections from multiple illustration social platforms. Serves as the frontend of the Bottle project. The backend is at ([`bottle-rs`](https://github.com/frothywater/bottle-rs)).

## Features

- **Feeds**: Browse multiple illustration platforms in a unified feed interface. User can subscribe to different types of feeds (timeline, bookmarks, etc.) from different platforms. Bottle tracks them and updates new contents.
- **Library**: Manage favorite illustration by adding them from feeds to the library, and organizes them in a tree hierarchy of albums and folders, with drag-and-drop support.
- **Artist View**: Browse works grouped by artists across different platforms, and in both community source and personal library contexts, to appreciate unique styles of different artists. The artist view is supported by the native 3-column layout in SwiftUI. Also, browse the community posts and the saved works of any artist with a context menu.
- **Media Viewing**:
  - Photos.app-like grid layout with adjustable density for immersive experience.
  - View media in the optimized gallery viewer for both single and multi-image posts such as manga.
  - Browse illustration's metadata in the information pane.
  - Progressive JPEG support and image caching for more responsive browsing.
- **Background Jobs**: Monitor and trigger background jobs of feed updates and media downloads.
- **Native Experience**: Built with SwiftUI, the app enjoys a smooth, responsive, and visually consistent native experience.

## Architecture & Technology

One of the technical motivations of this app is to learn to build with modern Apple technologies and follow contemporary iOS/macOS development practices.

The app's core architecture is based on MVVM (Model-View-ViewModel), with ViewModels being bridges connecting data models and views. All ViewModels conforms to [`ObservableObject`](https://developer.apple.com/documentation/combine/observableobject) so that views can subscribe to data changes.

ViewModels play key roles in both two directions: (1) accept user's requests and load the needed data, and (2) parse and aggregate the response from backend and provide necessary data to update the view. For clearer code organization, these two roles are split and abstracted to two separate sets of protocols: `ContentLoader` and `EntityProvider`:
- `ContentLoader`s are responsible for loading contents that are either paginated (with known count) or indefinite. The behaviors are provided by the default implementations of `PaginatedLoader` and `IndefiniteLoader`, respectively.
- `EntityProvider`s are responsible for aggregate backend responses, which may contain flattened entities (posts, media, works, images, users) with one-to-many/many-to-many relationships. And for different kind of views, the relationships that the aggregation relies on are different. There are 3 kinds of entity providers: `PostProvider`, `MediaProvider` and `UserProvider`.

By conforming to any combination of the two set of protocols (with default implementation), concrete ViewModel classes can be easily constructed for different view purposes.

Besides, there are other dedicated ViewModels such as `AppModel` for the global app state and `GalleryViewModel` for the multi-image viewer.

Core technologies used in the app:
- **SwiftUI**: The declarative UI framework.
- **Async/Await**: Utilize Swift's structured concurrency for network operations.
- [Observation](https://developer.apple.com/documentation/observation) Framework: Use the new `@Observable` macro for simple state management without the need of `Combine`. Only used in `AppModel` for experiment for now.
- [Core Transferable](https://developer.apple.com/documentation/coretransferable) Framework: Support drag and drop in a modern Swift approach.
- [Nuke](https://kean.blog/nuke/home): Efficient image loading and caching.

## Structure

- `App/`
  - `BottleApp.swift`: App entry point.
  - `ContentView.swift`: Core navigation logic for 2-column/3-column layout with sidebar.
  - `AppModel.swift`: Global state management for the app.
  - `ViewModel.swift`: Core protocols and implementations for ViewModels.
- `Component/`: UI components for feed/library browsing and management. Important ones are:
  -  `PostView`-`PostGrid` for multi-image works like manga,
  -  `MediaView`-`MediaGrid` for illustrations,
  -  and `UserList` for artist view.
- `Data/`
  - `Client.swift`: Network communication layer with the backend server.
  - `Response.swift`: Data models and entity definitions, with extensions.
  - `Request.swift`: API request structures and parameters.
- `Util/`: Helper extensions and utility functions, including image/URL handling and some fallback codes (UIKit/AppKit).

## Caveats

Although SwiftUI has been growing these years, some critical functionalities are still missing or difficult to implement right. (And the infamous bad Apple documentation problem is true.) So I have to use some workarounds for now, which includes:
- Fallback to UIKit/AppKit for smooth zooming and panning gesture in the image viewer.
- Fix on nested ScrollView problem on macOS: [source](https://stackoverflow.com/questions/64920744/swiftui-nested-scrollviews-problem-on-macos).
- Navigation cababilities provided by SwiftUI are somewhat limited. Switching between 2-column and 3-column layouts of `NavigationSplitView` will loss the states. Also, `NavigationStack` must be nested in the `NavigationSplitView` to support inner navigation, which is not elegant and may cause problems.
- Some behaviors are not consistent among platforms (iOS and macOS), such as the zooming gesture mentioned before.