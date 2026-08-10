Last Modified: 08/10/2026 (1786502400) by amonrit

# Steam - Video Streaming App Architecture

## Overview

iOS video streaming app using **Model-View-ViewModel (MVVM)** architecture with HLS playback, adaptive bitrate, fullscreen support, and debug metrics.

### Tech Stack
- **Language**: Swift
- **UI Framework**: SwiftUI
- **Architecture**: MVVM (Model-View-ViewModel)
- **Playback**: AVFoundation (AVPlayer)
- **Reactive**: Combine + KVO
- **Threading**: GCD
- **Logging**: os.Logger

---

## MVVM Architecture

### 1. Model

**PlaybackState** (Entity)
```swift
struct PlaybackState {
    var isLoading: Bool = false
    var isPlaying: Bool = false
    var errorMessage: String?
    var bufferingCount: Int = 0
    var currentStream: VideoStream?
}
```

**VideoStream** (Entity)
```swift
struct VideoStream: Identifiable, Hashable {
    let id: UUID
    let title: String
    let urlString: String
    let thumbnailURLString: String
    
    var url: URL? { URL(string: urlString) }
    var thumbnailURL: URL? { URL(string: thumbnailURLString) }
}
```

---

### 2. ViewModel

**PlaybackViewModel** - All business logic, state management, and observer setup
```swift
class PlaybackViewModel: ObservableObject {
    // MARK: - Published State
    @Published var isLoading: Bool = false
    @Published var isPlaying: Bool = false
    @Published var errorMessage: String?
    @Published var bufferingCount: Int = 0
    @Published var currentStream: VideoStream?
    
    let player: AVPlayer
    private let worker: VideoPlayerWorker
    private var playbackState: PlaybackState = .idle
    
    // MARK: - Public Interface
    func loadStream(_ stream: VideoStream)
    func play()
    func pause()
    func retry()
    
    // MARK: - Debug Info
    var resolutionText: String
    var bitrateText: String
}
```

**Responsibilities:**
- Load and manage playback lifecycle
- Setup KVO observers for player status, buffering, errors
- Update internal `playbackState` and publish to `@Published` properties
- Format debug info (resolution, bitrate)
- Handle stream errors and retry logic

---

### 3. View

**VideoPlayerView** - Renders video player UI
```swift
struct VideoPlayerView: View {
    @ObservedObject var viewModel: PlaybackViewModel
    @Binding var isFullScreen: Bool
    
    var body: some View {
        // VideoPlayer + Loading/Error overlays + Fullscreen button
        // Calls viewModel.retry() on error
    }
}
```

**FullScreenPlayerView** - Fullscreen player wrapper
```swift
struct FullScreenPlayerView: View {
    @ObservedObject var viewModel: PlaybackViewModel
    @Binding var isPresented: Bool
}
```

**ContentView** - Main app container
```swift
struct ContentView: View {
    @StateObject private var playbackViewModel = PlaybackViewModel()
    @State private var showDebug = false  // UI state only
    
    // Shows video list, current selection, debug panel
    // Calls viewModel.loadStream() on stream selection
}
```

**Responsibilities:**
- Pure presentation logic
- SwiftUI bindings to ViewModel state
- User gesture handling (passes to ViewModel)
- UI state management (e.g., `showDebug` panel toggle)

---

### 4. Worker

**VideoPlayerWorker** - Reusable KVO observer setup
```swift
class VideoPlayerWorker {
    func setupKVOObservers(
        for item: AVPlayerItem,
        player: AVPlayer,
        onStatusChange: @escaping (AVPlayerItem.Status) -> Void,
        onBufferingChange: @escaping (Bool) -> Void,
        onStall: @escaping () -> Void,
        onFailedToPlayToEnd: @escaping (Error?) -> Void
    )
    
    func getResolution(from player: AVPlayer) -> String
    func getBitrate(from player: AVPlayer) -> String
}
```

**Responsibilities:**
- Setup Combine publishers for KVO changes
- All publishers deliver callbacks on main thread (`.receive(on: DispatchQueue.main)`)
- Extract debug info (resolution, bitrate)

---

## Data Flow

### 1️⃣ User Selects Video

```
┌─────────────────┐
│   ContentView   │
│  (View Layer)   │
└────────┬────────┘
         │
         │ onTapGesture
         ↓
playbackViewModel.loadStream(stream)
         ↓
┌──────────────────────────┐
│  PlaybackViewModel       │
│  (ViewModel Layer)       │
└────────┬─────────────────┘
         │
         ├─ 1. player.pause()
         ├─ 2. cancellables.removeAll()
         ├─ 3. Validate URL
         ├─ 4. Create AVPlayerItem
         ├─ 5. player.replaceCurrentItem(with: item)
         ├─ 6. setupObservers()
         └─ 7. Update @Published properties (isLoading, currentStream)
         
         ↓
┌──────────────────────────┐
│   VideoPlayerWorker      │
│  (Utility Layer)         │
└────────┬─────────────────┘
         │
         ├─ Monitor status changes
         ├─ Monitor buffering state
         ├─ Monitor stalls
         ├─ Monitor failed-to-play errors
         └─ Deliver callbacks on main thread
         
         ↓
         
Callbacks trigger ViewModel handlers:
- handleStatusChange()
- handleBuffering()
- handlePlaybackStall()
- handleFailedToPlayToEnd()

         ↓
@Published properties update
         
         ↓
┌──────────────────────────┐
│   SwiftUI Views          │
│  (View Layer)            │
└──────────────────────────┘
Re-render based on state changes
```

