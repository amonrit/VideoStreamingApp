//
//  StreamAdminStateActor.swift
//  steam
//
//  Actor-based state management for stream admin using structured concurrency.
//  Provides thread-safe state updates for the StreamAdminViewModel.
//

import Foundation

// MARK: - State Snapshot

/// State snapshot for stream administration
/// Conforms to Sendable for thread-safe passing across actors
public struct StreamAdminStateSnapshot: Sendable {
    public var isLoading: Bool
    public var errorMessage: String?
    public var paths: [MediaMTXPath]
    public var selectedPath: MediaMTXPath?
    public var baseURL: URL?
    public var isOnline: Bool
    public var totalViewers: Int
    public var lastUpdateTime: Date

    public init(
        isLoading: Bool = false,
        errorMessage: String? = nil,
        paths: [MediaMTXPath] = [],
        selectedPath: MediaMTXPath? = nil,
        baseURL: URL? = nil,
        isOnline: Bool = false,
        totalViewers: Int = 0,
        lastUpdateTime: Date = Date()
    ) {
        self.isLoading = isLoading
        self.errorMessage = errorMessage
        self.paths = paths
        self.selectedPath = selectedPath
        self.baseURL = baseURL
        self.isOnline = isOnline
        self.totalViewers = totalViewers
        self.lastUpdateTime = lastUpdateTime
    }

    public static func == (lhs: StreamAdminStateSnapshot, rhs: StreamAdminStateSnapshot) -> Bool {
        lhs.isLoading == rhs.isLoading &&
        lhs.errorMessage == rhs.errorMessage &&
        lhs.paths.count == rhs.paths.count &&
        lhs.selectedPath?.name == rhs.selectedPath?.name &&
        lhs.baseURL == rhs.baseURL &&
        lhs.isOnline == rhs.isOnline &&
        lhs.totalViewers == rhs.totalViewers
    }
}

// MARK: - Protocol

/// Protocol for stream admin state actor to enable testing with mocks
public protocol StreamAdminStateActorProtocol: AnyObject, Sendable {
    var currentState: StreamAdminStateSnapshot { get }
    var stateUpdates: AsyncStream<StreamAdminStateSnapshot> { get }

    func updateLoading(_ value: Bool) async
    func updateError(_ message: String?) async
    func updatePaths(_ paths: [MediaMTXPath]) async
    func updateSelectedPath(_ path: MediaMTXPath?) async
    func updateBaseURL(_ url: URL?) async
    func updateOnline(_ value: Bool) async
    func updateTotalViewers(_ count: Int) async
    func updateLastUpdateTime(_ time: Date) async
    func reset() async
}

// MARK: - Main Actor Implementation

/// Actor-based state management for stream admin
/// - Isolates state to actor domain
/// - Provides AsyncStream for reactive updates
/// - Thread-safe state mutations
///
/// Usage:
/// ```swift
/// let stateActor = DefaultStreamAdminStateActor()
///
/// // Update state
/// await stateActor.updateLoading(true)
///
/// // Observe updates
/// for await state in await stateActor.stateUpdates {
///     print("Paths updated: \(state.paths.count)")
/// }
/// ```
public final actor DefaultStreamAdminStateActor {
    // MARK: - Properties

    private var _state: StreamAdminStateSnapshot

    private nonisolated let stateSubject: (
        stream: AsyncStream<StreamAdminStateSnapshot>,
        continuation: AsyncStream<StreamAdminStateSnapshot>.Continuation
    )

    public var currentState: StreamAdminStateSnapshot { _state }

    nonisolated public var stateUpdates: AsyncStream<StreamAdminStateSnapshot> { stateSubject.stream }

    // MARK: - Initialization

    public init(initialState: StreamAdminStateSnapshot = .init()) {
        self._state = initialState
        self.stateSubject = AsyncStream.makeStream()
    }

    // MARK: - State Mutations

    /// Updates loading state and broadcasts change
    public func updateLoading(_ value: Bool) {
        guard _state.isLoading != value else { return }
        _state.isLoading = value
        broadcast()
    }

    /// Updates error message and broadcasts change
    public func updateError(_ message: String?) {
        guard _state.errorMessage != message else { return }
        _state.errorMessage = message
        broadcast()
    }

    /// Updates paths list and broadcasts change
    public func updatePaths(_ paths: [MediaMTXPath]) {
        guard _state.paths.count != paths.count else { return }
        _state.paths = paths

        // Auto-update totalViewers
        let newTotalViewers = paths.reduce(0) { $0 + $1.viewerCount }
        _state.totalViewers = newTotalViewers

        broadcast()
    }

    /// Updates selected path and broadcasts change
    public func updateSelectedPath(_ path: MediaMTXPath?) {
        guard _state.selectedPath?.name != path?.name else { return }
        _state.selectedPath = path
        broadcast()
    }

    /// Updates base URL and broadcasts change
    public func updateBaseURL(_ url: URL?) {
        guard _state.baseURL != url else { return }
        _state.baseURL = url
        broadcast()
    }

    /// Updates online status and broadcasts change
    public func updateOnline(_ value: Bool) {
        guard _state.isOnline != value else { return }
        _state.isOnline = value
        broadcast()
    }

    /// Updates total viewer count and broadcasts change
    public func updateTotalViewers(_ count: Int) {
        guard _state.totalViewers != count else { return }
        _state.totalViewers = count
        broadcast()
    }

    /// Updates last update time and broadcasts change
    public func updateLastUpdateTime(_ time: Date) {
        _state.lastUpdateTime = time
        broadcast()
    }

    /// Resets state to initial values and broadcasts change
    public func reset() {
        _state = StreamAdminStateSnapshot()
        broadcast()
    }

    // MARK: - Private Helpers

    /// Broadcasts current state to all subscribers
    private func broadcast() {
        stateSubject.continuation.yield(_state)
    }

    /// Terminates the state stream
    nonisolated public func finish() {
        stateSubject.continuation.finish()
    }

    // MARK: - Cleanup

    deinit {
        finish()
    }
}

