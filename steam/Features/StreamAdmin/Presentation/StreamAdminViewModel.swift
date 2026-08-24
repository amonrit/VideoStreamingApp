//
//  StreamAdminViewModel.swift
//  steam
//

import Foundation
import os

private let logger = Logger(subsystem: "amonrit.steam", category: "admin")

@MainActor
@Observable
final class StreamAdminViewModel {
    // MARK: - Observed Properties (synced from StreamAdminStateActor)
    var paths: [MediaMTXPath] = []
    var isLoading: Bool = false
    var errorMessage: String?
    var lastUpdated: Date?

    private let stateActor: DefaultStreamAdminStateActor
    // `nonisolated(unsafe)` only to permit reading these two from `deinit`,
    // which runs nonisolated and can't touch @MainActor-isolated storage
    // directly (plain `nonisolated` isn't accepted on a mutable stored
    // property). Both types are already Sendable (Task, and
    // StreamAdminPollingService as an actor), so this doesn't weaken any
    // actual safety — it only opts out of isolation *checking*.
    // `@ObservationIgnored` because neither is UI-facing state the way
    // `paths`/`isLoading`/etc. above are.
    @ObservationIgnored
    private nonisolated(unsafe) var stateObserverTask: Task<Void, Never>?

    @ObservationIgnored
    private nonisolated(unsafe) var streamAdminPollingService: StreamAdminPollingService?

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

    // MARK: - State Observation
    /// Observes state changes from the actor and mirrors them into the
    /// `@Observable`-tracked stored properties above.
    private func startStateObserver() {
        stateObserverTask = Task {
            for await state in stateActor.stateUpdates {
                syncObservedProperties(from: state)
            }
        }
    }

    /// Synchronizes the observed properties from actor state.
    /// Called whenever the state actor updates.
    private func syncObservedProperties(from state: StreamAdminStateSnapshot) {
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
            await streamAdminPollingService?.startPolling()
            logger.info("📊 Started polling with StreamAdminPollingService")
        }
    }

    /// Stop polling for updates
    func stopPolling() {
        Task {
            await streamAdminPollingService?.stopPolling()
            streamAdminPollingService = nil
        }
        logger.info("⏹️  Stopped polling")
    }

    deinit {
        stateObserverTask?.cancel()

        // Capture the service itself, not `self` — by the time this Task runs,
        // `self` has already finished deinitializing, so `[weak self]` would
        // always read nil here and silently skip the cleanup.
        if let service = streamAdminPollingService {
            Task {
                await service.stopPolling()
            }
        }

        logger.info("🔴 StreamAdminViewModel deinitialized")
    }
}
