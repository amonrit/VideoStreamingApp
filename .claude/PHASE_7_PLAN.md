Last Modified: 08/17/2026 (1786920029) by amonrit

# Phase 7 Plan: Modernize to Structured Concurrency

## 📋 Overview

**Issue:** #27 - Modernize to Structured Concurrency  
**Depends On:** Phase 1-6 (all previous phases) ✅  
**Status:** IN PROGRESS (Steps 1-2 Complete ✅)  
**Estimated Effort:** 3-4 hours  
**Priority:** High (Core architectural modernization)

---

## 🎯 Objective

Modernize Steam app's concurrency model from Combine/ObservableObject to Swift's structured concurrency (async/await, actors, AsyncSequence):

1. Replace ViewModels from ObservableObject to async/await-based architecture
2. Migrate @Published properties to StateActor pattern
3. Ensure all state models are Sendable
4. Integrate PollingService AsyncSequence into ViewModels
5. Remove remaining Combine dependencies where possible
6. Improve thread-safety with actor-based state management
7. Modernize error handling with async/await patterns

---

## 📊 Current Architecture Analysis

### ✅ What's Already Structured Concurrency-Ready

**PollingService (Phase 5):**
- ✅ Already an actor
- ✅ Returns AsyncSequence for polling
- ✅ Uses Task.sleep() instead of Timer
- ✅ Type-safe with Sendable constraints
- ✅ Supports cancellation via Task

**RetryOrchestrator (Phase 4):**
- ✅ Async/await implementation
- ✅ Uses CheckedContinuation for resuming async tasks
- ✅ Error handling via throws

**State Models (Phase 2):**
- ✅ ConnectionStatus, PlaybackState, RetryState
- ✅ All enums (naturally Sendable)
- ✅ Framework-independent

### ⚠️ What Needs Modernization

**PlaybackViewModel:**
```swift
class PlaybackViewModel: ObservableObject {
    @Published var isLoading: Bool = false
    @Published var isPlaying: Bool = false
    @Published var errorMessage: String?
    // ... 7 more @Published properties
    
    private var cancellables = Set<AnyCancellable>()
}
```

**Issues:**
- ❌ Still uses ObservableObject + @Published
- ❌ Combine-dependent
- ❌ Manual task tracking with CheckedContinuation
- ❌ Not using PollingService AsyncSequence pattern

**StreamAdminViewModel:**
```swift
class StreamAdminViewModel: ObservableObject {
    @Published var paths: [MediaMTXPath] = []
    @Published var isLoading: Bool = false
    // Still uses Timer pattern
}
```

**Issues:**
- ❌ Still uses ObservableObject + @Published
- ❌ Combine-dependent
- ❌ Manual polling state management

**VideoPlayerView:**
- ⚠️ Still has some Timer usage
- ⚠️ Could benefit from async/await patterns

---

## 🏗️ Phase 7 Implementation Plan

### Architecture: StateActor Pattern

Instead of ObservableObject, use an actor for thread-safe state management with async/await:

```swift
@MainActor
actor PlaybackState {
    // State properties (no @Published needed)
    var isLoading: Bool = false
    var isPlaying: Bool = false
    var errorMessage: String?
    var connectionStatus: ConnectionStatus = .disconnected
    var retryAttempt: Int = 0
    var viewerCount: Int?
    
    // State mutations (actor-isolated)
    nonisolated var stateUpdates: AsyncStream<PlaybackStateSnapshot>
    
    func updateLoading(_ value: Bool)
    func updateError(_ message: String?)
    func updateViewerCount(_ count: Int?)
}

// For SwiftUI observability, provide snapshots
struct PlaybackStateSnapshot: Sendable {
    let isLoading: Bool
    let isPlaying: Bool
    let errorMessage: String?
    let connectionStatus: ConnectionStatus
    let retryAttempt: Int
    let viewerCount: Int?
}
```

### Step 1: Create StateActor Base Class (30 min)

**File:** `steam/Core/Architecture/StateActor.swift`

