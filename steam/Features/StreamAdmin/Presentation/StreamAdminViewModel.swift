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

    private var refreshTimer: Timer?
    private let apiClient: MediaMTXAPIClient?
    private let refreshInterval: TimeInterval = 4.0
    private var failureCount: Int = 0
    private let maxFailures: Int = 3

    init() {
        // Try to initialize API client — if no valid server is found, it will be nil
        // and the view will show a "configure server" message
        self.apiClient = nil  // Will be set lazily if needed

        logger.info("📊 StreamAdminViewModel initialized")
    }

    /// Start polling for stream updates
    func startPolling(baseURL: URL? = nil) {
        stopPolling()

        let targetBaseURL = baseURL ?? URL(string: "http://localhost:9997") ?? URL(fileURLWithPath: "")
        let client = MediaMTXAPIClient(baseURL: targetBaseURL)

        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            self?.refresh(client: client)
        }

        // Fetch immediately
        refresh(client: client)
        logger.info("📊 Started polling at \(self.refreshInterval)s intervals")
    }

    /// Stop polling for updates
    func stopPolling() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        logger.info("⏹️  Stopped polling")
    }

    /// Manually refresh stream list
    private func refresh(client: MediaMTXAPIClient) {
        Task { [weak self] in
            do {
                let pathList = try await client.fetchPathList()
                await MainActor.run {
                    self?.paths = pathList.items
                    self?.lastUpdated = Date()
                    self?.errorMessage = nil
                    self?.failureCount = 0
                    self?.isLoading = false
                    logger.info("✅ Fetched \(pathList.items.count) streams")
                }
            } catch {
                await MainActor.run {
                    self?.failureCount += 1
                    let errorMsg = "Failed to fetch streams: \(error.localizedDescription)"
                    logger.warning("⚠️  \(errorMsg, privacy: .public)")

                    // Keep showing old data on transient failure
                    if self?.failureCount ?? 0 >= self?.maxFailures ?? 3 {
                        self?.errorMessage = errorMsg
                        self?.paths = []
                    }
                    self?.isLoading = false
                }
            }
        }
    }

    deinit {
        stopPolling()
        logger.info("🔴 StreamAdminViewModel deinitialized")
    }
}
