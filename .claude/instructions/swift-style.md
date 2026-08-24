Last Modified: 08/24/2026 (1787587709) by amonrit

# Swift Code Style Guide

This guide defines the Swift coding standards for the Steam project.

---

## Naming Conventions

### Types (Classes, Structs, Enums)
- **PascalCase** - Always start with uppercase
- Use descriptive names
- Example: `PlaybackViewModel`, `VideoPlayerWorker`, `ConnectionStatus`

### Variables & Constants
- **camelCase** - Start with lowercase
- Be descriptive but concise
- Example: `isLoading`, `currentStream`, `bufferingCount`

### Functions & Methods
- **camelCase** - Start with lowercase
- Use verb phrases for actions
- Example: `loadStream()`, `setupObservers()`, `handleBuffering()`

### Constants
- **UPPER_SNAKE_CASE** or **camelCase**
- Use for module-level constants
- Example: `let maxRetries = 2` or `private let loadTimeout: TimeInterval = 3.0`

---

## Code Organization

### File Structure
```swift
//
//  FileName.swift
//  steam
//
//  Created by Developer on Date.
//

import Foundation
import SwiftUI

// MARK: - Main Type
@MainActor
@Observable
final class MyType {

    // MARK: - Properties
    var state: String = ""
    private var internalState: String

    // MARK: - Lifecycle
    init() { }

    // MARK: - Public Interface
    func publicMethod() { }

    // MARK: - Private Helpers
    private func privateHelper() { }
}
```

### MARK Sections
Use MARK comments to organize code:
```swift
// MARK: - Properties
// MARK: - Lifecycle / Init
// MARK: - Public Interface
// MARK: - State Management
// MARK: - Private Helpers
// MARK: - Logging
```

---

## Indentation & Formatting

### Spaces
- **4 spaces** for indentation (not tabs)
- Match `.editorconfig` settings

### Line Length
- **Max 120 characters** per line
- Break long lines for readability
- Align parameters for clarity

### Braces
- Opening brace on same line (1TBS style)
```swift
class MyClass {
    func myMethod() {
        if condition {
            // code
        }
    }
}
```

---

## SwiftUI Best Practices

### View Composition
```swift
struct MyView: View {
    let viewModel: MyViewModel
    @State private var isExpanded = false

    var body: some View {
        VStack {
            headerView
            contentView
            footerView
        }
    }

    // MARK: - Private Views
    private var headerView: some View {
        Text("Header")
    }
}
```

### Getting a ViewModel
- Views never construct their own ViewModel. `AppCoordinator` builds it (via `DIContainer`) and either passes it into the destination view's initializer or the view reads `@Environment(AppCoordinator.self)` to navigate to a screen that will receive one.
- Example: `VideoStreamListView(playbackViewModel: coordinator.makePlaybackViewModel())`

### State Management
- Keep UI-only state in the View (`@State`) — things like "is this sheet showing", not business state
- Business logic & state lives in the ViewModel, which is `@Observable` (never `ObservableObject`/`@Published`)
- Long-lived state that multiple methods mutate goes through a `StateActor`, mirrored into a stored `@Observable` property (see `docs/PATTERN-CHEAT-SHEET.md`)
- Don't duplicate state between a View's `@State` and the ViewModel

---

## MVVM Architecture

### ViewModel Responsibilities
```swift
@MainActor
@Observable
final class PlaybackViewModel {
    // 1. State, mirrored from a StateActor (see docs/PATTERN-CHEAT-SHEET.md)
    private var state = PlaybackStateSnapshot()
    var isLoading: Bool { state.isLoading }
    var currentStream: VideoStream? { state.currentStream }

    // 2. Own important objects (AVPlayer, networking)
    let player: AVPlayer
    private let worker: VideoPlayerWorker
    private let apiClientProvider: APIClientProvider

    // 3. Business logic methods
    func loadStream(_ stream: VideoStream) { }
    func play() { }
    func pause() { }

    // 4. Internal state management
    private let stateActor: DefaultPlaybackStateActor
    @ObservationIgnored private nonisolated(unsafe) var stateObserverTask: Task<Void, Never>?
}
```

### Worker Responsibilities
```swift
class VideoPlayerWorker {
    // 1. Reusable utilities
    func setupKVOObservers(...) { }
    
    // 2. Format extraction
    func getResolution(from player: AVPlayer) -> String { }
    
    // 3. Return results via closures
    // NO UI updates, NO state management
}
```

---

## Error Handling

### User-Facing Errors
```swift
private func presentError(_ message: String) {
    logger.error("Error: \(message, privacy: .public)")
    errorMessage = message
}
```