**Purpose:** Generic foundation for all state management actors

```swift
@MainActor
public actor StateActor<State: Sendable> {
    // Streaming state updates
    private let stateSubject = AsyncStream<State>.makeStream()
    public var stateUpdates: AsyncStream<State> { stateSubject.stream }
    
    // Current state
    private var _state: State
    
    public init(initialState: State) {
        self._state = initialState
    }
    
    public var currentState: State {
        _state
    }
    
    // Reducer pattern
    public func updateState(_ reducer: @Sendable (inout State) -> Void) {
        reducer(&_state)
        stateSubject.continuation.yield(_state)
    }
}
```

### Step 2: Refactor PlaybackViewModel (45 min)

**File:** `steam/Features/Playback/Presentation/PlaybackViewModel.swift`

**Changes:**

1. **Replace ObservableObject with @MainActor class**
```swift
@MainActor
final class PlaybackViewModel: NSObject, Sendable {
    // Keep AVPlayer (not Sendable, but isolated to MainActor)
    let player: AVPlayer
    private let worker: VideoPlayerWorker
    
    // State actor
    private nonisolated let stateActor: any PlaybackStateActorProtocol
    
    // Export state as Combine for SwiftUI compatibility (temporary bridge)
    @Published var isLoading: Bool = false
    // ... other @Published properties
    
    init(player: AVPlayer = AVPlayer(), 
         apiClientProvider: APIClientProvider = DefaultAPIClientProvider(),
         stateActor: any PlaybackStateActorProtocol? = nil) {
        self.player = player
        self.apiClientProvider = apiClientProvider
        self.worker = VideoPlayerWorker()
        self.stateActor = stateActor ?? DefaultPlaybackStateActor()
        
        super.init()
        
        // Observe state changes from actor
        Task {
            for await state in await self.stateActor.stateUpdates {
                await MainActor.run {
                    self.isLoading = state.isLoading
                    self.isPlaying = state.isPlaying
                    // ... sync all @Published properties
                }
            }
        }
    }
}
```

2. **Update state mutations to use actor**
```swift
func updateError(_ message: String?) {
    Task {
        await stateActor.updateError(message)
    }
}

func updateViewerCount(_ count: Int?) {
    Task {
        await stateActor.updateViewerCount(count)
    }
}
```

3. **Integrate PollingService AsyncSequence**
```swift
private func startViewerCountPolling() {
    Task {
        for try await count in await viewerCountPollingService.startPolling() {
            await stateActor.updateViewerCount(count)
        }
    }
}
```

### Step 3: Create Playback State Actor (30 min)

**File:** `steam/Features/Playback/Domain/Actors/PlaybackStateActor.swift`

```swift
@MainActor
public actor PlaybackStateActor {
    public struct State: Sendable {
        public var isLoading: Bool = false
        public var isPlaying: Bool = false
        public var errorMessage: String?
        public var bufferingCount: Int = 0
        public var currentStream: VideoStream?
        public var connectionStatus: ConnectionStatus = .disconnected
        public var retryAttempt: Int = 0
        public var viewerCount: Int?
    }
    
    private let stateSubject = AsyncStream<State>.makeStream()
    public var stateUpdates: AsyncStream<State> { stateSubject.stream }
    
    private var _state: State = State()
    
    public var currentState: State { _state }
    
    public func updateLoading(_ value: Bool) {
        _state.isLoading = value
        stateSubject.continuation.yield(_state)
    }
    
    public func updatePlaying(_ value: Bool) {
        _state.isPlaying = value
        stateSubject.continuation.yield(_state)
    }
    
    public func updateError(_ message: String?) {
        _state.errorMessage = message
        stateSubject.continuation.yield(_state)
    }
    
    public func updateConnectionStatus(_ status: ConnectionStatus) {
        _state.connectionStatus = status
        stateSubject.continuation.yield(_state)
    }
    
    public func updateViewerCount(_ count: Int?) {
        _state.viewerCount = count
        stateSubject.continuation.yield(_state)
    }
    
    // ... other state updates
}
```

