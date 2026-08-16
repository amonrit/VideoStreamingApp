//
//  PlaybackStateActor.swift
//  steam
//
//  Actor-based state management for video playback using structured concurrency.
//  Provides thread-safe state updates for the PlaybackViewModel.
//

import Foundation
import AVFoundation

// MARK: - State Snapshot

/// State snapshot for video playback
/// Conforms to Sendable for thread-safe passing across actors
public struct PlaybackStateSnapshot: Sendable {
    public var isLoading: Bool
    public var isPlaying: Bool
    public var errorMessage: String?
    public var bufferingCount: Int
    public var currentStream: VideoStream?
    public var connectionStatus: ConnectionStatus
    public var retryAttempt: Int
    public var viewerCount: Int?
    public var currentTime: Double
    public var duration: Double

    public init(
        isLoading: Bool = false,
        isPlaying: Bool = false,
        errorMessage: String? = nil,
        bufferingCount: Int = 0,
        currentStream: VideoStream? = nil,
        connectionStatus: ConnectionStatus = .disconnected,
        retryAttempt: Int = 0,
        viewerCount: Int? = nil,
        currentTime: Double = 0,
        duration: Double = 0
    ) {
        self.isLoading = isLoading
        self.isPlaying = isPlaying
        self.errorMessage = errorMessage
        self.bufferingCount = bufferingCount
        self.currentStream = currentStream
        self.connectionStatus = connectionStatus
        self.retryAttempt = retryAttempt
        self.viewerCount = viewerCount
        self.currentTime = currentTime
        self.duration = duration
    }

    public static func == (lhs: PlaybackStateSnapshot, rhs: PlaybackStateSnapshot) -> Bool {
        lhs.isLoading == rhs.isLoading &&
        lhs.isPlaying == rhs.isPlaying &&
        lhs.errorMessage == rhs.errorMessage &&
        lhs.bufferingCount == rhs.bufferingCount &&
        lhs.currentStream?.id == rhs.currentStream?.id &&
        lhs.connectionStatus == rhs.connectionStatus &&
        lhs.retryAttempt == rhs.retryAttempt &&
        lhs.viewerCount == rhs.viewerCount &&
        abs(lhs.currentTime - rhs.currentTime) < 0.01 &&
        lhs.duration == rhs.duration
    }
}

/// Protocol for playback state actor to enable testing with mocks
public protocol PlaybackStateActorProtocol: AnyObject, Sendable {
    var currentState: PlaybackStateSnapshot { get }
    var stateUpdates: AsyncStream<PlaybackStateSnapshot> { get }

    func updateLoading(_ value: Bool) async
    func updatePlaying(_ value: Bool) async
    func updateError(_ message: String?) async
    func updateConnectionStatus(_ status: ConnectionStatus) async
    func updateRetryAttempt(_ count: Int) async
    func updateViewerCount(_ count: Int?) async
    func updateCurrentStream(_ stream: VideoStream?) async
    func updateBufferingCount(_ count: Int) async
    func updateCurrentTime(_ time: Double) async
    func updateDuration(_ duration: Double) async
    func reset() async
}