### 2️⃣ Player Status Changes (Streaming)

```
AVPlayerItem.status changes
         │
         ↓
VideoPlayerWorker observes via KVO
         │
         ↓
Calls onStatusChange() callback
         │
         ↓
PlaybackViewModel.handleStatusChange()
         │
         ├─ Updates playbackState
         └─ Calls updatePlaybackViewModel() → publishes @Published properties
         │
         ↓
SwiftUI views re-render based on:
- isLoading, isPlaying, errorMessage, bufferingCount
```

### 3️⃣ Buffering & Network Issues

```
AVPlayerItem.isPlaybackLikelyToKeepUp changes
         │
         ↓
VideoPlayerWorker.onBufferingChange()
         │
         ↓
PlaybackViewModel.handleBuffering()
         │
         ├─ Sets isLoading = true
         ├─ Increments bufferingCount
         └─ Publishes updates
         │
         ↓
View shows loading spinner + debug panel updates count
```

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
│   │   ├── ContentView.swift
│   │   ├── VideoPlayerView.swift
│   │   └── FullScreenPlayerView.swift
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
| **ContentView** | View | List, selection, debug panel |
| **VideoPlayerWorker** | Utility | KVO setup, formatting |
| **PlaybackState** | Model | Data entity |
| **VideoStream** | Model | Data entity |

---

## State Management

### PlaybackViewModel Internal State
- `playbackState: PlaybackState` — internal tracking of stream + playback status
- `@Published` properties — synced to UI via Combine
- `cancellables: Set<AnyCancellable>` — KVO subscription management

### ContentView Local State
- `@StateObject playbackViewModel` — preserved across re-renders (fixes D2: AVPlayer leak)
- `@State showDebug` — pure UI state, not synced to ViewModel

### Data Flow
1. User action → ViewModel method called
2. ViewModel updates `playbackState` internally
3. `updatePlaybackViewModel()` copies to `@Published` properties on main thread
4. SwiftUI observes `@Published` → re-renders

---

## Key Fixes & Improvements

### D1: Duplicate Error Subscription
- Removed duplicate `.AVPlayerItemFailedToPlayToEndTime` from Interactor
- Worker now handles all error monitoring (single source)

### D2: AVPlayer Memory Leak
- Replaced `@ObservedObject` with custom `init()` → `@StateObject` 
- `@StateObject` preserves instance across ContentView re-renders

### D3: Dead Debug Plumbing
- Replaced unreachable `updateDebugInfo()` method
- Added computed `resolutionText`, `bitrateText` properties
- Live updates via `.onAppear()` and ViewModel state changes

### D6: Dead Formatting Methods
- Removed unused `formatResolution()` and `formatBitrate()`
- Kept live `getResolution()` and `getBitrate()`

### Threading (Decision B)
- Worker attaches `.receive(on: DispatchQueue.main)` to all publishers
- All callbacks guaranteed to fire on main thread
- Eliminated scattered `DispatchQueue.main.async` blocks

---

## Request/Response Pattern → MVVM

**Old Clean Swift (VIPER):**
```
View → ViewController → Interactor → Presenter → ViewController → View
   (Router injection)  (Request/Response structs, Presenter protocol)
```

**New MVVM:**
```
View → ViewModel ⟷ Worker
   (@ObservedObject)  (KVO setup)
   
ViewModel is the single source of truth:
- Owns business logic
- Manages state
- Owns observers
- No DTOs or routing protocols needed
```

---

## Logging

Uses `os.Logger` for structured logging:
- Subsystem: `amonrit.steam`
- Category: `playback`
- Levels: `.info`, `.error`, `.debug`
- Viewable in Xcode Console or Console.app

Example:
```
logger.info("📥 Loading stream: MyStream")
logger.error("❌ Invalid URL")
logger.debug("   URL: https://...")
```

---

## Key Benefits of MVVM

✅ **Simplicity** — Single ViewModel owns all logic (vs. I-P-C split)  
✅ **Testability** — ViewModel can be tested independently  
✅ **State Management** — Combine `@Published` is SwiftUI-native  
✅ **No Routing Complexity** — No protocols, DTOs, or dependency injection boilerplate  
✅ **Direct Data Binding** — Views directly observe ViewModel (vs. manual copy)  
✅ **Less Code** — Removed 400+ lines of VIPER scaffolding  
✅ **Memory Safety** — `@StateObject` prevents AVPlayer leaks on re-render  

---

**Architecture**: MVVM  
**Platform**: iOS (SwiftUI)  
**Last Updated**: August 2026  
**Status**: Migrated from Clean Swift (VIP) on 2026-08-10

---
**Last Updated:** 2026-08-10 (1786357473) by amonrit
