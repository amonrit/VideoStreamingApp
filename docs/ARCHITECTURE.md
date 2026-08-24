Last Modified: 08/24/2026 (1787587709) by amonrit

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
| **11** | Handoff | Documentation, ADRs |
| **12+** | Modernization | Repository/DataSource scaffold removed, `KeychainManager`/`URLLogger` became actors, ViewModels migrated to `@Observable`, navigation/DI moved to a Coordinator pattern (`AppCoordinator`/`DIContainer`, [ADR-004](./adr/ADR-004-coordinator-navigation.md)) |

---

## MVVM Architecture

### 1. Model

**Data entities** that represent core concepts:
- `VideoStream` — URL, title, thumbnail
- `PlaybackState` — Internal state tracking (idle, loading, playing, error)

### 2. ViewModel

**PlaybackViewModel** — `@MainActor @Observable` class holding all business logic, state management, and observer setup:

**Responsibilities:**
- Load and manage playback lifecycle
- Setup KVO observers for player status, buffering, errors
- Mirror `PlaybackStateActor`'s state into a local, `@Observable`-tracked property (see [ADR-001](./adr/ADR-001-structured-concurrency.md))
- Format debug info (resolution, bitrate)
- Handle stream errors and retry logic via `RetryOrchestrator`

**Observable Properties** (computed from the mirrored actor state):
- `isLoading`, `isPlaying`, `errorMessage`
- `bufferingCount`, `currentStream`, `connectionStatus`, `viewerCount`
- `resolutionText`, `bitrateText`

Note: this is `@Observable`, not `ObservableObject`/`@Published` — the project migrated
off Combine's observation system. See [ADR-001](./adr/ADR-001-structured-concurrency.md).

### 3. View

**HomeView** — Root app container (Navigation Hub)
- Navigation menu with options: Watch Streams, Stream Admin, Settings, About (mock), Help (mock)
- Navigates via `@Environment(AppCoordinator.self)` + `coordinator.navigate(to:)`, not `NavigationLink(destination:)`

**VideoStreamListView** — Playback screen with stream management
- Receives its `PlaybackViewModel` from `AppCoordinator` (constructed via `DIContainer`) instead of owning a `@StateObject`
- Shows video list, current selection, debug panel
- Calls `viewModel.loadStream()` on stream selection

**VideoPlayerView** — Renders video player UI
- Player + Loading/Error overlays + Fullscreen button
- Calls `viewModel.retry()` on error

**FullScreenPlayerView** — Fullscreen player wrapper

**StreamAdminView** — Live stream/viewer monitoring screen, mirrors `VideoStreamListView`'s shape with `StreamAdminViewModel`

**SettingsView** — App settings (theme, etc.), real screen (not a mock)

### 4. Worker

**VideoPlayerWorker** — Reusable KVO observer setup:
- Sets up KVO observers for player/item status changes
- All callbacks deliver on the main thread
- Extract debug info (resolution, bitrate)

---

## File Structure

```
steam/
├── steam/
│   ├── App/
│   │   ├── steamApp.swift               (Entry point)
│   │   ├── AppCoordinator.swift         (Navigation + DI, @Observable)
│   │   └── Navigation/AppRoute.swift    (Navigation destinations)
│   │
│   ├── Core/
│   │   ├── Architecture/StateActor.swift    (Generic thread-safe state base)
│   │   ├── DI/
│   │   │   ├── APIClientProvider.swift
│   │   │   └── DIContainer.swift
│   │   ├── Managers/
│   │   │   ├── KeychainManager.swift    (actor)
│   │   │   └── ThemeManager.swift       (@Observable)
│   │   ├── Networking/MediaMTXAPIClient.swift
│   │   └── Utils/                       (RetryStrategy, PollingService, URLValidator, ...)
│   │
│   ├── Features/
│   │   ├── Home/Presentation/HomeView.swift
│   │   ├── Playback/
│   │   │   ├── Domain/
│   │   │   │   ├── Entities/            (VideoStream, PlaybackState, ConnectionStatus, RetryState)
│   │   │   │   ├── Actors/PlaybackStateActor.swift
│   │   │   │   └── Services/            (RetryOrchestrator, ViewerCountPollingService)
│   │   │   └── Presentation/
│   │   │       ├── PlaybackViewModel.swift    (ViewModel + Business Logic)
│   │   │       ├── VideoStreamListView.swift  (Playback & stream management)
│   │   │       ├── VideoPlayerView.swift      (Player UI component)
│   │   │       ├── VideoPlayerWorker.swift    (Reusable KVO Setup)
│   │   │       └── FullScreenPlayerView.swift (Fullscreen player container)
│   │   ├── StreamAdmin/                 (Domain + Presentation, mirrors Playback's shape)
│   │   └── Settings/Presentation/SettingsView.swift
│   │
│   ├── DesignSystem/
│   └── Resources/
│
└── steam.xcodeproj/
```

