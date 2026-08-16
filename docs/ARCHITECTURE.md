Last Modified: 08/17/2026 (1786899911) by amonrit

# Steam - Video Streaming App Architecture

## Overview

iOS video streaming app using **Model-View-ViewModel (MVVM)** architecture with HLS playback, adaptive bitrate, fullscreen support, and debug metrics.

**Tech Stack:**
- **Language**: Swift
- **UI Framework**: SwiftUI
- **Architecture**: MVVM (Model-View-ViewModel)
- **Playback**: AVFoundation (AVPlayer)
- **Reactive**: Combine + KVO

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

**Architecture**: MVVM  
**Platform**: iOS (SwiftUI)  
**Last Updated**: August 2026