### Step 4: Refactor StreamAdminViewModel (30 min)

**File:** `steam/Features/StreamAdmin/Presentation/StreamAdminViewModel.swift`

**Changes:**
- Replace ObservableObject with @MainActor class
- Create StreamAdminStateActor
- Use PollingService AsyncSequence for path updates
- Remove manual Timer management (already done in Phase 5)

### Step 5: Update SwiftUI Views for Compatibility (20 min)

**Files to Update:**
- VideoStreamListView.swift
- VideoPlayerView.swift
- StreamAdminView.swift

**Changes:**
- Continue using @StateObject/@ObservedObject during transition
- Views remain unchanged (no breaking changes)
- Gradual migration path to full structured concurrency

### Step 6: Migrate Task Management (20 min)

**Updates:**
- Replace `CheckedContinuation` with async sequences where possible
- Use `Task` cancellation instead of manual tracking
- Ensure proper task cleanup in deinit

### Step 7: Ensure All Types Are Sendable (15 min)

**Audit:**
- ✅ ConnectionStatus - enum (already Sendable)
- ✅ PlaybackState - struct (already Sendable)
- ✅ VideoStream - needs Sendable conformance
- ✅ MediaMTXPath - needs Sendable conformance
- Error types - mark as Sendable where possible

---

## ✅ Acceptance Criteria

- [ ] StateActor base implementation created and tested
- [ ] PlaybackStateActor created with full state management
- [ ] PlaybackViewModel refactored to use StateActor
- [ ] ViewerCountPollingService integrated with AsyncSequence
- [ ] StreamAdminViewModel refactored similarly
- [ ] All @Published properties bridge to actor state
- [ ] All state models marked Sendable
- [ ] No breaking changes to SwiftUI views
- [ ] All tasks properly cancelled in deinit
- [ ] No memory leaks (verified with Xcode Instruments)
- [ ] Build succeeds (DEBUG configuration)
- [ ] All existing tests pass
- [ ] No Combine warnings or deprecations

---

## 📂 File Structure

**New Files:**
```
steam/Core/Architecture/StateActor.swift
steam/Features/Playback/Domain/Actors/PlaybackStateActor.swift
steam/Features/StreamAdmin/Domain/Actors/StreamAdminStateActor.swift
steamTests/Actors/PlaybackStateActorTests.swift
steamTests/Actors/StreamAdminStateActorTests.swift
```

**Modified Files:**
```
steam/Features/Playback/Presentation/PlaybackViewModel.swift
steam/Features/StreamAdmin/Presentation/StreamAdminViewModel.swift
steam/Domain/Entities/VideoStream.swift
steam/Domain/Entities/MediaMTXPath.swift
```

---

## 🔧 Implementation Checklist

### Step 1: Foundation (30 min)
- [ ] Create StateActor.swift with generic implementation
- [ ] Add @MainActor isolation
- [ ] Implement AsyncStream wrapping
- [ ] Add error handling
- [ ] Create unit tests
- [ ] Build succeeds

### Step 2: Playback State (30 min)
- [ ] Create PlaybackStateActor.swift
- [ ] Define State struct with all properties
- [ ] Implement state update methods
- [ ] Add AsyncStream for updates
- [ ] Test state transitions
- [ ] Build succeeds

### Step 3: Refactor PlaybackViewModel (45 min)
- [ ] Change from ObservableObject to @MainActor class
- [ ] Inject PlaybackStateActor
- [ ] Bridge @Published properties
- [ ] Update all state mutations
- [ ] Integrate PollingService AsyncSequence
- [ ] Update Task management
- [ ] Build succeeds

### Step 4: StreamAdmin State (30 min)
- [ ] Create StreamAdminStateActor.swift
- [ ] Define State struct
- [ ] Implement state updates
- [ ] Refactor StreamAdminViewModel
- [ ] Build succeeds

