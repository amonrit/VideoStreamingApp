import Foundation
import Combine
import AVFoundation

/// Dependency Injection Container
/// Creates ViewModels and shared services for the app. Owned by `AppCoordinator`
/// (one instance per app run) rather than accessed as a global singleton, so
/// call sites can be tested with a container built from mock dependencies.
class DIContainer: ObservableObject {
    // MARK: - Core Dependencies (Lazily Initialized)
    private lazy var urlValidator: URLValidator = URLValidator()
    private lazy var mediaMTXAPIClient: MediaMTXAPIClient = {
        // Default to localhost MediaMTX server
        let baseURL = URL(string: "http://localhost:9997") ?? URL(fileURLWithPath: "")
        return MediaMTXAPIClient(baseURL: baseURL)
    }()

    // MARK: - Repositories (Lazily Initialized)
    private lazy var streamRepository: StreamRepository = {
        let remoteDataSource = StreamRemoteDataSourceImpl(apiClient: mediaMTXAPIClient)
        return StreamRepositoryImpl(remoteDataSource: remoteDataSource)
    }()

    private lazy var streamAdminRepository: StreamAdminRepository = {
        let remoteDataSource = StreamAdminRemoteDataSourceImpl(apiClient: mediaMTXAPIClient)
        return StreamAdminRepositoryImpl(remoteDataSource: remoteDataSource)
    }()

    init() {
        // Initialize container
    }

    // MARK: - Playback Feature Dependencies

    /// Create PlaybackViewModel with all dependencies
    func makePlaybackViewModel(player: AVPlayer = AVPlayer()) -> PlaybackViewModel {
        PlaybackViewModel(player: player)
    }

    /// Get StreamRepository
    func getStreamRepository() -> StreamRepository {
        streamRepository
    }

    // MARK: - StreamAdmin Feature Dependencies

    /// Create StreamAdminViewModel with all dependencies
    func makeStreamAdminViewModel() -> StreamAdminViewModel {
        StreamAdminViewModel()
    }

    /// Get StreamAdminRepository
    func getStreamAdminRepository() -> StreamAdminRepository {
        streamAdminRepository
    }

    // MARK: - Core Services

    /// Get URLValidator
    func getURLValidator() -> URLValidator {
        urlValidator
    }

    /// Get MediaMTXAPIClient
    func getMediaMTXAPIClient() -> MediaMTXAPIClient {
        mediaMTXAPIClient
    }

    // MARK: - Settings Feature Dependencies
    // Will be added as needed
}
