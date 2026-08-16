//
//  StateActor.swift
//  steam
//
//  Generic actor-based state management using structured concurrency.
//  Provides a modern alternative to ObservableObject for MainActor-isolated state.
//

import Foundation

/// Generic actor for thread-safe state management using async/await.
/// Isolates state to the main thread for SwiftUI compatibility.
///
/// Provides:
/// - Thread-safe state mutations via actor isolation
/// - AsyncStream for reactive state updates
/// - Sendable constraint on all state
/// - Proper task cancellation semantics
///
/// Example:
/// ```swift
/// @MainActor
/// actor PlaybackState {
///     struct State: Sendable {
///         var isPlaying: Bool = false
///         var currentTime: Double = 0
///     }
///
///     private var _state: State = State()
///     private let stateSubject = AsyncStream<State>.makeStream()
///
///     var stateUpdates: AsyncStream<State> { stateSubject.stream }
///     var currentState: State { _state }
///
///     func play() {
///         _state.isPlaying = true
///         stateSubject.continuation.yield(_state)
///     }
/// }
/// ```
public protocol StateActorProtocol: AnyObject, Sendable {
    associatedtype StateType: Sendable

    /// Current state snapshot
    var currentState: StateType { get }

    /// Async stream of state updates
    var stateUpdates: AsyncStream<StateType> { get }
}

/// Generic state actor base implementation
/// Use as: @MainActor final actor MyStateActor { ... }
public actor GenericStateActor<State: Sendable> {
    // MARK: - Types

    /// Continuation for state updates
    typealias StateContinuation = AsyncStream<State>.Continuation

    // MARK: - Properties

    /// Current state (protected by actor isolation)
    private var _state: State

    /// Stream continuation for broadcasting state changes
    private let stateSubject: (stream: AsyncStream<State>, continuation: StateContinuation)

    /// Public access to state update stream (nonisolated - safe for AsyncStream)
    nonisolated public var stateUpdates: AsyncStream<State> { stateSubject.stream }

    /// Current state snapshot
    public var currentState: State { _state }

    // MARK: - Initialization

    /// Initializes the state actor with an initial state
    /// - Parameter initialState: The starting state value
    public init(initialState: State) {
        self._state = initialState
        self.stateSubject = AsyncStream.makeStream()
    }

    // MARK: - Public Methods

    /// Updates state using a reducer closure and broadcasts the change
    /// - Parameter reducer: Closure that mutates the state
    public func updateState(_ reducer: (inout State) -> Void) {
        reducer(&_state)
        stateSubject.continuation.yield(_state)
    }

    /// Replaces the entire state and broadcasts the change
    /// - Parameter newState: The new state to set
    public func setState(_ newState: State) {
        _state = newState
        stateSubject.continuation.yield(_state)
    }

    /// Gets the current state without side effects
    /// - Returns: A copy of the current state
    public func getState() -> State {
        _state
    }

    /// Terminates the state stream
    /// Call when the actor should stop broadcasting updates
    nonisolated public func finish() {
        // Note: AsyncStream.Continuation is Sendable, safe to call from nonisolated context
        stateSubject.continuation.finish()
    }
}

// MARK: - Bridge to SwiftUI Observability (Temporary)

/// Extension to support bridging state actor to SwiftUI views during migration.
/// This allows @Published properties to observe the AsyncStream.
extension GenericStateActor {
    /// Creates an async task that observes state updates
    /// - Parameter onUpdate: Closure called when state changes
    /// - Returns: A Task that continues until cancelled
    nonisolated public func observeState(
        onUpdate: @escaping (State) -> Void
    ) -> Task<Void, Never> {
        Task {
            var iterator = stateUpdates.makeAsyncIterator()
            while let state = await iterator.next() {
                onUpdate(state)
            }
        }
    }
}

// MARK: - Error Types

/// Errors that can occur in state actor operations
public enum StateActorError: LocalizedError {
    case stateStreamClosed
    case invalidState(String)
    case operationCancelled

    public var errorDescription: String? {
        switch self {
        case .stateStreamClosed:
            return "State stream has been closed"
        case .invalidState(let reason):
            return "Invalid state: \(reason)"
        case .operationCancelled:
            return "Operation was cancelled"
        }
    }
}
