Last Modified: 08/17/2026 (1786922418) by amonrit

# Steam Architecture — Pattern Cheat Sheet

Quick reference for the 4 modern patterns in Steam.

---

## Pattern 1: StateActor — Thread-Safe State

### When to Use
✅ Long-lived state that changes  
✅ Multiple concurrent updates  
✅ MainActor-compatible with SwiftUI  

### Basic Template
```swift
@MainActor
actor MyStateActor: GenericStateActor<MyStateActor.State> {
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

### In Views
```swift
var body: some View {
    VStack {
        Text(state?.value ?? "")
        if state?.isLoading == true { ProgressView() }
    }
    .onAppear {
        task = Task {
            for await newState in actor.stateUpdates {
                await MainActor.run { self.state = newState }
            }
        }
    }
}
```

### Key Methods
```swift
updateState { $0.field = value }     // Mutate & broadcast
setState(newState)                    // Replace & broadcast
let current = currentState             // Read current
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
private let retryOrchestrator = RetryOrchestrator(
    configuration: .production,
    onStatusChanged: { msg in logger.info(msg) }
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
.production    // 3 attempts, 1-30s backoff
.testing       // 1 attempt, no delay
PlaybackConfiguration(maxAttempts: 5, initialDelaySeconds: 0.5)
```

### Flow
```
Operation attempt 1
  ├─ Success → return result
  └─ Failure → wait exponential time
Operation attempt 2
  ├─ Success → return result
  └─ Failure → wait exponential time
Operation attempt 3
  ├─ Success → return result
  └─ Failure → throw error
```

---

## Pattern 3: APIClientProvider — Dependency Injection

### When to Use
✅ Creating API clients  
✅ Need testing without network  
✅ Support multiple configurations  

### Basic Template
```swift
class MyService {
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

## Pattern 4: Structured Concurrency — Task Management

### When to Use
✅ Long-running async operations  
✅ Polling/background tasks  
✅ Automatic cancellation needed  

### Basic Template
```swift
var pollingTask: Task<Void, Never>?

func startPolling() {
    pollingTask = Task {
        while !Task.isCancelled {
            do {
                let result = try await operation()
                // Handle result
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

### Common Sleeps
```swift
try await Task.sleep(nanoseconds: 1_000_000_000)     // 1 second
try await Task.sleep(nanoseconds: 500_000_000)       // 0.5 seconds
try await Task.sleep(nanoseconds: 5_000_000_000)     // 5 seconds
```

### Task Groups (Parallel)
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

## Decision Tree

```
I need to...

[Manage state]
  ├─ Is it long-lived? → YES → StateActor ✓
  └─ Is it simple? → YES → @State or struct

[Make network call]
  ├─ Might fail transiently? → YES → RetryOrchestrator ✓
  └─ Nope, it's solid → Direct await

[Create API client]
  ├─ Need testable? → YES → APIClientProvider ✓
  └─ Standalone script → Direct creation

[Run background task]
  ├─ Long-running? → YES → Task + structured concurrency ✓
  └─ One-off? → Task { } directly
```

---

## Common Combinations

### Scenario 1: Load Data with Retry + State
```swift
let stateActor = MyStateActor()
let orchestrator = RetryOrchestrator()

await stateActor.setLoading(true)

do {
    let data = try await orchestrator.attemptWithRetry {
        try await client.fetch()
    }
    await stateActor.setData(data)
} catch {
    await stateActor.setError(error)
}
```

### Scenario 2: Poll Data + Update State
```swift
var task: Task<Void, Never>?

func startPolling() {
    task = Task {
        while !Task.isCancelled {
            do {
                let data = try await client.fetch()
                await stateActor.setData(data)
                try await Task.sleep(nanoseconds: 5_000_000_000)
            } catch is CancellationError {
                return
            }
        }
    }
}

func stopPolling() {
    task?.cancel()
}
```

### Scenario 3: Testable Service with DI + Retry
```swift
class DataService {
    private let clientProvider: APIClientProvider
    private let retryOrchestrator: RetryOrchestrator
    
    init(clientProvider: APIClientProvider = DefaultAPIClientProvider()) {
        self.clientProvider = clientProvider
        self.retryOrchestrator = RetryOrchestrator()
    }
    
    func loadData() async throws -> Data {
        try await retryOrchestrator.attemptWithRetry {
            let client = self.clientProvider.createAPIClient(baseURL: url)
            return try await client.fetch()
        }
    }
}
```

---

## Code Review Checklist

### StateActor
- [ ] Struct conforms to Sendable
- [ ] Actor is @MainActor
- [ ] State updates use updateState or setState
- [ ] Views observe stateUpdates AsyncStream
- [ ] Tests check state directly

### RetryOrchestrator
- [ ] Used for network/transient operations
- [ ] Wrapped in attemptWithRetry
- [ ] Error handler logs each attempt
- [ ] Configuration matches operation criticality
- [ ] Tests use .testing configuration

### APIClientProvider
- [ ] Accepted via constructor parameter
- [ ] Default implementation provided
- [ ] Tests inject MockAPIClientProvider
- [ ] No direct client creation in service

### Structured Concurrency
- [ ] Task loops check !Task.isCancelled
- [ ] CancellationError handled
- [ ] Tasks cancelled on deinit/disappear
- [ ] No dangling Task references

---

## Reference Links

### Documentation
- [ARCHITECTURE.md](./ARCHITECTURE.md) — Complete system design
- [REFACTORING_GUIDE.md](./REFACTORING_GUIDE.md) — Detailed patterns & examples
- [MIGRATION_GUIDE.md](./MIGRATION_GUIDE.md) — Step-by-step refactoring
- [adr/](./adr/) — Design decision explanations

### Implementation Files
- `steam/Core/Architecture/StateActor.swift`
- `steam/Features/Playback/Domain/Services/RetryOrchestrator.swift`
- `steam/Core/DI/APIClientProvider.swift`

---

## Troubleshooting

### "StateActor won't compile"
→ Make sure State struct conforms to `Sendable`

### "Test makes real network calls"
→ Missing MockAPIClientProvider injection

### "Task keeps running after cancel"
→ Check `!Task.isCancelled` in while loop

### "State updates not appearing in View"
→ Ensure View observes stateUpdates AsyncStream

---

## Performance Tips

1. **StateActor** — Batching updates OK, but yields for each
2. **RetryOrchestrator** — Exponential backoff prevents thundering herd
3. **APIClientProvider** — Zero overhead, just indirection
4. **Tasks** — Prefer Task.sleep to DispatchQueue.asyncAfter

---

## Gotchas

❌ **Don't:**
- Use @Published with StateActor (contradictory)
- Make State mutable without Sendable (data race)
- Retry on client errors like 400/401 (won't help)
- Create APIClient without provider in testable code
- Forget to cancel polling tasks (memory leak)

✅ **Do:**
- Use StateActor for all MainActor state
- Make all struct fields Sendable
- Retry on transient errors (timeout, 5xx)
- Always accept APIClientProvider parameter
- Cancel tasks in onDisappear/deinit

---

## Quick Examples

### Minimal StateActor
```swift
@MainActor actor Counter: GenericStateActor<Int> {
    init() { super.init(initialState: 0) }
    func increment() { updateState { $0 += 1 } }
}
```

### Minimal RetryOrchestrator
```swift
let data = try await RetryOrchestrator()
    .attemptWithRetry { try await api.fetch() }
```

### Minimal APIClientProvider
```swift
class Service {
    init(clientProvider: APIClientProvider = DefaultAPIClientProvider()) {
        self.clientProvider = clientProvider
    }
}
```

### Minimal Structured Concurrency
```swift
Task {
    while !Task.isCancelled {
        try? await doWork()
        try? await Task.sleep(nanoseconds: 1e9)
    }
}
```

---

## One-Page Diagram

```
                    ┌─────────────┐
                    │  SwiftUI    │
                    │  Views      │
                    └──────┬──────┘
                           │ observes
                           ▼
            ┌──────────────────────────────┐
            │    StateActor (Thread-Safe)   │
            │  - updateState() mutations    │
            │  - AsyncStream updates        │
            └──────────┬───────────────────┘
                       │ calls methods
                       ▼
    ┌──────────────────────────────────────────┐
    │  Services/ViewModels                     │
    │  ├─ RetryOrchestrator (Resilience)      │
    │  │  └─ attemptWithRetry() with backoff  │
    │  └─ Polling (Long-running tasks)        │
    │     └─ Task loops with cancellation     │
    └──────────────────┬───────────────────────┘
                       │ creates
                       ▼
    ┌──────────────────────────────────────────┐
    │  APIClientProvider (Dependency Inject)  │
    │  ├─ DefaultAPIClientProvider (prod)     │
    │  └─ MockAPIClientProvider (test)        │
    └──────────────────┬───────────────────────┘
                       │ creates
                       ▼
    ┌──────────────────────────────────────────┐
    │  MediaMTXAPIClient                       │
    │  └─ Network calls (HTTP)                 │
    └──────────────────────────────────────────┘
```

---

**Cheat Sheet Version:** 1.0  
**Last Updated:** August 2026  
**Print:** Yes, this fits on 2 pages!

See [DOCUMENTATION.md](../DOCUMENTATION.md) for complete guides.
