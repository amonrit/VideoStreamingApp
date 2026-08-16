//
//  StreamAdminViewModel.swift
//  steam
//

import Foundation
import Combine
import os

private let logger = Logger(subsystem: "amonrit.steam", category: "admin")

class StreamAdminViewModel: ObservableObject {
    @Published var paths: [MediaMTXPath] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var lastUpdated: Date?

    // ✅ Phase 5: Use StreamAdminPollingService instead of Timer
    private var streamAdminPollingService: StreamAdminPollingService?

    // ✅ Phase 6: Dependency injection for API client provider
    private let apiClientProvider: APIClientProvider
    private var failureCount: Int = 0
    private let maxFailures: Int = 3

    /// Initializes StreamAdminViewModel with optional custom API client provider
    /// - Parameter apiClientProvider: Custom provider for API clients (defaults to DefaultAPIClientProvider)
    init(apiClientProvider: APIClientProvider = DefaultAPIClientProvider()) {
        self.apiClientProvider = apiClientProvider
        logger.info("📊 StreamAdminViewModel initialized")
    }

    /// Start polling for stream updates
    func startPolling(baseURL: URL? = nil) {
        stopPolling()

        let targetBaseURL = baseURL ?? URL(string: "http://localhost:9997") ?? URL(fileURLWithPath: "")
        // ✅ Phase 6: Use dependency-injected API client provider
        let client = apiClientProvider.createAPIClient(baseURL: targetBaseURL)

        // ✅ Phase 5: Use StreamAdminPollingService instead of Timer
        streamAdminPollingService = StreamAdminPollingService(
            fetchStreams: { [weak self] in
                guard let self = self else { throw PollingError.cancelled }
                // Fetch actual streams
                let pathList = try await client.fetchPathList()
                // Update UI with paths
                await MainActor.run {
                    self.paths = pathList.items
                    self.lastUpdated = Date()
                    self.errorMessage = nil
                    self.failureCount = 0
                    self.isLoading = false
                    logger.info("✅ Fetched \(pathList.items.count) streams")
                }
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
        // ✅ Phase 5: Stop service instead of invalidating Timer
        Task {
            await streamAdminPollingService?.stopPolling()
            streamAdminPollingService = nil
        }
        logger.info("⏹️  Stopped polling")
    }

    deinit {
        // ✅ Phase 5: Stop polling service on dealloc
        Task {
            await streamAdminPollingService?.stopPolling()
        }
        logger.info("🔴 StreamAdminViewModel deinitialized")
    }
}
