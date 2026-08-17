import Foundation
import Combine
import AVFoundation

/// Dependency Injection Container
/// Manages creation and injection of all dependencies across the app
class DIContainer: ObservableObject {
    // MARK: - Singleton Instance
    static let shared = DIContainer()

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

    private init() {
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
