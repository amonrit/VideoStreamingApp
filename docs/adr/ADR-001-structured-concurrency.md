Last Modified: 08/24/2026 (1787587709) by amonrit

# ADR-001: Structured Concurrency with StateActor

## Status

✅ **ACCEPTED** (Phase 7)

## Context

The application previously managed state using SwiftUI's `@Published` properties with KVO observers. This approach had several issues:

1. **Thread Safety:** No compile-time guarantee that state mutations were thread-safe
2. **Memory Leaks:** Manual KVO observers required careful cleanup
3. **Testing Complexity:** Hard to test state changes without UI integration
4. **Swift Best Practices:** The language evolved to favor `async/await` over closure-based reactivity

The Swift language introduced structured concurrency (SE-0304, SE-0306) which provides:
- Compile-time task safety
- Automatic task cancellation on scope exit
- Sendable constraint for cross-actor communication
- Better control flow with `async/await`

## Decision

We adopted structured concurrency with a generic `StateActor` base class:

1. **Replace @Published with StateActor** — Migrate state management from property observers to actor-isolated mutations
2. **Use AsyncStream for Reactive Updates** — Views observe state via `stateUpdates` AsyncStream instead of @Published
3. **MainActor Isolation** — All state actors default to @MainActor for SwiftUI compatibility
4. **Sendable Constraint** — All state types must conform to Sendable for cross-actor safety

## Implementation

### Key Components

**StateActor Protocol:**
```swift
protocol StateActorProtocol: AnyObject, Sendable {
    associatedtype StateType: Sendable
    var currentState: StateType { get }
    var stateUpdates: AsyncStream<StateType> { get }
}
```

**Generic Implementation:**
```swift
@MainActor
actor GenericStateActor<State: Sendable> {
    private var _state: State
    private let stateSubject: (stream: AsyncStream<State>, continuation: AsyncStream<State>.Continuation)
    
    func updateState(_ reducer: (inout State) -> Void) {
        reducer(&_state)
        stateSubject.continuation.yield(_state)
    }
}
```

**Concrete Usage (PlaybackStateActor):**
```swift
@MainActor
actor PlaybackStateActor: GenericStateActor<PlaybackStateActor.State> {
    struct State: Sendable {
        var isPlaying = false
        var currentTime: Double = 0
        var errorMessage: String?
    }
    
    func play() {
        updateState { $0.isPlaying = true }
    }
}
```

### Migration Path

- **Phase 7:** Introduced StateActor and integrated into PlaybackViewModel
- **Phase 8:** Added StateActor to StreamAdminViewModel
- **Phase 9:** Refactored Views to observe state updates
- **Phase 12+:** Completed migration of all ViewModels off `ObservableObject`/`@Published` to `@Observable`

### The concrete integration shape (post-migration)

The pattern that shipped isn't "Views subscribe to the actor's `AsyncStream` directly" — it's:

1. The actor (`PlaybackStateActor`) stays the source of truth, mutated only via `updateX(...)` methods.
2. The owning ViewModel is `@Observable` (not `ObservableObject`) and keeps a private, `@Observable`-tracked mirror of the actor's state, kept in sync by a `Task` started in `init` that iterates `stateActor.stateUpdates`.
3. Views read plain computed properties on the ViewModel (`viewModel.isLoading`) — they never touch `AsyncStream` or the actor directly.

This mirroring step exists because SwiftUI's `@Observable` machinery can only track reads of stored properties on the observed object itself, not reads that reach through to a separate actor.

## Consequences

### ✅ Advantages

- **Compile-time Safety:** Swift compiler enforces actor isolation
- **Memory Safe:** Automatic task cancellation prevents leaks
- **Testable:** State changes can be tested without UI
- **Performance:** Reduced overhead of KVO observers
- **Standard Swift:** Aligns with language best practices

### ⚠️ Trade-offs

- **Learning Curve:** Team must understand actors and AsyncStream
- **Migration Effort:** Existing @Published code requires refactoring
- **Tooling:** Some third-party libraries may not support async patterns yet
- **iOS Availability:** Requires iOS 13.0+ (SWIFT_VERSION ≥ 5.5)

## Alternatives Considered

1. **Keep @Published** — Simpler migration, but ignores language evolution
2. **Use Combine Publishers** — Explicit types, but heavier than AsyncStream
3. **Redux-style State Machine** — More powerful, but more boilerplate
4. **Manual ObservableObject** — Full control, but error-prone

**Why StateActor won:** Best balance of safety, simplicity, and standards alignment

## Related Decisions

- **ADR-002:** RetryOrchestrator for resilience
- **ADR-003:** APIClientProvider for dependency injection
- **ADR-004:** Task-based polling instead of Timers

## References

- [SE-0304: Structured Concurrency](https://github.com/apple/swift-evolution/blob/main/proposals/0304-structured-concurrency.md)
- [SE-0306: Async/await](https://github.com/apple/swift-evolution/blob/main/proposals/0306-async-await.md)
- [SE-0313: Sendable](https://github.com/apple/swift-evolution/blob/main/proposals/0313-actor-isolation-checking.md)
- [WWDC 2021: Async/Await](https://developer.apple.com/videos/play/wwdc2021/10132/)

## Implementation Checklist

- [x] StateActor generic implementation
- [x] PlaybackStateActor integration
- [x] StreamAdminStateActor integration
- [x] Unit tests for StateActors
- [x] Integration tests for state updates
- [x] Complete migration of all ViewModels to `@Observable`
- [x] Documentation of the migration pattern (see above, and `docs/PATTERN-CHEAT-SHEET.md`)
- [ ] Team training on structured concurrency

---

**Follows:** Phase 7 completion  
**Supersedes:** KVO observer pattern  
**Last Reviewed:** 08/17/2026
