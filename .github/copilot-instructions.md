Last Modified: 08/17/2026 (1786899911) by amonrit

# GitHub Copilot Instructions - Steam iOS Streaming App

This file provides guidance to GitHub Copilot when working on this repository.

## Project Overview

**Steam** is an iOS video streaming application with two main components:

1. **iOS App** - SwiftUI-based HLS player using MVVM architecture
2. **Streaming Server** - Docker-based MediaMTX for multi-protocol streaming

## Code Style & Conventions

### Swift
- **Indentation**: 4 spaces (no tabs)
- **Line Length**: Max 120 characters
- **Naming**: camelCase for variables/functions, PascalCase for types
- **Architecture**: MVVM - Views observe ViewModels, ViewModels own business logic
- **Threading**: All UI updates on main thread guaranteed

### File Organization
```
steam/
├── steamApp.swift           (Entry point)
├── Models/                  (Data entities)
├── ViewModels/              (Business logic)
├── Views/                   (SwiftUI UI)
└── Workers/                 (Reusable utilities)
```

### Documentation
- Use `// MARK: - Section Name` to organize code sections
- Comment WHY, not WHAT
- Prefer clear code over clever code
- Use structured logging: `logger.info()`, `logger.error()`

## Architecture Guidelines

### MVVM Pattern
- **Views**: Observe @Published properties, call ViewModel methods on user action
- **ViewModel**: Owns AVPlayer, manages state, coordinates Workers
- **Worker**: Reusable utilities (KVO setup, format extraction), no UI code
- **Models**: Data entities (VideoStream, PlaybackState)

### Important Rules
- ✅ Use @StateObject for objects created in Views (preserves instance)
- ❌ Never use @ObservedObject for objects you create (causes memory leaks)
- ✅ All Combine publishers deliver on main thread
- ✅ Use [weak self] in closures to avoid retain cycles
- ❌ Never put business logic in Views

## Streaming Server

### Docker & Deployment
- **Container**: MediaMTX v1.20.0 in Docker
- **Config**: `streaming/mediamtx.yml` and `streaming/docker-compose.yml`
- **Paths**: Use relative paths (portable across machines)
- **Deployment**: Copy folder + `docker-compose up -d` = ready to stream

### Protocols
| Protocol | Port | Use Case |
|----------|------|----------|
| RTMP | 1935 | Publishing (OBS, FFmpeg) |
| RTSP | 8554 | Low-latency playback |
| HLS | 8888 | iOS/Web playback |
| WebRTC | 8889 | Ultra-low-latency browser |
| SRT | 8890 | Secure backup link |

## Common Development Tasks

### Adding a Feature
1. Add `@Published` property to ViewModel if new state needed
2. Add method to ViewModel for user action
3. Create Worker helper if complex logic needed
4. Create/update SwiftUI View to call ViewModel
5. Write tests (XCTest)

### Debugging
- **iOS**: Search Xcode Console for `[playback]` category
- **Server**: `./streaming.sh logs` to watch output
- **Network**: Use `curl` to test HLS endpoint
- **Logs**: Structured logging via `os.Logger`

### Deployment
- Copy `steam/` folder to new machine
- Run `cd steam/streaming && docker-compose up -d`
- Get IP: `ifconfig | grep "inet "`
- Test: `curl http://IP:8888/live/mystream/index.m3u8`

## Code Quality Standards

### Logging
```swift
import os
private let logger = Logger(subsystem: "amonrit.steam", category: "playback")

logger.info("✅ Stream loaded")
logger.error("❌ Failed to load: \(error)")
logger.debug("   Debug info here")
```

### Error Handling
- Always provide user-facing error messages
- Log errors with context
- Use descriptive error names
- Suggest recovery actions when possible

### Testing
- Write XCTest for ViewModels and Workers
- Test success and failure paths
- Mock dependencies (AVPlayer, network)
- Avoid logic in Views (harder to test)

## Xcode & Build Setup

### Schemes
- `steam` - Main iOS app scheme

### Build Phases
- Pre-build: Optional linting
- Post-build: Optional analysis

### Device Testing
- iOS 15+ supported
- Test on simulator and real device
- AirPlay/external playback supported

## Performance Considerations

### Memory
- AVPlayer can be heavy (use @StateObject)
- Don't create multiple AVPlayer instances
- Clean up Combine subscriptions with cancellables

### Network
- HLS: ~5-10s latency (buffered playback)
- RTSP: <1s latency (real-time)
- Retry logic: 3s load timeout, 2s stall timeout

### CPU
- SwiftUI rendering optimized for Views
- Worker utilities run efficiently
- Logging is structured (low overhead)

## Git & Version Control

### Commit Messages
Use conventional commits:
```
feat: add playback controls
fix: resolve memory leak in ViewModel
docs: update docs/DEPLOYMENT.md
chore: update dependencies
refactor: simplify VideoPlayerWorker
test: add tests for retry logic
```

### Branch Strategy
- Work on feature branches
- Create PR with detailed description
- Merge to main when reviewed

## Key Files Reference

| File | Purpose |
|------|---------|
| `README.md` | Project overview & quick start |
| `CLAUDE.md` | AI assistant guide |
| `docs/ARCHITECTURE.md` | Deep dive into MVVM |
| `docs/DEPLOYMENT.md` | Server deployment |
| `DOCUMENTATION.md` | Master index for all docs |

## Common Mistakes to Avoid

### Memory Leaks
```swift
// ❌ WRONG
setupObservers {
    self.handleChange()  // Strong capture
}

// ✅ CORRECT
setupObservers { [weak self] in
    self?.handleChange()  // Weak capture
}
```

### State Duplication
```swift
// ❌ WRONG - Duplicate state
class MyView: View {
    @State var isLoading = false
    @ObservedObject var viewModel = ViewModel()  // Also has isLoading
}

// ✅ CORRECT - Single source of truth
class MyView: View {
    @StateObject var viewModel = ViewModel()  // One @Published var isLoading
}
```

### Business Logic in Views
```swift
// ❌ WRONG
struct VideoPlayerView: View {
    var body: some View {
        // Business logic here - WRONG
        if userDidTap {
            viewModel.loadStream(stream)  // Should be method call
        }
    }
}

// ✅ CORRECT
struct VideoPlayerView: View {
    var body: some View {
        Button("Load") {
            viewModel.loadStream(stream)  // Just call method
        }
    }
}
```

## When Asking Copilot

✅ "Generate tests for PlaybackViewModel"
✅ "Optimize this SwiftUI View performance"
✅ "What's the best way to handle X in MVVM?"
✅ "Help debug this streaming issue"

❌ "Generate boilerplate code" (MVVM doesn't need much)
❌ "Add more features without design" (design first)
❌ "Ignore architecture guidelines" (consistency matters)

## Testing Framework

- **XCTest** - Built-in iOS testing framework
- **@MainActor** - For testing main thread code
- **Mocking** - Use protocol-based design for mockable dependencies

## Useful Links

- [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- [The Combine Framework](https://developer.apple.com/documentation/combine)
- [SwiftUI Tutorials](https://developer.apple.com/tutorials/swiftui)
- [AVFoundation Framework](https://developer.apple.com/documentation/avfoundation)

---

**Last Updated**: August 2026  
**Copilot Version**: Latest  
**Project Stage**: Active Development
