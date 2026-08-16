Last Modified: 08/17/2026 (1786922418) by amonrit

# Steam - Video Streaming App Architecture

## Overview

iOS video streaming app using **Model-View-ViewModel (MVVM)** architecture with HLS playback, adaptive bitrate, fullscreen support, and debug metrics.

**Tech Stack:**
- **Language**: Swift
- **UI Framework**: SwiftUI
- **Architecture**: MVVM (Model-View-ViewModel)
- **Playback**: AVFoundation (AVPlayer)
- **Reactive**: Combine + KVO

## Architecture Evolution Timeline

| Phase | Focus | Key Additions |
|-------|-------|----------------|
| **1-3** | Foundation | MVVM, AVPlayer, Views |
| **4** | Resilience | RetryOrchestrator, error handling |
| **5** | Testability | APIClientProvider, dependency injection |
| **6** | Observability | Polling services, metrics |
| **7** | Concurrency | StateActor, structured concurrency |
| **8** | Performance | Optimization, debouncing |
| **9** | Cleanup | View refactoring, logic consolidation |
| **11** | Handoff | Documentation, migration guides |

---

## MVVM Architecture

### 1. Model

**Data entities** that represent core concepts:
- `VideoStream` — URL, title, thumbnail
- `PlaybackState` — Internal state tracking (idle, loading, playing, error)

### 2. ViewModel

**PlaybackViewModel** — All business logic, state management, and observer setup:

**Responsibilities:**
- Load and manage playback lifecycle
- Setup KVO observers for player status, buffering, errors
- Update internal `playbackState` and publish to `@Published` properties
- Format debug info (resolution, bitrate)
- Handle stream errors and retry logic

**Published Properties:**
- `isLoading`, `isPlaying`, `errorMessage`
- `bufferingCount`, `currentStream`
- `resolutionText`, `bitrateText`

### 3. View

**HomeView** — Root app container (Navigation Hub)
- Navigation menu with options: Watch Streams, Settings, About, Help
- NavigationLink to VideoStreamListView

**VideoStreamListView** — Playback screen with stream management
- Owns `@StateObject private var playbackViewModel`
- Shows video list, current selection, debug panel
- Calls `viewModel.loadStream()` on stream selection

**VideoPlayerView** — Renders video player UI
- Player + Loading/Error overlays + Fullscreen button
- Calls `viewModel.retry()` on error

**FullScreenPlayerView** — Fullscreen player wrapper

### 4. Worker

**VideoPlayerWorker** — Reusable KVO observer setup:
- Setup Combine publishers for KVO changes
- All publishers deliver callbacks on main thread
- Extract debug info (resolution, bitrate)

---

## File Structure

```
steam/
├── steam/
│   ├── steamApp.swift
│   │
│   ├── Models/
│   │   ├── VideoStream.swift          (Entity)
│   │   └── PlaybackState.swift        (Entity)
│   │
│   ├── ViewModels/
│   │   └── PlaybackViewModel.swift    (ViewModel + Business Logic)
│   │
│   ├── Views/
│   │   ├── HomeView.swift             (Root entry point - Navigation menu)
│   │   ├── VideoStreamListView.swift  (Playback & stream management)
│   │   ├── VideoPlayerView.swift      (Player UI component)
│   │   └── FullScreenPlayerView.swift (Fullscreen player container)
│   │
│   └── Workers/
│       └── VideoPlayerWorker.swift    (Reusable KVO/Combine Setup)
│
└── steam.xcodeproj/
```

---

## Component Responsibilities

| Component | Type | Responsibility |
|-----------|------|-----------------|
| **PlaybackViewModel** | ViewModel | Business logic, state, observer setup |
| **VideoPlayerView** | View | Player + overlays, calls ViewModel actions |
| **FullScreenPlayerView** | View | Fullscreen container |
| **HomeView** | View | Root menu, navigation hub |
| **VideoStreamListView** | View | Stream list, selection, debug panel |
| **VideoPlayerWorker** | Utility | KVO setup, formatting |
| **PlaybackState** | Model | Data entity |
| **VideoStream** | Model | Data entity |

---

## State Management

