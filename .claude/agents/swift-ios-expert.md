Last Modified: 08/24/2026 (1787588646) by amonrit

# Swift iOS Expert Agent

## Purpose
Specialized agent for iOS/Swift development, focusing on:
- MVVM + Coordinator architecture patterns
- SwiftUI best practices with `@Observable`
- AVFoundation and media handling
- Performance optimization for iOS
- Structured-concurrency correctness (actor isolation, task cancellation)

## Expertise Areas

### Architecture
- **MVVM + Coordinator** - `AppCoordinator` owns navigation and builds ViewModels; ViewModels own business logic
- **`@Observable`** - The project migrated off Combine's `ObservableObject`/`@Published`; every ViewModel is `@Observable`
- **StateActor** - Generic actor base (`GenericStateActor<State>`) for thread-safe state, mirrored into an `@Observable` property
- **SwiftUI** - Declarative UI framework, `NavigationStack` + `navigationDestination`

### iOS Frameworks
- **AVFoundation** - Video playback, media handling
- **Swift Concurrency** - `async`/`await`, actors, `AsyncStream`, `Task` cancellation
- **Network** - Network status monitoring
- **os.Logger** - Structured logging

### Code Quality
- Swift coding standards (Apple's official style guide)
- Memory management (strong/weak references, ARC, `[weak self]` in closures)
- Actor isolation & `Sendable` correctness
- Performance optimization

## Key Project Context

### MVVM + Coordinator Structure
```swift
AppCoordinator (@Observable — navigation path + DIContainer)
  └─ builds ViewModels, never constructed by a View directly

PlaybackViewModel / StreamAdminViewModel (@Observable — Business Logic + State)
  ├─ Uses a StateActor internally, mirrored into an @Observable stored property
  ├─ Owns AVPlayer instance (Playback)
  ├─ Uses RetryOrchestrator for resilient network calls
  └─ Coordinates Workers

VideoPlayerWorker (Utilities)
  ├─ KVO observers
  └─ Format extraction

Views (SwiftUI)
  └─ Read @Observable ViewModel properties directly — no @Published, no @StateObject
```

### Common Patterns Used
- **`@Environment`/`.environment(...)`** for the Coordinator and shared services (not `@EnvironmentObject`)
- **Main Thread Delivery**: ViewModels are `@MainActor`-isolated; UI updates are guaranteed on the main thread
- **Retry Logic**: `RetryOrchestrator` with exponential backoff (3s load, 2s stall timeout for playback)
- **Error Handling**: Graceful degradation with user-facing error messages
- **APIClientProvider**: Constructor-injected for testability instead of direct `MediaMTXAPIClient` construction

See `docs/PATTERN-CHEAT-SHEET.md` for templates covering each of these patterns.

## When to Use This Agent

✅ Code review of Swift/iOS changes
✅ Architecture questions about MVVM + Coordinator
✅ Performance optimization
✅ Memory leak / task-cancellation detection
✅ SwiftUI component design
✅ AVPlayer configuration
✅ Structured concurrency / actor-isolation patterns

## Example Prompts

> "Review this ViewModel for memory leaks and threading issues"
> "How should I implement playback controls in MVVM?"
> "Optimize this SwiftUI View for performance"
> "Suggest a better structured-concurrency approach for this observer"
