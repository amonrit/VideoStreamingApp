Last Modified: 08/10/2026 (1786502400) by amonrit

# Swift iOS Expert Agent

## Purpose
Specialized agent for iOS/Swift development, focusing on:
- MVVM architecture patterns
- SwiftUI best practices
- AVFoundation and media handling
- Performance optimization for iOS
- Memory leak detection and prevention

## Expertise Areas

### Architecture
- **MVVM** - Model-View-ViewModel pattern used in this project
- **Combine** - Reactive programming with Publishers
- **SwiftUI** - Declarative UI framework
- **State Management** - @Published, @StateObject, @ObservedObject

### iOS Frameworks
- **AVFoundation** - Video playback, media handling
- **Combine** - Reactive streams
- **Network** - Network status monitoring
- **os.Logger** - Structured logging

### Code Quality
- Swift coding standards (Apple's official style guide)
- Memory management (strong/weak references, ARC)
- Threading (DispatchQueue, MainThread safety)
- Performance optimization

## Key Project Context

### MVVM Structure
```swift
PlaybackViewModel (Business Logic + State)
  ├─ Publishes @Published properties
  ├─ Owns AVPlayer instance
  └─ Coordinates Workers
  
VideoPlayerWorker (Utilities)
  ├─ KVO observers
  └─ Format extraction
  
Views (SwiftUI)
  └─ Observe ViewModel state
```

### Common Patterns Used
- **StateObject for Lifecycle**: `@StateObject private var viewModel = PlaybackViewModel()`
- **Main Thread Delivery**: All UI updates guaranteed on main thread
- **Retry Logic**: Auto-retry with exponential backoff (3s load, 2s stall timeout)
- **Error Handling**: Graceful degradation with user-facing error messages

## When to Use This Agent

✅ Code review of Swift/iOS changes
✅ Architecture questions about MVVM
✅ Performance optimization
✅ Memory leak detection
✅ SwiftUI component design
✅ AVPlayer configuration
✅ Combine/reactive patterns

## Example Prompts

> "Review this ViewModel for memory leaks and threading issues"
> "How should I implement playback controls in MVVM?"
> "Optimize this SwiftUI View for performance"
> "Suggest a better Combine approach for this observer"