There is no `Repository`/`DataSource` layer: it was scaffolded early on (`Domain/Repositories`,
`Data/Repositories`, `Data/DataSources`), never wired up (it only returned placeholder data),
and has since been removed. ViewModels call `MediaMTXAPIClient` directly through
`APIClientProvider`. If a real need shows up (a second data source to combine, or logic that
needs to be shared outside a ViewModel), extract it from the working ViewModel at that point.

---

## Component Responsibilities

| Component | Type | Responsibility |
|-----------|------|-----------------|
| **AppCoordinator** | Coordinator | Navigation state, builds ViewModels via `DIContainer` |
| **PlaybackViewModel** | ViewModel | Business logic, state, observer setup |
| **StreamAdminViewModel** | ViewModel | Stream/viewer monitoring, polling |
| **VideoPlayerView** | View | Player + overlays, calls ViewModel actions |
| **FullScreenPlayerView** | View | Fullscreen container |
| **HomeView** | View | Root menu, navigation hub |
| **VideoStreamListView** | View | Stream list, selection, debug panel |
| **StreamAdminView** | View | Stream/viewer monitoring UI |
| **VideoPlayerWorker** | Utility | KVO setup, formatting |
| **PlaybackState** | Entity | Data entity |
| **VideoStream** | Entity | Data entity |

---

## State Management

### PlaybackViewModel Internal State
- `stateActor: DefaultPlaybackStateActor` — the actual source of truth, mutated only through `updateX(...)` calls
- `state: PlaybackStateSnapshot` — a private, `@Observable`-tracked mirror kept in sync by a `Task` observing `stateActor.stateUpdates`
- Public `var isLoading: Bool { state.isLoading }`-style computed properties — what Views actually read