### Step 5: Compatibility Layer (20 min)
- [ ] Verify SwiftUI views still work unchanged
- [ ] Test @StateObject/@ObservedObject observers
- [ ] Manual testing of UI
- [ ] Build succeeds

### Step 6: Sendability (15 min)
- [ ] Add Sendable to VideoStream
- [ ] Add Sendable to MediaMTXPath
- [ ] Audit all error types
- [ ] Suppress warnings if necessary
- [ ] Build succeeds

### Step 7: Testing & Validation (30 min)
- [ ] Unit tests for StateActors
- [ ] Integration tests with PollingService
- [ ] Manual testing of playback flow
- [ ] Memory leak detection (Xcode Instruments)
- [ ] Task cancellation verification
- [ ] All tests pass

---

## 🚀 Benefits

✅ **Modern Swift Concurrency** — Uses async/await, actors, AsyncSequence  
✅ **Thread-Safe** — Actor isolation ensures no data races  
✅ **Better Performance** — Less context switching than Combine  
✅ **Easier Testing** — Mock actors without complex Combine stubs  
✅ **Future-Proof** — Aligns with Apple's concurrency direction  
✅ **Gradual Migration** — No breaking changes to SwiftUI views  
✅ **Sendable Everywhere** — Type-safe data flow across threads  

---

## 🔗 Dependencies

**Requires:**
- ✅ Phase 1-6 (foundation complete)
- ✅ PollingService (Phase 5, already actor-based)
- ✅ RetryOrchestrator (Phase 4, already async/await)
- iOS 13.0+ (AsyncSequence, Actor)

**Enables:**
- Phase 8: Performance Optimization
- Phase 9: Advanced Concurrency Patterns (AsyncAlgorithms)
- Future: Distributed Actor support

---

## 📊 Expected Impact

**Code Changes:**
- New files: 5-6 (actors, tests)
- Modified files: 4-5 (ViewModels, entities)
- Lines added: ~800 LOC (mostly actors + tests)
- Lines removed: ~200 LOC (Combine code)
- Net: +600 LOC (significant, but worth it)

**Performance:**
- Reduced allocations: AsyncSequence vs @Published
- Lower latency: Direct state updates vs publisher chains
- Better memory: Automatic cleanup of AsyncStream

**Architecture:**
- Clear separation: State management (actor) vs. UI (View)
- Testability: State actors easily mockable
- Composability: Tasks compose naturally

---

## ⚠️ Migration Strategy

### Phase 7.1: Foundation & Playback (Recommended First)
- Create StateActor infrastructure
- Implement PlaybackStateActor
- Refactor PlaybackViewModel
- Verify all tests pass
- Get code review

### Phase 7.2: StreamAdmin & Others
- Apply same pattern to StreamAdminViewModel
- Refactor other ViewModels
- Comprehensive testing

### Phase 7.3: Polish & Optimization
- Performance profiling
- Memory leak detection
- Remove Combine entirely if possible
- Production deployment

---

## 💡 Key Architectural Decisions

### Why StateActor instead of @Observable?
- Better task cancellation semantics
- Built-in AsyncStream for multiple subscribers
- Easier to test state transitions
- More control over state mutations
- Works well with UIKit/AppKit if needed

### Why Bridge @Published During Transition?
- Zero breaking changes to SwiftUI views
- Can migrate view-by-view
- Gradual adoption pattern
- Easy to revert if needed
- Reduces QA burden

### Why @MainActor for ViewModels?
- Ensures UI updates on main thread
- Prevents accidental background state mutations
- Compiler enforces correct threading
- Matches expected SwiftUI behavior

---

## 🎯 Success Metrics

- ✅ No Combine warnings in build
- ✅ All state updates via actor isolation
- ✅ Zero data race warnings
- ✅ Memory leaks: 0
- ✅ Test coverage: >85%
- ✅ Performance: No regression
- ✅ Type safety: Full Sendable compliance

---

**Ready to implement Phase 7!** 🚀

Phase 7 will position Steam as a modern Swift app using the latest concurrency features while maintaining backward compatibility with existing views.