/// Actor-based state management for playback
/// - Isolates state to actor domain (default executor)
/// - Provides AsyncStream for reactive updates
/// - Thread-safe state mutations
///
/// Usage:
/// ```swift
/// let stateActor = DefaultPlaybackStateActor()
///
/// // Update state
/// await stateActor.updateLoading(true)
///
/// // Observe updates
/// for await state in await stateActor.stateUpdates {
///     print("State updated: \(state.isLoading)")
/// }
/// ```
public final actor DefaultPlaybackStateActor {
    // MARK: - Properties

    private var _state: PlaybackStateSnapshot

    private nonisolated let stateSubject: (
        stream: AsyncStream<PlaybackStateSnapshot>,
        continuation: AsyncStream<PlaybackStateSnapshot>.Continuation
    )

    public var currentState: PlaybackStateSnapshot { _state }

    nonisolated public var stateUpdates: AsyncStream<PlaybackStateSnapshot> { stateSubject.stream }

    // MARK: - Initialization

    public init(initialState: PlaybackStateSnapshot = .init()) {
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

    /// Updates playing state and broadcasts change
    public func updatePlaying(_ value: Bool) {
        guard _state.isPlaying != value else { return }
        _state.isPlaying = value
        broadcast()
    }

    /// Updates error message and broadcasts change
    public func updateError(_ message: String?) {
        guard _state.errorMessage != message else { return }
        _state.errorMessage = message
        broadcast()
    }

    /// Updates connection status and broadcasts change
    public func updateConnectionStatus(_ status: ConnectionStatus) {
        guard _state.connectionStatus != status else { return }
        _state.connectionStatus = status
        broadcast()
    }

    /// Updates retry attempt count and broadcasts change
    public func updateRetryAttempt(_ count: Int) {
        guard _state.retryAttempt != count else { return }
        _state.retryAttempt = count
        broadcast()
    }

    /// Updates viewer count and broadcasts change
    public func updateViewerCount(_ count: Int?) {
        guard _state.viewerCount != count else { return }
        _state.viewerCount = count
        broadcast()
    }

    /// Updates current stream and broadcasts change
    public func updateCurrentStream(_ stream: VideoStream?) {
        guard _state.currentStream?.id != stream?.id else { return }
        _state.currentStream = stream
        broadcast()
    }

    /// Updates buffering count and broadcasts change
    public func updateBufferingCount(_ count: Int) {
        guard _state.bufferingCount != count else { return }
        _state.bufferingCount = count
        broadcast()
    }

    /// Updates current playback time and broadcasts change
    public func updateCurrentTime(_ time: Double) {
        // Don't guard for time updates - they change frequently
        let roundedTime = (time * 100).rounded() / 100 // Round to 2 decimal places
        guard abs(_state.currentTime - roundedTime) >= 0.01 else { return }
        _state.currentTime = roundedTime
        broadcast()
    }

    /// Updates total duration and broadcasts change
    public func updateDuration(_ duration: Double) {
        guard _state.duration != duration else { return }
        _state.duration = duration
        broadcast()
    }

    /// Resets state to initial values and broadcasts change
    public func reset() {
        _state = PlaybackStateSnapshot()
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
public final class MockPlaybackStateActor: PlaybackStateActorProtocol, Sendable {
    private let stateSubject: (
        stream: AsyncStream<PlaybackStateSnapshot>,
        continuation: AsyncStream<PlaybackStateSnapshot>.Continuation
    )

    public nonisolated var stateUpdates: AsyncStream<PlaybackStateSnapshot> {
        stateSubject.stream
    }

    private let stateQueue = DispatchQueue(label: "mock.playback.state")
    private var _state: PlaybackStateSnapshot

    public nonisolated var currentState: PlaybackStateSnapshot {
        stateQueue.sync { _state }
    }

    public init(initialState: PlaybackStateSnapshot = .init()) {
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

    public func updatePlaying(_ value: Bool) async {
        stateQueue.sync {
            guard _state.isPlaying != value else { return }
            _state.isPlaying = value
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

    public func updateConnectionStatus(_ status: ConnectionStatus) async {
        stateQueue.sync {
            guard _state.connectionStatus != status else { return }
            _state.connectionStatus = status
            stateSubject.continuation.yield(_state)
        }
    }

    public func updateRetryAttempt(_ count: Int) async {
        stateQueue.sync {
            guard _state.retryAttempt != count else { return }
            _state.retryAttempt = count
            stateSubject.continuation.yield(_state)
        }
    }

    public func updateViewerCount(_ count: Int?) async {
        stateQueue.sync {
            guard _state.viewerCount != count else { return }
            _state.viewerCount = count
            stateSubject.continuation.yield(_state)
        }
    }

    public func updateCurrentStream(_ stream: VideoStream?) async {
        stateQueue.sync {
            guard _state.currentStream?.id != stream?.id else { return }
            _state.currentStream = stream
            stateSubject.continuation.yield(_state)
        }
    }

    public func updateBufferingCount(_ count: Int) async {
        stateQueue.sync {
            guard _state.bufferingCount != count else { return }
            _state.bufferingCount = count
            stateSubject.continuation.yield(_state)
        }
    }

    public func updateCurrentTime(_ time: Double) async {
        stateQueue.sync {
            let roundedTime = (time * 100).rounded() / 100
            guard abs(_state.currentTime - roundedTime) >= 0.01 else { return }
            _state.currentTime = roundedTime
            stateSubject.continuation.yield(_state)
        }
    }

    public func updateDuration(_ duration: Double) async {
        stateQueue.sync {
            guard _state.duration != duration else { return }
            _state.duration = duration
            stateSubject.continuation.yield(_state)
        }
    }

    public func reset() async {
        stateQueue.sync {
            _state = PlaybackStateSnapshot()
            stateSubject.continuation.yield(_state)
        }
    }

    deinit {
        stateSubject.continuation.finish()
    }
}