### PlaybackViewModel Internal State
- `playbackState: PlaybackState` — internal tracking of stream + playback status
- `@Published` properties — synced to UI via Combine
- `cancellables: Set<AnyCancellable>` — KVO subscription management

### VideoStreamListView Local State
- `@StateObject playbackViewModel` — preserved across re-renders (prevents AVPlayer leak)
- `@State showDebug` — pure UI state, not synced to ViewModel

### Data Flow
1. User action → ViewModel method called
2. ViewModel updates `playbackState` internally
3. `updatePlaybackViewModel()` copies to `@Published` properties on main thread
4. SwiftUI observes `@Published` → re-renders

---

## Key Benefits of MVVM

✅ **Simplicity** — Single ViewModel owns all logic  
✅ **Testability** — ViewModel can be tested independently  
✅ **State Management** — Combine `@Published` is SwiftUI-native  
✅ **No Routing Complexity** — No protocols, DTOs, or dependency injection boilerplate  
✅ **Direct Data Binding** — Views directly observe ViewModel  
✅ **Memory Safety** — `@StateObject` prevents AVPlayer leaks on re-render  

---

## Modern Architectural Patterns (Phase 7+)

### 1. StateActor: Thread-Safe State Management

**Problem Solved:** ObservableObject + @Published was not thread-safe at compile time

**Solution:** Generic `StateActor` using Swift's structured concurrency

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

**Benefits:**
- Compile-time thread safety
- AsyncStream for reactive updates
- Automatic task cancellation
- Sendable constraint prevents data races

**When to Use:** Any long-lived state that needs thread-safe mutations

**See Also:** [ADR-001: Structured Concurrency](./adr/ADR-001-structured-concurrency.md)

### 2. RetryOrchestrator: Centralized Retry Logic

**Problem Solved:** Retry logic scattered across ViewModels, inconsistent strategies

**Solution:** Centralized service with exponential backoff and state tracking

```swift
let orchestrator = RetryOrchestrator(configuration: .production)

let stream = try await orchestrator.attemptWithRetry {
    try await client.getStream(url)
} onError: { error, attempt in
    logger.error("Attempt \(attempt) failed: \(error)")
}
```

**Features:**
- Exponential backoff with jitter
- Configurable retry counts and delays
- Status callbacks for logging
- Error tracking and classification

**Strategies:**
- `production`: 3 attempts, 1-30s backoff
- `testing`: 1 attempt, no delays
- `aggressive`: 5 attempts for critical operations

**See Also:** [ADR-002: Retry Orchestrator](./adr/ADR-002-retry-orchestrator.md)

### 3. APIClientProvider: Dependency Injection

**Problem Solved:** Hard-coded API clients, difficult testing, no flexibility

**Solution:** Protocol-based factory for client creation

```swift
protocol APIClientProvider {
    func createAPIClient(baseURL: URL) -> MediaMTXAPIClient
    func getDefaultClient() -> MediaMTXAPIClient?
}

class StreamAdminService {
    init(clientProvider: APIClientProvider = DefaultAPIClientProvider()) {
        self.clientProvider = clientProvider
    }
}
```

**Implementations:**
- `DefaultAPIClientProvider` — Production with real API
- `MockAPIClientProvider` — Testing with mock responses

**Benefits:**
- Easy testing without network calls
- Swappable implementations
- Centralized configuration
- 100x faster test execution

**See Also:** [ADR-003: Dependency Injection](./adr/ADR-003-dependency-injection.md)

### 4. Polling Services: Structured Concurrency

**Problem Solved:** Manual timer management, difficult cancellation, memory leaks

**Solution:** Task-based polling with automatic cleanup

```swift
func startPolling() async {
    while !Task.isCancelled {
        try await Task.sleep(nanoseconds: 1_000_000_000)
        let status = try await client.getStatus()
        // Handle status
    }
}

// Automatic cleanup on task cancellation
```

**Features:**
- AsyncStream for state updates
- Automatic cancellation on scope exit
- No manual timer management
- Memory safe by default

---

## Complete Architecture Diagram

