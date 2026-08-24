Last Modified: 08/24/2026 (1787588646) by amonrit

# Steam Architecture — Pattern Cheat Sheet

Quick reference for the 5 patterns used throughout Steam: StateActor, RetryOrchestrator, APIClientProvider, structured-concurrency polling, and the Coordinator. For the full system picture, see [ARCHITECTURE.md](./ARCHITECTURE.md).

---

## Pattern 1: StateActor — Thread-Safe State

### When to Use
✅ Long-lived state that changes over time
✅ Multiple concurrent writers
✅ MainActor-compatible with SwiftUI

### Basic Template
```swift
@MainActor
final actor MyStateActor: GenericStateActor<MyStateActor.State> {
    struct State: Sendable {
        var value: String = ""
        var isLoading: Bool = false
    }

    init() { super.init(initialState: State()) }

    func updateValue(_ val: String) {
        updateState { $0.value = val }
    }
}
```

### How ViewModels actually consume it

The actor is the source of truth, but SwiftUI can only observe stored properties on an `@Observable` object — it can't observe reads that reach through to a separate actor. So the ViewModel keeps a local, `@Observable`-tracked mirror and syncs it from the actor's `AsyncStream` in `init`:

```swift
@MainActor
@Observable
final class MyViewModel {
    private let stateActor: MyStateActor
    private var state = MyStateActor.State()
    @ObservationIgnored private nonisolated(unsafe) var stateObserverTask: Task<Void, Never>?

    init(stateActor: MyStateActor = MyStateActor()) {
        self.stateActor = stateActor
        stateObserverTask = Task {
            for await newState in stateActor.stateUpdates {
                state = newState
            }
        }
    }

    var value: String { state.value }        // Views just read this
    var isLoading: Bool { state.isLoading }

    deinit { stateObserverTask?.cancel() }
}
```

Views then read `viewModel.value` / `viewModel.isLoading` directly — no `AsyncStream` code in the View layer. This is the pattern `PlaybackViewModel` and `StreamAdminViewModel` both use. See the real implementation in `steam/Features/Playback/Presentation/PlaybackViewModel.swift`.

### Key Methods
```swift
updateState { $0.field = value }              // Mutate & broadcast
setState(newState)                            // Replace & broadcast
let current = currentState                    // Read current (async, off-actor)
var updates: AsyncStream<State> { /* ... */ } // Observe
```

---

## Pattern 2: RetryOrchestrator — Resilient Network Calls

### When to Use
✅ Network operations
✅ Transient failures (timeouts, 5xx)
✅ Need consistent retry behavior

### Basic Template
```swift
let retryOrchestrator = RetryOrchestrator(
    configuration: .production,
    onStatusChanged: { msg in logger.info("\(msg)") }
)

do {
    let result = try await retryOrchestrator.attemptWithRetry {
        try await client.someOperation()
    } onError: { error, attempt in
        logger.error("Attempt \(attempt): \(error)")
    }
} catch {
    logger.error("Failed after all retries: \(error)")
}
```

### Configurations
```swift
.production    // 3 attempts, 1-30s exponential backoff
.testing       // 1 attempt, no delay — use this in tests
PlaybackConfiguration(maxAttempts: 5, initialDelaySeconds: 0.5)
```

### Flow
```
Operation attempt 1
  ├─ Success → return result
  └─ Failure → wait exponential backoff
Operation attempt 2
  ├─ Success → return result
  └─ Failure → wait exponential backoff
Operation attempt 3
  ├─ Success → return result
  └─ Failure → throw error
```

---

## Pattern 3: APIClientProvider — Dependency Injection

### When to Use
✅ Creating `MediaMTXAPIClient` instances
✅ Need to test without network calls
✅ Multiple base URLs/configurations

### Basic Template
```swift
final class MyService {
    private let clientProvider: APIClientProvider

    init(clientProvider: APIClientProvider = DefaultAPIClientProvider()) {
        self.clientProvider = clientProvider
    }

    func doWork() async throws {
        let client = clientProvider.createAPIClient(baseURL: URL(string: "http://localhost:9997")!)
        return try await client.request()
    }
}
```

### Testing
```swift
let mockProvider = MockAPIClientProvider()
mockProvider.defaultMockClient = mockClient

let service = MyService(clientProvider: mockProvider)
let result = try await service.doWork()
XCTAssertEqual(result, expected)
```

### Implementations
```swift
DefaultAPIClientProvider()  // Real network calls
MockAPIClientProvider()     // Test mocks (no network)
```

---

## Pattern 4: Structured Concurrency — Task-Based Polling

### When to Use
✅ Long-running async operations (viewer count, stream status)
✅ Automatic cancellation needed (no `Timer.invalidate()` to forget)

### Basic Template
```swift
private var pollingTask: Task<Void, Never>?

func startPolling() {
    pollingTask = Task {
        while !Task.isCancelled {
            do {
                let result = try await operation()
                // handle result
                try await Task.sleep(nanoseconds: 1_000_000_000)
            } catch is CancellationError {
                return
            }
        }
    }
}

func stopPolling() {
    pollingTask?.cancel()
}
```

