Last Modified: 08/17/2026 (1786922418) by amonrit

# Migration Guide — Adopting Modern Patterns

This guide helps developers migrate legacy code to use modern architectural patterns.

---

## Table of Contents

1. [Quick Decision Tree](#decision-tree)
2. [Migration Checklist](#checklist)
3. [Common Patterns to Replace](#patterns)
4. [Code Examples](#examples)
5. [Testing After Migration](#testing)
6. [Rolling Out Changes](#rollout)

---

## Quick Decision Tree {#decision-tree}

**When adding a new feature:**

```
Is it a service that maintains state?
  ├─ YES → Use StateActor (see Pattern 1)
  └─ NO  → Use a simple struct

Does it make network calls?
  ├─ YES → Use RetryOrchestrator + APIClientProvider
  │        (see Patterns 2 & 3)
  └─ NO  → Call API directly

Does it need to be testable?
  ├─ YES → Inject APIClientProvider
  │        (see Pattern 3)
  └─ NO  → Can use DefaultAPIClientProvider default

Does it run long-lived async operations?
  ├─ YES → Use Task-based structured concurrency
  │        (see Pattern 4)
  └─ NO  → Use async/await directly
```

---

## Migration Checklist {#checklist}

### Before Starting

- [ ] Identify target code (old @Published ViewModel, etc.)
- [ ] Create a feature branch: `refactor/modernize-<component>`
- [ ] Write tests for current behavior (if missing)
- [ ] Verify tests pass before refactoring

### During Migration

- [ ] Replace @Published with StateActor
- [ ] Replace manual retry with RetryOrchestrator
- [ ] Add APIClientProvider injection
- [ ] Update Views to observe AsyncStream
- [ ] Update tests to use mocks
- [ ] Run all tests: `make test`
- [ ] Check code coverage

### After Migration

- [ ] Code review (ask for patterns feedback)
- [ ] Merge to main after approval
- [ ] Run integration tests in staging
- [ ] Verify in production (A/B test if possible)
- [ ] Update CHANGELOG.md

---

## Common Patterns to Replace {#patterns}

### Pattern 1: @Published Properties → StateActor

**Where to find it:**
```bash
grep -r "@Published" steam/Features --include="*.swift"
```

**Checklist:**
- [ ] Create State struct inside actor
- [ ] Copy @Published var names to State fields
- [ ] Replace each @Published setter with updateState call
- [ ] Update Views to observe stateUpdates
- [ ] Update tests to check state directly

**Example:**

```swift
// BEFORE
class MyViewModel: ObservableObject {
    @Published var name = ""
    @Published var isLoading = false
    @Published var error: String?
    
    func loadData() {
        self.isLoading = true
        // ...
    }
}

// AFTER
@MainActor
actor MyStateActor: GenericStateActor<MyStateActor.State> {
    struct State: Sendable {
        var name = ""
        var isLoading = false
        var error: String?
    }
    
    init() {
        super.init(initialState: State())
    }
    
    func loadData() {
        updateState { $0.isLoading = true }
    }
}
```

### Pattern 2: Manual Retry Loops → RetryOrchestrator

**Where to find it:**
```bash
grep -r "while.*retry\|attempt.*<\|maxAttempts" steam/ --include="*.swift"
```

**Checklist:**
- [ ] Extract operation into separate function
- [ ] Wrap with retryOrchestrator.attemptWithRetry
- [ ] Remove manual delay calculation
- [ ] Add onError handler for logging
- [ ] Test with .testing configuration

**Example:**

```swift
// BEFORE
func loadStream() async throws {
    var attempt = 0
    while attempt < 3 {
        do {
            return try await client.getStream()
        } catch {
            attempt += 1
            try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt)) * 1e9))
        }
    }
    throw NSError(domain: "Failed after retries")
}

// AFTER
private let retryOrchestrator = RetryOrchestrator()

func loadStream() async throws -> Stream {
    try await retryOrchestrator.attemptWithRetry {
        try await client.getStream()
    } onError: { error, attempt in
        logger.error("Attempt \(attempt): \(error)")
    }
}
```

### Pattern 3: Hard-Coded Clients → APIClientProvider

**Where to find it:**
```bash
grep -r "MediaMTXAPIClient(baseURL:" steam/ --include="*.swift"
```

**Checklist:**
- [ ] Add clientProvider parameter to __init__
- [ ] Replace direct client creation with clientProvider.createAPIClient()
- [ ] Create MockAPIClientProvider in tests
- [ ] Update test setup to inject mock
- [ ] Verify all code paths testable

**Example:**

```swift
// BEFORE
class StreamAdminService {
    func createStream(name: String) async throws -> Stream {
        let client = MediaMTXAPIClient(baseURL: URL(string: "http://localhost:9997")!)
        return try await client.createStream(name: name)
    }
}

// AFTER
class StreamAdminService {
    private let clientProvider: APIClientProvider
    
    init(clientProvider: APIClientProvider = DefaultAPIClientProvider()) {
        self.clientProvider = clientProvider
    }
    
    func createStream(name: String) async throws -> Stream {
        let client = clientProvider.createAPIClient(baseURL: URL(string: "http://localhost:9997")!)
        return try await client.createStream(name: name)
    }
}
```

### Pattern 4: Manual Timers → Task-Based Polling

**Where to find it:**
```bash
grep -r "Timer\|DispatchSourceTimer\|schedule" steam/ --include="*.swift"
```

**Checklist:**
- [ ] Replace Timer with Task.sleep
- [ ] Use while !Task.isCancelled loop
- [ ] Wrap in Task { }
- [ ] Let task cancellation handle cleanup
- [ ] No manual invalidation needed

**Example:**

```swift
// BEFORE
class PollingService {
    var timer: Timer?
    
    func startPolling() {
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
            Task {
                let status = try await self.client.getStatus()
                // Handle status
            }
        }
    }
    
    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }
    
    deinit {
        stopPolling() // Easy to forget!
    }
}

// AFTER
class PollingService {
    private var pollingTask: Task<Void, Never>?
    
    func startPolling() {
        pollingTask = Task {
            while !Task.isCancelled {
                do {
                    let status = try await client.getStatus()
                    // Handle status
                    try await Task.sleep(nanoseconds: 5_000_000_000)
                } catch is CancellationError {
                    return
                }
            }
        }
    }
    
    func stopPolling() {
        pollingTask?.cancel()
        // Automatic cleanup!
    }
}
```

---

## Code Examples {#examples}

### Example 1: Complete Service Modernization

Before: Old streaming service with all anti-patterns

```swift
class OldStreamService: NSObject, ObservableObject {
    @Published var streams: [Stream] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private let baseURL = URL(string: "http://localhost:9997")!
    private var pollingTimer: Timer?
    private var retryCount = 0
    
    func loadStreams() {
        isLoading = true
        
        Task {
            var attempts = 0
            while attempts < 3 {
                do {
                    let client = MediaMTXAPIClient(baseURL: baseURL)
                    let streams = try await client.listStreams()
                    
                    DispatchQueue.main.async {
                        self.streams = streams
                        self.isLoading = false
                        self.error = nil
                    }
                    return
                } catch {
                    attempts += 1
                    if attempts < 3 {
                        try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempts)) * 1e9))
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.error = "Failed after 3 attempts"
                self.isLoading = false
            }
        }
    }
    
    func startPolling() {
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
            self.loadStreams()
        }
    }
    
    func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }
    
    deinit {
        stopPolling()
    }
}
```

After: Modern service using new patterns

```swift
@MainActor
actor StreamStateActor: GenericStateActor<StreamStateActor.State> {
    struct State: Sendable {
        var streams: [Stream] = []
        var isLoading = false
        var error: String?
    }
    
    init() {
        super.init(initialState: State())
    }
    
    func setLoading(_ value: Bool) {
        updateState { $0.isLoading = value }
    }
    
    func setStreams(_ streams: [Stream]) {
        updateState {
            $0.streams = streams
            $0.error = nil
        }
    }
    
    func setError(_ message: String) {
        updateState {
            $0.error = message
            $0.isLoading = false
        }
    }
}

class ModernStreamService {
    private let clientProvider: APIClientProvider
    private let retryOrchestrator: RetryOrchestrator
    private let stateActor: StreamStateActor
    
    private var pollingTask: Task<Void, Never>?
    
    init(
        clientProvider: APIClientProvider = DefaultAPIClientProvider(),
        stateActor: StreamStateActor = StreamStateActor()
    ) {
        self.clientProvider = clientProvider
        self.retryOrchestrator = RetryOrchestrator()
        self.stateActor = stateActor
    }
    
    func loadStreams() async {
        await stateActor.setLoading(true)
        
        do {
            let streams = try await retryOrchestrator.attemptWithRetry {
                let client = self.clientProvider.createAPIClient(baseURL: URL(string: "http://localhost:9997")!)
                return try await client.listStreams()
            } onError: { error, attempt in
                logger.error("Attempt \(attempt): \(error)")
            }
            
            await stateActor.setStreams(streams)
        } catch {
            await stateActor.setError(error.localizedDescription)
        }
    }
    
    func startPolling() {
        pollingTask = Task {
            while !Task.isCancelled {
                try? await loadStreams()
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }
    }
    
    func stopPolling() {
        pollingTask?.cancel()
    }
}
```

### Example 2: View Modernization

Before: View observing old ViewModel

```swift
struct StreamListView: View {
    @ObservedObject var viewModel: OldStreamService
    
    var body: some View {
        List(viewModel.streams) { stream in
            StreamCell(stream: stream)
        }
        .overlay(
            Group {
                if viewModel.isLoading {
                    ProgressView()
                }
            }
        )
        .alert(isPresented: .constant(viewModel.error != nil)) {
            Alert(title: Text("Error"), message: Text(viewModel.error ?? ""))
        }
        .onAppear { viewModel.loadStreams() }
    }
}
```

After: View observing modern StateActor

```swift
struct StreamListView: View {
    @State private var state: StreamStateActor.State?
    @State private var task: Task<Void, Never>?
    
    private let service: ModernStreamService
    
    var body: some View {
        List((state?.streams ?? []), id: \.id) { stream in
            StreamCell(stream: stream)
        }
        .overlay(
            Group {
                if state?.isLoading == true {
                    ProgressView()
                }
            }
        )
        .alert(isPresented: .constant(state?.error != nil)) {
            Alert(title: Text("Error"), message: Text(state?.error ?? ""))
        }
        .onAppear {
            task = Task {
                await service.loadStreams()
                
                var iterator = await service.stateActor.stateUpdates.makeAsyncIterator()
                while let newState = await iterator.next() {
                    await MainActor.run {
                        self.state = newState
                    }
                }
            }
        }
        .onDisappear {
            task?.cancel()
            service.stopPolling()
        }
    }
}
```

---

## Testing After Migration {#testing}

### Test Pattern: StateActor

```swift
@MainActor
final class StreamStateActorTests: XCTestCase {
    var actor: StreamStateActor!
    
    override func setUp() async throws {
        actor = StreamStateActor()
    }
    
    func testSetStreams() async throws {
        let mockStreams = [Stream(id: "1", name: "Test")]
        
        await actor.setStreams(mockStreams)
        
        let state = await actor.currentState
        XCTAssertEqual(state.streams, mockStreams)
        XCTAssertNil(state.error)
    }
}
```

### Test Pattern: Service with Mock Provider

```swift
class ModernStreamServiceTests: XCTestCase {
    @MainActor
    func testLoadStreams() async throws {
        let mockProvider = MockAPIClientProvider()
        let mockClient = MockMediaMTXAPIClient()
        mockProvider.defaultMockClient = mockClient
        
        let service = ModernStreamService(clientProvider: mockProvider)
        
        try await service.loadStreams()
        
        let state = await service.stateActor.currentState
        XCTAssertFalse(state.isLoading)
        XCTAssertNotNil(state.streams)
    }
}
```

---

## Rolling Out Changes {#rollout}

### Phase Approach

1. **Week 1: Migration Phase 1**
   - Migrate 1-2 small services
   - Get team feedback
   - Refine processes

2. **Week 2-3: Migration Phase 2**
   - Migrate 3-4 medium services
   - Establish patterns
   - Document issues

3. **Week 4: Completion**
   - Migrate remaining services
   - Update documentation
   - Team training

### Rollback Strategy

If migration introduces issues:

1. Identify problematic commit
2. Create issue to track problem
3. Revert commit if critical
4. Fix on a new branch
5. Re-submit with improvements

```bash
# Revert a commit
git revert <commit-hash> -m "Revert modernization due to XYZ"

# Create tracking issue
gh issue create -t "Fix modernization issue" -b "Revert: <link>"
```

---

## Common Pitfalls

### ❌ Mistake 1: Forgetting to update Tests

```swift
// WRONG: Test still tries to use old @Published
func testLoadData() {
    let vm = ModernStreamService()
    vm.loadData() // No @Published properties!
    XCTAssertTrue(vm.isLoading) // Property doesn't exist
}

// RIGHT: Test observes state from actor
func testLoadData() async throws {
    let service = ModernStreamService()
    try await service.loadStreams()
    
    let state = await service.stateActor.currentState
    XCTAssertFalse(state.isLoading)
}
```

### ❌ Mistake 2: Not Injecting Mock in Constructor

```swift
// WRONG: Service creates real client in init
class Service {
    init() {
        self.client = MediaMTXAPIClient() // Always real!
    }
}

// RIGHT: Accept provider parameter
class Service {
    init(clientProvider: APIClientProvider = DefaultAPIClientProvider()) {
        self.clientProvider = clientProvider
    }
}
```

### ❌ Mistake 3: Forgetting to Cancel Tasks

```swift
// WRONG: Task runs forever
func startPolling() {
    Task {
        while true { // infinite loop!
            try await Task.sleep(nanoseconds: 1e9)
        }
    }
}

// RIGHT: Check cancellation
func startPolling() {
    pollingTask = Task {
        while !Task.isCancelled {
            try await Task.sleep(nanoseconds: 1e9)
        }
    }
}
```

---

## Success Metrics

Track these metrics before and after migration:

| Metric | Before | After | Goal |
|--------|--------|-------|------|
| Test Execution Time | 60s | 5s | 10x faster |
| Lines of Test Code | 400 | 300 | 25% reduction |
| Code Coverage | 60% | 85% | +25% |
| Manual Bug Reports | 5-10/week | 1-2/week | 80% reduction |
| Retry Success Rate | 70% | 95% | +25% |

---

## Resources

- **[REFACTORING_GUIDE.md](./REFACTORING_GUIDE.md)** — Detailed patterns
- **[adr/ADR-001-structured-concurrency.md](./adr/ADR-001-structured-concurrency.md)** — StateActor design
- **[adr/ADR-002-retry-orchestrator.md](./adr/ADR-002-retry-orchestrator.md)** — Retry design
- **[adr/ADR-003-dependency-injection.md](./adr/ADR-003-dependency-injection.md)** — DI design
- **[ARCHITECTURE.md](./ARCHITECTURE.md)** — Complete system design

---

**Last Updated:** August 2026  
**Next Review:** August 2027