// MARK: - Test Helper

/// Mock implementation for testing
public final class MockStreamAdminStateActor: StreamAdminStateActorProtocol, Sendable {
    private let stateSubject: (
        stream: AsyncStream<StreamAdminStateSnapshot>,
        continuation: AsyncStream<StreamAdminStateSnapshot>.Continuation
    )

    public nonisolated var stateUpdates: AsyncStream<StreamAdminStateSnapshot> {
        stateSubject.stream
    }

    private let stateQueue = DispatchQueue(label: "mock.streamadmin.state")
    private var _state: StreamAdminStateSnapshot

    public nonisolated var currentState: StreamAdminStateSnapshot {
        stateQueue.sync { _state }
    }

    public init(initialState: StreamAdminStateSnapshot = .init()) {
        self._state = initialState
        self.stateSubject = AsyncStream.makeStream()
    }

    public func updateLoading(_ value: Bool) async {
        stateQueue.sync {
            guard _state.isLoading != value else { return }
            _state.isLoading = value
            stateSubject.continuation.yield(_state)
        }
    }

    public func updateError(_ message: String?) async {
        stateQueue.sync {
            guard _state.errorMessage != message else { return }
            _state.errorMessage = message
            stateSubject.continuation.yield(_state)
        }
    }

    public func updatePaths(_ paths: [MediaMTXPath]) async {
        stateQueue.sync {
            guard _state.paths.count != paths.count else { return }
            _state.paths = paths
            let newTotalViewers = paths.reduce(0) { $0 + $1.viewerCount }
            _state.totalViewers = newTotalViewers
            stateSubject.continuation.yield(_state)
        }
    }

    public func updateSelectedPath(_ path: MediaMTXPath?) async {
        stateQueue.sync {
            guard _state.selectedPath?.name != path?.name else { return }
            _state.selectedPath = path
            stateSubject.continuation.yield(_state)
        }
    }

    public func updateBaseURL(_ url: URL?) async {
        stateQueue.sync {
            guard _state.baseURL != url else { return }
            _state.baseURL = url
            stateSubject.continuation.yield(_state)
        }
    }

    public func updateOnline(_ value: Bool) async {
        stateQueue.sync {
            guard _state.isOnline != value else { return }
            _state.isOnline = value
            stateSubject.continuation.yield(_state)
        }
    }

    public func updateTotalViewers(_ count: Int) async {
        stateQueue.sync {
            guard _state.totalViewers != count else { return }
            _state.totalViewers = count
            stateSubject.continuation.yield(_state)
        }
    }

    public func updateLastUpdateTime(_ time: Date) async {
        stateQueue.sync {
            _state.lastUpdateTime = time
            stateSubject.continuation.yield(_state)
        }
    }

    public func reset() async {
        stateQueue.sync {
            _state = StreamAdminStateSnapshot()
            stateSubject.continuation.yield(_state)
        }
    }

    deinit {
        stateSubject.continuation.finish()
    }
}