### Task Groups (Parallel Work)
```swift
try await withTaskGroup(of: Result.self) { group in
    for item in items {
        group.addTask { try await process(item) }
    }
    for try await result in group {
        // Handle result
    }
}
```

---

## Pattern 5: Coordinator — Navigation & ViewModel Construction

### When to Use
✅ A view needs to push another screen
✅ A screen needs a ViewModel constructed with its dependencies

### Basic Usage
```swift
// Navigating from a View:
@Environment(AppCoordinator.self) var coordinator
...
coordinator.navigate(to: .streamAdmin)

// AppCoordinator builds the destination + its ViewModel:
func navigationView(for route: AppRoute) -> some View {
    switch route {
    case .streamAdmin: StreamAdminView(viewModel: makeStreamAdminViewModel())
    ...
    }
}
```

**Rule of thumb:** Views never call a ViewModel initializer themselves. If a screen needs a ViewModel, it gets one from `AppCoordinator` (directly, or via `DIContainer` inside the coordinator).

---

## Decision Tree

```
I need to...

[Manage state]
  ├─ Is it long-lived, shared across methods? → StateActor, mirrored into an @Observable ViewModel
  └─ Is it pure UI state (a toggle, a sheet flag)? → plain @Observable var, no actor

[Make a network call]
  ├─ Might fail transiently? → RetryOrchestrator
  └─ Can't fail meaningfully → direct await

[Create an API client]
  ├─ Needs to be testable? → APIClientProvider
  └─ One-off script → direct creation

[Run a background task]
  ├─ Long-running (polling)? → Task + structured concurrency, checked against Task.isCancelled
  └─ One-off? → Task { } directly

[Navigate to another screen / build its ViewModel]
  → AppCoordinator.navigate(to:) / DIContainer, never construct the ViewModel in the View
```

---

## Code Review Checklist

### StateActor
- [ ] `State` struct conforms to `Sendable`
- [ ] Actor is `@MainActor`
- [ ] Mutations go through `updateState`/`setState`, never a direct property set
- [ ] The owning ViewModel is `@Observable` and mirrors `stateUpdates` into a stored property (not raw `AsyncStream` code inside a View)
- [ ] `stateObserverTask` is cancelled in `deinit`

### RetryOrchestrator
- [ ] Used for network/transient operations only
- [ ] Wrapped in `attemptWithRetry`
- [ ] `onError` logs each attempt
- [ ] Tests use `.testing` configuration (no real delays)

### APIClientProvider
- [ ] Accepted via constructor parameter with a `DefaultAPIClientProvider()` default
- [ ] Tests inject `MockAPIClientProvider`
- [ ] No direct `MediaMTXAPIClient(...)` construction inside a service

### Structured Concurrency
- [ ] Poll loops check `!Task.isCancelled`
- [ ] `CancellationError` handled (usually by returning)
- [ ] Tasks cancelled in `deinit`/`stopPolling()` — no dangling `Task` references

### Coordinator
- [ ] The View doesn't construct its own ViewModel
- [ ] New destinations get a case in `AppRoute` + a branch in `AppCoordinator.navigationView(for:)`

---

## Gotchas

❌ **Don't:**
- Mix `ObservableObject`/`@Published` with `@Observable` in the same type
- Make a `State` struct mutable without `Sendable`
- Retry on client errors like 400/401 (retrying won't help)
- Construct a ViewModel directly inside a View's initializer
- Forget to cancel polling tasks (leaks the `Task`, not memory in the classic sense, but it keeps running forever)

✅ **Do:**
- Use `@Observable` for every ViewModel (the project migrated off Combine/`@Published`)
- Make all `State` struct fields `Sendable`
- Retry on transient errors (timeout, 5xx)
- Get ViewModels from `AppCoordinator`
- Cancel tasks in `deinit`/`onDisappear`

---

## Reference Links

- [ARCHITECTURE.md](./ARCHITECTURE.md) — complete system design

### Implementation Files
- `steam/Core/Architecture/StateActor.swift`
- `steam/Features/Playback/Domain/Services/RetryOrchestrator.swift`
- `steam/Core/DI/APIClientProvider.swift`
- `steam/App/AppCoordinator.swift`, `steam/App/Navigation/AppRoute.swift`, `steam/Core/DI/DIContainer.swift`

---

## Troubleshooting

### "StateActor won't compile"
→ Make sure the `State` struct conforms to `Sendable`.

### "Test makes real network calls"
→ Missing `MockAPIClientProvider` injection.

### "Task keeps running after cancel"
→ Check for `!Task.isCancelled` in the `while` loop.

### "View isn't updating when state changes"
→ Make sure the ViewModel actually mirrors `stateActor.stateUpdates` into a stored, `@Observable`-tracked property — a computed property that reaches into the actor directly won't be tracked.

---

**Cheat Sheet Version:** 2.0
**Last Updated:** August 2026 — merged the former REFACTORING_GUIDE.md and MIGRATION_GUIDE.md into this file and updated all examples from `@Published`/`ObservableObject` to `@Observable`, since the whole codebase has migrated and there's no more legacy code left to migrate *to* these patterns — this is now just "how we build new features."

See [DOCUMENTATION.md](../DOCUMENTATION.md) for the full documentation index.