### VideoStreamListView Local State
- `playbackViewModel` — received from `AppCoordinator`/`DIContainer`, not owned via `@StateObject` (there's no `ObservableObject` here to wrap)
- `@State showDebug` — pure UI state, not synced to the ViewModel

### Data Flow
1. User action → ViewModel method called
2. ViewModel calls `await stateActor.updateX(...)`, which mutates the actor's state and yields it on `stateUpdates`
3. The ViewModel's observer `Task` receives the new state and assigns it to its private `state` property
4. `@Observable` tracks that assignment → SwiftUI re-renders any View reading a computed property derived from it

---

## Key Benefits of MVVM + Coordinator

✅ **Simplicity** — Single ViewModel owns all logic  
✅ **Testability** — ViewModel can be tested independently, and `AppCoordinator` can be built with mock dependencies  
✅ **State Management** — `@Observable` is SwiftUI-native, no Combine boilerplate  
✅ **Centralized Navigation** — One `AppCoordinator` owns the nav path; Views never build their own ViewModels  
✅ **Direct Data Binding** — Views directly read `@Observable` ViewModel properties  
✅ **Memory Safety** — the ViewModel's lifetime is tied to the navigation stack via `AppCoordinator`, not a View-owned `@StateObject`  

---

## Modern Architectural Patterns (Phase 7+)

### 1. StateActor: Thread-Safe State Management

**Problem Solved:** `ObservableObject` + `@Published` wasn't thread-safe at compile time, and ViewModels needed a way to mutate state from multiple async contexts safely

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

### 5. Coordinator: Navigation & Dependency Injection

**Problem Solved:** Navigation state scattered across Views, `DIContainer` existed but had no caller, `AppCoordinator` was an unwired template (issues #33, #35)

**Solution:** `AppCoordinator` (`@Observable`) owns the `NavigationStack`'s path and is the only place that builds ViewModels, via a `DIContainer` it holds privately

```swift
@MainActor @Observable
final class AppCoordinator {
    var navigationPath: [AppRoute] = []
    private let diContainer: DIContainer

    func navigate(to route: AppRoute) { navigationPath.append(route) }

    @ViewBuilder
    func navigationView(for route: AppRoute) -> some View {
        switch route {
        case .watchStreams: VideoStreamListView(playbackViewModel: makePlaybackViewModel())
        case .streamAdmin: StreamAdminView(viewModel: makeStreamAdminViewModel())
        case .settings: SettingsView()
        }
    }
}
```

**Features:**
- Single source of truth for "where am I in the app"
- Views never construct their own ViewModels
- `DIContainer` has exactly one caller, so it's easy to swap in mocks for tests

**See Also:** [ADR-004: Coordinator](./adr/ADR-004-coordinator-navigation.md)

---

## Complete Architecture Diagram

```
┌─────────────────────────────────────────────┐
│              AppCoordinator                  │
│   (navigation path + DIContainer, builds     │
│    every ViewModel below)                    │
└────────────────┬────────────────────────────┘
                 │ injects
                 ▼
┌─────────────────────────────────────────────┐
│             SwiftUI Views                   │
│  ┌──────────────┬──────────────┐           │
│  │ HomeView     │ VideoPlayer  │           │
│  │ StreamList   │ FullScreen   │           │
│  │ StreamAdmin  │ Settings     │           │
│  └──────────────┴──────────────┘           │
└────────────────┬────────────────────────────┘
                 │ reads @Observable properties
                 ▼
    ┌──────────────────────────────────┐
    │   ViewModels (@Observable)       │
    │  ┌──────────────────────────┐   │
    │  │PlaybackViewModel         │   │
    │  │StreamAdminViewModel      │   │
    │  └───────────┬──────────────┘   │
    │              │ mirrors stateUpdates
    │              ▼                   │
    │  ┌──────────────────────────┐   │
    │  │StateActors               │   │
    │  │ PlaybackStateActor       │   │
    │  │ StreamAdminStateActor    │   │
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

**Architecture**: MVVM + Coordinator + Actors + DI  
**Concurrency Model**: Structured Concurrency (async/await)  
**State Management**: StateActor + AsyncStream, mirrored into `@Observable` ViewModels  
**Navigation & DI**: AppCoordinator + DIContainer  
**Resilience**: RetryOrchestrator  
**Testing**: Dependency Injection via APIClientProvider  
**Platform**: iOS (SwiftUI) + MediaMTX Server  
**Last Updated**: August 2026  

---

## Quick References

- **[PATTERN-CHEAT-SHEET.md](./PATTERN-CHEAT-SHEET.md)** — Templates & checklists for every pattern
- **[adr/ADR-001-structured-concurrency.md](./adr/ADR-001-structured-concurrency.md)** — StateActor decisions
- **[adr/ADR-002-retry-orchestrator.md](./adr/ADR-002-retry-orchestrator.md)** — Retry decisions
- **[adr/ADR-003-dependency-injection.md](./adr/ADR-003-dependency-injection.md)** — DI decisions
- **[adr/ADR-004-coordinator-navigation.md](./adr/ADR-004-coordinator-navigation.md)** — Coordinator decisions
- **[DEVELOPMENT.md](./DEVELOPMENT.md)** — Development workflow
- **[DEPLOYMENT.md](./DEPLOYMENT.md)** — Production deployment
