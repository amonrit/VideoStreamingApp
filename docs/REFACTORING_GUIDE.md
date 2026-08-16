Last Modified: 08/17/2026 (1786922418) by amonrit

# Refactoring Guide — Modernizing the Codebase

This guide explains how to refactor code in the Steam project using modern Swift patterns and architectural improvements introduced in Phases 4-9.

---

## Table of Contents

1. [Overview: The Problem We're Solving](#overview)
2. [Pattern 1: StateActor for Thread-Safe State](#pattern-1-stateactor)
3. [Pattern 2: RetryOrchestrator for Resilience](#pattern-2-retryorchestrator)
4. [Pattern 3: APIClientProvider for Dependency Injection](#pattern-3-apiclientprovider)
5. [Pattern 4: Structured Concurrency with Task Management](#pattern-4-structured-concurrency)
6. [Common Refactoring Scenarios](#scenarios)
7. [Testing Your Refactored Code](#testing)
8. [Rollback Strategy](#rollback)

---

## Overview: The Problem We're Solving {#overview}

**Before:** The codebase used ObservableObject ViewModels with KVO observers and manual state management.

**Pain Points:**
- Thread safety wasn't enforced at compile time
- Retry logic was scattered across ViewModels
- Testing required complex mocking of entire APIClient
- Manual task cancellation led to memory leaks
- Business logic lived in Views

**After:** Structured concurrency patterns ensure type-safe, testable code.

**Benefits:**
✅ Compile-time thread safety with actors  
✅ Reusable retry logic via RetryOrchestrator  
✅ Testable APIs via dependency injection  
✅ Automatic task cancellation with scoped tasks  
✅ Clean separation of concerns  

---

## Pattern 1: StateActor for Thread-Safe State {#pattern-1-stateactor}

### What It Is

`StateActor` is a generic Swift actor that manages state in a thread-safe, actor-isolated way. It's the modern replacement for `@Published` properties in ViewModels.

**Key Features:**
- Automatically MainActor-isolated for SwiftUI
- AsyncStream for reactive updates
- Sendable constraint ensures thread safety
- No memory leaks from retained closures

### When to Use It

✅ **Use StateActor when:**
- You need thread-safe state in a service or ViewModel
- You want to avoid `@Published` boilerplate
- You're handling long-lived async operations
- You need testable state mutations

❌ **Don't use StateActor when:**
- You just need a simple struct
- You're managing pure function inputs/outputs
- State doesn't change after initialization

### Refactoring Example: PlaybackStateActor

**Before (ObservableObject):**
```swift
@MainActor
class PlaybackViewModel: NSObject, ObservableObject {
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var errorMessage: String?
    
    func play() {
        isPlaying = true
        player.play()
    }
}
```

**After (StateActor):**
```swift
@MainActor
actor PlaybackStateActor {
    struct State: Sendable {
        var isPlaying = false
        var currentTime: Double = 0
        var duration: Double = 0
        var errorMessage: String?
    }
    
    private var _state = State()
    private let stateSubject = AsyncStream<State>.makeStream()
    
    var stateUpdates: AsyncStream<State> { stateSubject.stream }
    var currentState: State { _state }
    
    func play() {
        updateState { state in
            state.isPlaying = true
        }
    }
    
    func updateState(_ reducer: (inout State) -> Void) {
        reducer(&_state)
        stateSubject.continuation.yield(_state)
    }
}
```

**In SwiftUI View:**
```swift
struct VideoPlayerView: View {
    @State private var state: PlaybackStateActor.State?
    private let stateActor: PlaybackStateActor
    
    var body: some View {
        VStack {
            if let state = state, state.isPlaying {
                Text("Now Playing")
            }
        }
        .onAppear {
            Task {
                // Observe state updates
                var iterator = stateActor.stateUpdates.makeAsyncIterator()
                while let newState = await iterator.next() {
                    await MainActor.run {
                        self.state = newState
                    }
                }
            }
        }
    }
}
```

### Step-by-Step Refactoring

1. **Create State Struct**
   ```swift
   struct State: Sendable {
       var isPlaying = false
       var isLoading = false
       var error: String?
   }
   ```

2. **Inherit from GenericStateActor**
   ```swift
   @MainActor
   actor MyStateActor: GenericStateActor<MyStateActor.State> {
       struct State: Sendable { /* ... */ }
       
       init() {
           super.init(initialState: State())
       }
   }
   ```

3. **Replace @Published with updateState**
   ```swift
   // Old
   @Published var isPlaying = false
   
   // New
   func setIsPlaying(_ value: Bool) {
       updateState { $0.isPlaying = value }
   }
   ```

4. **Observe in Views**
   ```swift
   Task {
       for await state in stateActor.stateUpdates {
           // Update UI
       }
   }
   ```

---

## Pattern 2: RetryOrchestrator for Resilience {#pattern-2-retryorchestrator}

### What It Is

`RetryOrchestrator` is a centralized retry service that handles all retry logic with exponential backoff, state tracking, and status callbacks.

**Key Features:**
- Exponential backoff with jitter
- Retry attempt tracking
- Error capture and history
- Status message callbacks for logging
- Sendable for async/await compatibility

### When to Use It

✅ **Use RetryOrchestrator when:**
- Making API calls that might fail transiently
- Loading streams that need resilience
- You want consistent retry behavior across the app
- You need to track retry metrics

❌ **Don't use RetryOrchestrator when:**
- The operation cannot fail
- You're not calling external APIs
- Retrying would cause side effects

### Refactoring Example: Stream Loading

**Before (Manual retry in ViewModel):**
```swift
class PlaybackViewModel: ObservableObject {
    func loadStream(_ url: URL) {
        Task {
            var attempt = 0
            while attempt < 3 {
                do {
                    let stream = try await client.getStream(url)
                    DispatchQueue.main.async {
                        self.currentStream = stream
                    }
                    return
                } catch {
                    attempt += 1
                    if attempt < 3 {
                        try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt)) * 1_000_000_000))
                    }
                }
            }
        }
    }
}
```

**After (Using RetryOrchestrator):**
```swift
class PlaybackViewModel: ObservableObject {
    private let retryOrchestrator = RetryOrchestrator()
    
    func loadStream(_ url: URL) {
        Task {
            do {
                let stream = try await retryOrchestrator.attemptWithRetry {
                    try await self.client.getStream(url)
                } onError: { error, attempt in
                    print("❌ Load failed on attempt \(attempt): \(error)")
                }
                
                await MainActor.run {
                    self.currentStream = stream
                }
            } catch {
                print("Failed to load stream after retries")
            }
        }
    }
}
```

### Step-by-Step Refactoring

1. **Initialize RetryOrchestrator**
   ```swift
   private let retryOrchestrator = RetryOrchestrator(
       configuration: .production,
       onStatusChanged: { message in
           print("🔄 Retry: \(message)")
       }
   )
   ```

2. **Wrap Operation**
   ```swift
   let result = try await retryOrchestrator.attemptWithRetry {
       try await client.performOperation()
   } onError: { error, attempt in
       // Handle error on each attempt
   }
   ```

3. **Handle Success/Failure**
   ```swift
   do {
       let result = try await retryOrchestrator.attemptWithRetry { /* ... */ }
       // Success path
   } catch {
       // Failure path after all retries
   }
   ```

---

## Pattern 3: APIClientProvider for Dependency Injection {#pattern-3-apiclientprovider}

### What It Is

`APIClientProvider` is a protocol that abstracts API client creation, enabling:
- Easy swapping of real vs. mock clients
- Configuration management
- Testing without network calls

**Key Features:**
- Protocol-based design for testability
- Real and mock implementations provided
- Supports multiple endpoints
- Clean constructor injection

### When to Use It

✅ **Use APIClientProvider when:**
- Creating services that need API clients
- You want to test without making real API calls
- Multiple clients with different configurations exist
- You need to swap implementations for different environments

❌ **Don't use APIClientProvider when:**
- There's only one API client in the app
- You're not using dependency injection
- Unit testing isn't a concern

### Refactoring Example: StreamAdminService

**Before (Direct client creation):**
```swift
class StreamAdminService {
    func createStream(name: String) async throws -> Stream {
        let client = MediaMTXAPIClient(baseURL: URL(string: "http://localhost:9997")!)
        return try await client.createStream(name: name)
    }
}

// Testing requires network access or mocking inside client
```

**After (Using APIClientProvider):**
```swift
class StreamAdminService {
    private let clientProvider: APIClientProvider
    
    init(clientProvider: APIClientProvider) {
        self.clientProvider = clientProvider
    }
    
    func createStream(name: String) async throws -> Stream {
        let client = clientProvider.createAPIClient(
            baseURL: URL(string: "http://localhost:9997")!
        )
        return try await client.createStream(name: name)
    }
}

// Testing is simple:
let mockProvider = MockAPIClientProvider()
mockProvider.setMockClient(mockClient, forURL: testURL)
let service = StreamAdminService(clientProvider: mockProvider)
```

### Step-by-Step Refactoring

1. **Accept Provider in Constructor**
   ```swift
   class MyService {
       private let clientProvider: APIClientProvider
       
       init(clientProvider: APIClientProvider = DefaultAPIClientProvider()) {
           self.clientProvider = clientProvider
       }
   }
   ```

2. **Use Provider to Create Clients**
   ```swift
   func performRequest() async throws {
       let client = clientProvider.createAPIClient(baseURL: baseURL)
       return try await client.request()
   }
   ```

3. **Test with Mock**
   ```swift
   func testPerformRequest() async throws {
       let mockProvider = MockAPIClientProvider()
       mockProvider.defaultMockClient = mockClient
       
       let service = MyService(clientProvider: mockProvider)
       let result = try await service.performRequest()
       XCTAssertEqual(result, expected)
   }
   ```

---

## Pattern 4: Structured Concurrency with Task Management {#pattern-4-structured-concurrency}

### What It Is

Structured concurrency ensures all async operations are properly scoped, tracked, and cancelled. Swift's Task system provides automatic resource management.

**Key Features:**
- Tasks are cancelled when scope ends
- Parent-child task relationships tracked
- No manual cancellation needed
- Memory safe by default

### When to Use It

✅ **Use Structured Concurrency when:**
- You're in an async function (always!)
- Managing multiple concurrent operations
- You need to cancel work cleanly
- Dealing with long-lived operations

### Refactoring Example: Polling

**Before (Manual cancellation):**
```swift
class PlaybackViewModel: ObservableObject {
    var pollingTask: Task<Void, Never>?
    
    func startPolling() {
        pollingTask = Task {
            while !Task.isCancelled {
                do {
                    let status = try await client.getStatus()
                    DispatchQueue.main.async {
                        self.status = status
                    }
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                } catch {
                    break
                }
            }
        }
    }
    
    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }
    
    deinit {
        stopPolling()  // Easy to forget!
    }
}
```

**After (Structured Concurrency):**
```swift
class PlaybackViewModel: ObservableObject {
    @MainActor
    actor PollingActor {
        private var pollingTask: Task<Void, Never>?
        
        func startPolling(onUpdate: @escaping (Status) -> Void) {
            pollingTask = Task {
                while !Task.isCancelled {
                    do {
                        let status = try await client.getStatus()
                        onUpdate(status)
                        try await Task.sleep(nanoseconds: 1_000_000_000)
                    } catch is CancellationError {
                        return
                    } catch {
                        return
                    }
                }
            }
        }
        
        func stopPolling() {
            pollingTask?.cancel()
        }
    }
    
    // Automatic cleanup - no deinit needed
}
```

**In Views:**
```swift
struct VideoPlayerView: View {
    @State var task: Task<Void, Never>?
    
    var body: some View {
        VStack { /* ... */ }
            .onAppear {
                task = Task {
                    for await state in stateActor.stateUpdates {
                        // Handle updates
                    }
                }
            }
            .onDisappear {
                task?.cancel()
            }
    }
}
```

### Common Patterns

**Task Group for Parallel Work:**
```swift
try await withTaskGroup(of: Result.self) { group in
    for url in urls {
        group.addTask {
            try await client.fetch(url)
        }
    }
    
    for try await result in group {
        // Process results
    }
}
```

**Task.sleep for Delays:**
```swift
try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
```

**Cancellation Safety:**
```swift
guard !Task.isCancelled else { return }
```

---

## Common Refactoring Scenarios {#scenarios}

### Scenario 1: Convert @Published ViewModel to StateActor

**Goal:** Modernize an old ViewModel using @Published

**Steps:**
1. Create a State struct inside the actor
2. Move all @Published vars to State
3. Replace ViewModel methods to use updateState
4. Update Views to observe stateUpdates
5. Add tests

**Example PR:** See `feat(phase-7): add StateActor foundation` in git history

### Scenario 2: Add Retry Logic to an API Call

**Goal:** Make a flaky network call more resilient

**Steps:**
1. Add RetryOrchestrator to the service
2. Wrap the API call in attemptWithRetry
3. Add error handling and logging
4. Test with retry configuration
5. Commit with type: `feat(resilience)`

### Scenario 3: Make a Service Testable

**Goal:** Remove hard dependencies on APIClient

**Steps:**
1. Add APIClientProvider parameter to constructor
2. Use provider instead of creating clients directly
3. Create mock provider in tests
4. Verify all code paths can be tested
5. Commit with type: `refactor(di)`

### Scenario 4: Clean Up View Logic

**Goal:** Move business logic from View to ViewModel

**Steps:**
1. Audit the View for computed properties, conditions, transforms
2. Move each piece to appropriate ViewModel method or property
3. View now only observes properties and calls methods
4. Add unit tests for ViewModel logic
5. Commit with type: `refactor(views)`

---

## Testing Your Refactored Code {#testing}

### Unit Test Pattern

```swift
@MainActor
class PlaybackStateActorTests: XCTestCase {
    var actor: PlaybackStateActor!
    
    override func setUp() async throws {
        actor = PlaybackStateActor()
    }
    
    func testPlay() async throws {
        await actor.play()
        let state = await actor.currentState
        XCTAssertTrue(state.isPlaying)
    }
    
    func testStateUpdates() async throws {
        let updateTask = Task {
            var states: [PlaybackStateActor.State] = []
            var iterator = await actor.stateUpdates.makeAsyncIterator()
            
            while states.count < 2 && !Task.isCancelled {
                if let state = await iterator.next() {
                    states.append(state)
                }
            }
            return states
        }
        
        await actor.play()
        await actor.pause()
        
        let states = await updateTask.value
        XCTAssertEqual(states.count, 2)
    }
}
```

### Integration Test Pattern

```swift
class PlaybackViewModelIntegrationTests: XCTestCase {
    @MainActor
    func testLoadStreamWithRetry() async throws {
        let mockProvider = MockAPIClientProvider()
        let mockClient = MockMediaMTXAPIClient()
        mockProvider.defaultMockClient = mockClient
        
        let viewModel = PlaybackViewModel(clientProvider: mockProvider)
        
        try await viewModel.loadStream(testURL)
        
        XCTAssertNotNil(viewModel.currentStream)
    }
}
```

---

## Rollback Strategy {#rollback}

If a refactoring introduces bugs:

1. **Identify the commit**
   ```bash
   git log --oneline | grep "your refactoring"
   ```

2. **Check what changed**
   ```bash
   git show <commit-hash>
   ```

3. **Revert if needed**
   ```bash
   git revert <commit-hash> -m "Revert problematic refactoring"
   ```

4. **Create issue to track the problem**
   - Document the specific issue
   - Link to the reverted commit
   - Assign for follow-up

---

## Summary

| Pattern | Use Case | Replaces | Benefit |
|---------|----------|----------|---------|
| **StateActor** | Thread-safe state | @Published | Compile-time safety + simpler code |
| **RetryOrchestrator** | API resilience | Manual retry loops | Consistent, testable, reusable |
| **APIClientProvider** | Dependency injection | Direct client creation | Easy testing + flexibility |
| **Structured Concurrency** | Task management | Manual cancellation | Automatic cleanup + memory safety |

---

## Next Steps

- **For New Features:** Use these patterns from day one
- **For Existing Code:** Refactor high-risk areas first (networking, state)
- **For Reviews:** Check that refactored code uses correct patterns
- **For Questions:** See [docs/ARCHITECTURE.md](./ARCHITECTURE.md) for deep dives

---

**Last Updated:** August 2026
