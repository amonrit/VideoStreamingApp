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
class/struct/enum MyType {
    
    // MARK: - Properties
    @Published var state: String
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
    @ObservedObject var viewModel: MyViewModel
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

### ObservedObject vs StateObject
- Use `@StateObject` for objects you create (preserves instance)
- Use `@ObservedObject` for objects passed in
- Example: `@StateObject private var viewModel = PlaybackViewModel()`

### State Management
- Keep UI-only state in View (`@State`)
- Business logic & persistence in ViewModel (`@Published`)
- Don't duplicate state

---

## MVVM Architecture

### ViewModel Responsibilities
```swift
class PlaybackViewModel: ObservableObject {
    // 1. Published properties (UI state)
    @Published var isLoading: Bool = false
    @Published var currentStream: VideoStream?
    
    // 2. Own important objects (AVPlayer, networking)
    let player: AVPlayer
    private let worker: VideoPlayerWorker
    
    // 3. Business logic methods
    func loadStream(_ stream: VideoStream) { }
    func play() { }
    func pause() { }
    
    // 4. Internal state management
    private var playbackState: PlaybackState = .idle
    private var cancellables = Set<AnyCancellable>()
}
```

### Worker Responsibilities
```swift
class VideoPlayerWorker {
    // 1. Reusable utilities
    func setupKVOObservers(...) { }
    
    // 2. Format extraction
    func getResolution(from player: AVPlayer) -> String { }
    
    // 3. Return results via callbacks/Combine
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

## Combine & Reactive Programming

### Publisher Setup
```swift
private var cancellables = Set<AnyCancellable>()

private func setupObservers() {
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
- Workers deliver all callbacks on main thread
- No need for `DispatchQueue.main.async` in Views
- If needed in ViewModel: use `.receive(on: DispatchQueue.main)`

---

## Memory Management

### Weak Self
```swift
setupObservers(
    onStatusChange: { [weak self] status in
        self?.handleStatusChange(status)
    }
)
```

### StateObject Preservation
```swift
// ✅ CORRECT - @StateObject preserves across re-renders
@StateObject private var viewModel = PlaybackViewModel()

// ❌ WRONG - ObservedObject leaks AVPlayer on re-render
@ObservedObject var viewModel = PlaybackViewModel()
```

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

❌ Using `@ObservedObject` for objects you create (causes leaks)
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
