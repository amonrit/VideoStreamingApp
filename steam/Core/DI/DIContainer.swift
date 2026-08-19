import Foundation
import Combine
import AVFoundation

/// Dependency Injection Container
/// Creates ViewModels and shared services for the app. Owned by `AppCoordinator`
/// (one instance per app run) rather than accessed as a global singleton, so
/// call sites can be tested with a container built from mock dependencies.
class DIContainer: ObservableObject {
    init() {
        // Initialize container
    }

    // MARK: - Playback Feature Dependencies

    /// Create PlaybackViewModel with all dependencies
    func makePlaybackViewModel(player: AVPlayer = AVPlayer()) -> PlaybackViewModel {
        PlaybackViewModel(player: player)
    }

    // MARK: - StreamAdmin Feature Dependencies

    /// Create StreamAdminViewModel with all dependencies
    func makeStreamAdminViewModel() -> StreamAdminViewModel {
        StreamAdminViewModel()
    }

    // MARK: - Settings Feature Dependencies
    // Will be added as needed
}
