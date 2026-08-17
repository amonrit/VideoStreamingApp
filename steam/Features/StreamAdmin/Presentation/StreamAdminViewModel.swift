//
//  StreamAdminViewModel.swift
//  steam
//

import Foundation
import Combine
import os

private let logger = Logger(subsystem: "amonrit.steam", category: "admin")

class StreamAdminViewModel: ObservableObject {
    // MARK: - @Published Properties (Bridge to StateActor)
    /// ✅ Phase 7: These are now synchronized from StreamAdminStateActor
    /// Kept for backward compatibility with existing SwiftUI views
    @Published var paths: [MediaMTXPath] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var lastUpdated: Date?

    private let stateActor: DefaultStreamAdminStateActor
    private var stateObserverTask: Task<Void, Never>?

    private var streamAdminPollingService: StreamAdminPollingService?

    private let apiClientProvider: APIClientProvider
    private var failureCount: Int = 0
    private let maxFailures: Int = 3

    /// Initializes StreamAdminViewModel with optional custom API client provider and state actor
    /// - Parameters:
    ///   - apiClientProvider: Custom provider for API clients (defaults to DefaultAPIClientProvider)
    ///   - stateActor: Custom state actor for testing (defaults to DefaultStreamAdminStateActor)
    init(
        apiClientProvider: APIClientProvider = DefaultAPIClientProvider(),
        stateActor: DefaultStreamAdminStateActor = DefaultStreamAdminStateActor()
    ) {
        self.apiClientProvider = apiClientProvider
        self.stateActor = stateActor
        logger.info("📊 StreamAdminViewModel initialized")

        startStateObserver()
    }

    // MARK: - Phase 7: State Observation
    /// Starts observing state changes from the actor and syncing to @Published properties
    /// This bridges structured concurrency (actor) with Combine (@Published) for backward compatibility
    private func startStateObserver() {
        stateObserverTask = Task {
            for await state in stateActor.stateUpdates {
                // Sync all state changes to @Published properties on main thread
                await MainActor.run { [weak self] in
                    self?.syncPublishedProperties(from: state)
                }
            }
        }
    }

    /// Synchronizes @Published properties from actor state
    /// Called whenever the state actor updates
    private func syncPublishedProperties(from state: StreamAdminStateSnapshot) {
        self.paths = state.paths
        self.isLoading = state.isLoading
        self.errorMessage = state.errorMessage
        self.lastUpdated = state.lastUpdateTime
    }

    /// Start polling for stream updates
    func startPolling(baseURL: URL? = nil) {
        stopPolling()

        let targetBaseURL = baseURL ?? URL(string: "http://localhost:9997") ?? URL(fileURLWithPath: "")

        Task {
            await stateActor.updateBaseURL(targetBaseURL)
            await stateActor.updateLoading(true)
        }

        let client = apiClientProvider.createAPIClient(baseURL: targetBaseURL)

        streamAdminPollingService = StreamAdminPollingService(
            fetchStreams: { [weak self] in
                guard let self = self else { throw PollingError.cancelled }
                // Fetch actual streams
                let pathList = try await client.fetchPathList()

                await self.stateActor.updatePaths(pathList.items)
                await self.stateActor.updateLastUpdateTime(Date())
                await self.stateActor.updateError(nil)
                await self.stateActor.updateLoading(false)

                logger.info("✅ Fetched \(pathList.items.count) streams")
                return pathList.items.count
            }
        )

        Task {
            streamAdminPollingService?.startPolling()
            logger.info("📊 Started polling with StreamAdminPollingService")
        }
    }

    /// Stop polling for updates
    func stopPolling() {
        Task {
            streamAdminPollingService?.stopPolling()
            streamAdminPollingService = nil
        }
        logger.info("⏹️  Stopped polling")
    }

    deinit {
        stateObserverTask?.cancel()

        let service = streamAdminPollingService
        if service != nil {
            Task { [weak self] in
                await self?.streamAdminPollingService?.stopPolling()
            }
        }

        logger.info("🔴 StreamAdminViewModel deinitialized")
    }
}