```
┌─────────────────────────────────────────────┐
│             SwiftUI Views                   │
│  ┌──────────────┬──────────────┐           │
│  │ HomeView     │ VideoPlayer  │           │
│  │ StreamList   │ FullScreen   │           │
│  └──────────────┴──────────────┘           │
└────────────────┬────────────────────────────┘
                 │ observes AsyncStream
                 ▼
      ┌──────────────────────────┐
      │   StateActors            │
      │  ┌────────────────────┐  │
      │  │PlaybackStateActor  │  │
      │  │StreamAdminStateAct │  │
      │  └────────────────────┘  │
      └────────┬─────────────────┘
               │ calls methods
               ▼
    ┌──────────────────────────────────┐
    │   ViewModels & Services          │
    │  ┌──────────────────────────┐   │
    │  │PlaybackViewModel         │   │
    │  │StreamAdminViewModel      │   │
    │  └──────────────────────────┘   │
    │  ┌──────────────────────────┐   │
    │  │RetryOrchestrator         │   │
    │  │Polling Services          │   │
    │  └──────────────────────────┘   │
    └────────┬────────────────────────┘
             │
    ┌────────▼──────────────────────┐
    │  APIClientProvider (DI)       │
    │  ├─ DefaultAPIClientProvider │
    │  └─ MockAPIClientProvider    │
    └────────┬──────────────────────┘
             │
             ▼
    ┌────────────────────────────┐
    │  MediaMTXAPIClient         │
    │  └─ Network Calls (HTTP)   │
    └────────┬───────────────────┘
             │
             ▼
    ┌────────────────────────────┐
    │  MediaMTX Server           │
    │  ├─ RTMP Publishing        │
    │  ├─ HLS Playback           │
    │  └─ Stream Management      │
    └────────────────────────────┘
```

---

## Data Flow: Complete Path

### User Plays a Stream

1. **View Action** → User taps "Play Stream"
2. **StateActor** → PlaybackStateActor.play() called
3. **ViewModel** → PlaybackViewModel delegates to RetryOrchestrator
4. **Retry** → RetryOrchestrator.attemptWithRetry() starts
5. **DI** → APIClientProvider creates MediaMTXAPIClient
6. **Network** → Client makes HTTP request to server
7. **Server** → MediaMTX returns stream URL
8. **State Update** → StateActor broadcasts new state
9. **AsyncStream** → Views observe state update
10. **UI** → SwiftUI re-renders with new stream playing

### Error Handling Path

1. Network call fails → RetryOrchestrator catches error
2. Checks if error is recoverable (timeouts, server errors)
3. If recoverable → Exponential backoff sleep + retry
4. If not recoverable → Error bubbles to ViewModel
5. ViewModel updates state with error message
6. StateActor broadcasts error state
7. View observes error and shows alert

---

## Testing Architecture

### Unit Tests

Test in isolation with mocks:
- StateActors ← Test state mutations
- ViewModels ← Test logic without network
- RetryOrchestrator ← Test backoff and state
- Services ← Test with MockAPIClientProvider

### Integration Tests

Test components together:
- StateActor + ViewModel
- ViewModel + Network (mock)
- Full flow with mocks

### Performance Tests

Measure performance:
- StateActor update throughput
- Memory usage during polling
- Task cancellation overhead

---

**Architecture**: MVVM + Actors + DI  
**Concurrency Model**: Structured Concurrency (async/await)  
**State Management**: StateActor + AsyncStream  
**Resilience**: RetryOrchestrator  
**Testing**: Dependency Injection via APIClientProvider  
**Platform**: iOS (SwiftUI) + MediaMTX Server  
**Last Updated**: August 2026  

---

## Quick References

- **[REFACTORING_GUIDE.md](./REFACTORING_GUIDE.md)** — How to modernize code
- **[adr/ADR-001-structured-concurrency.md](./adr/ADR-001-structured-concurrency.md)** — StateActor decisions
- **[adr/ADR-002-retry-orchestrator.md](./adr/ADR-002-retry-orchestrator.md)** — Retry decisions
- **[adr/ADR-003-dependency-injection.md](./adr/ADR-003-dependency-injection.md)** — DI decisions
- **[DEVELOPMENT.md](./DEVELOPMENT.md)** — Development workflow
- **[DEPLOYMENT.md](./DEPLOYMENT.md)** — Production deployment