### Logging Errors
```swift
import os

private let logger = Logger(subsystem: "amonrit.steam", category: "playback")

logger.error("Failed to load stream: \(error.localizedDescription)")
logger.debug("URL: \(streamURL.absoluteString)")
```

---

## KVO & Worker Callbacks

### Observer Setup
```swift
private func setupObservers(for item: AVPlayerItem) {
    worker.setupKVOObservers(
        for: item,
        player: player,
        onStatusChange: { [weak self] status in
            self?.handleStatusChange(status)
        }
    )
    // All callbacks are guaranteed main thread
}
```

### Main Thread Guarantee
- Workers deliver all callbacks on the main thread
- ViewModels are `@MainActor`-isolated, so no `DispatchQueue.main.async` is needed either in Views or ViewModels

---

## Memory Management

### Weak Self in Callbacks
```swift
setupObservers(
    onStatusChange: { [weak self] status in
        self?.handleStatusChange(status)
    }
)
```

### ViewModel Lifetime
ViewModels aren't created by the View — `AppCoordinator` builds one per navigation and passes it into the destination view's initializer, so it lives for the screen's lifetime without needing `@StateObject`/`@ObservedObject` at all:
```swift
// AppCoordinator.navigationView(for:)
case .watchStreams:
    VideoStreamListView(playbackViewModel: makePlaybackViewModel())
```

Cancel any `Task`s the ViewModel started (state observers, polling) in `deinit`.

---

## Optional Handling

### Guard Let
```swift
guard let url = stream.url else {
    presentError("Invalid URL")
    return
}
```

### Optional Chaining
```swift
if let error = error {
    handleError(error)
}
```

---

## Comments

### When to Comment
- **WHY** the code exists (architectural decisions)
- **Non-obvious** logic or workarounds
- **Gotchas** or known limitations

### Avoid
- Obvious comments ("increment counter")
- Duplicate information (code speaks for itself)

### Example
```swift
// ✅ GOOD - Explains why
// FIX: Strip session parameters for MediaMTX HLS compatibility
if let questionMarkIndex = urlString.firstIndex(of: "?") {
    cleanURLString = String(urlString[..<questionMarkIndex])
}

// ❌ BAD - Obvious comment
// Remove everything after ?
```

---

## Logging Format

### Structured Logging
```swift
import os

private let logger = Logger(subsystem: "amonrit.steam", category: "playback")

// Info
logger.info("✅ AVPlayer configured for HLS streaming")

// Error
logger.error("❌ Invalid URL: \(url, privacy: .public)")

// Debug
logger.debug("   Stream: \(streamName)")
```

### Emoji Convention
- ✅ Success, completion
- ❌ Error, failure
- 📥 Input, loading
- 📤 Output, saving
- 🔄 Retry, reset
- ⚠️ Warning
- 📊 Debug info

---

## Testing

### Test File Naming
- `MyClass.swift` → `MyClassTests.swift`
- Location: `steam/Tests/`

### Test Method Naming
```swift
func testLoadStreamWithValidURL() { }
func testLoadStreamWithInvalidURL() { }
func testPlaybackStateDuringBuffering() { }
```

### Quick Checklist
- Test both success and failure paths
- Test edge cases (empty strings, nil values)
- Use meaningful assertions
- Avoid logic in test setup

---

## Xcode Conventions

### Build Phases
- Pre-build: Lint checks
- Post-build: Code analysis

### Schemes
- `steam` - Main app scheme

### Build Configurations
- Debug - Development, full logging
- Release - Production, optimized

---

## Common Mistakes to Avoid

❌ Constructing a ViewModel inside a View instead of getting it from `AppCoordinator`
❌ Mixing `ObservableObject`/`@Published` into an `@Observable` type
❌ Duplicate state (UI state + ViewModel state for same value)
❌ Heavy logic in Views (move to ViewModel)
❌ Hardcoded values (extract to constants or config)
❌ Ignoring threading (always assume background threads possible)
❌ Capturing `self` strongly in closures (use `[weak self]`)

---

## Quick Reference

| Item | Convention | Example |
|------|-----------|---------|
| Class/Struct | PascalCase | `PlaybackViewModel` |
| Variable | camelCase | `isLoading` |
| Constant | camelCase | `maxRetries = 2` |
| Function | camelCase (verb) | `loadStream()` |
| Indentation | 4 spaces | — |
| Line length | ≤120 chars | — |
| Access level | Explicit | `private`, `public` |
| Threading | Main only for UI | No background UI updates |