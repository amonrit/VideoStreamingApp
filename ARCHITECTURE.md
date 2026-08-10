# 🎬 Steam - Video Streaming App Architecture

## Project Overview

**VideoStreamingApp** is an iOS app built with **SwiftUI** and **MVVM architecture** that streams HLS videos with playlist selection, fullscreen playback, and real-time debug metrics.

### Tech Stack
- **Language**: Swift
- **UI Framework**: SwiftUI
- **Architecture**: MVVM (Model-View-ViewModel)
- **Reactive**: Combine + KVO (Key-Value Observing)
- **Playback**: AVFoundation (AVPlayer, AVPlayerItem)
- **Threading**: GCD + Combine Publishers

---

## 1️⃣ Features & User Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                      User Interactions                              │
└─────────────────────────────────────────────────────────────────────┘

  User
   │
   ├─(Browse)──────→ Video List View
   │                  • Thumbnails (AsyncImage)
   │                  • Title & Status
   │                  • Current playing indicator
   │
   ├─(Tap video)───→ Player View
   │                  • HLS Adaptive Bitrate Playback
   │                  • Loading spinner
   │                  • Error overlay + Retry button
   │                  • Fullscreen button
   │
   └─(Fullscreen)──→ FullScreenPlayerView
                      • Full screen player only
                      • Hide status bar & UI
                      • Close button (X)
```

### Key Features

| Feature | Implementation |
|---------|-----------------|
| **HLS Streaming** | AVPlayer with HTTP Live Streaming (Apple dev CDN URLs) |
| **Adaptive Bitrate** | Automatic quality adjustment based on network conditions |
| **Playlist Selection** | User selects video → reordered list with selection at top |
| **Error Handling** | Error overlay with message + Retry button |
| **Buffering Detection** | Tracks stalls via `isPlaybackLikelyToKeepUp` + `AVPlayerItemPlaybackStalled` notification |
| **Debug Mode** | Toggle to show resolution, bitrate, buffering count |
| **Fullscreen Support** | Full screen cover with hide status bar |
| **Async Image Loading** | AsyncImage with fallback states (empty, success, failure) |

### Loading & Error States

```
Loading State:
  isLoading = true
  → Show: Spinner + "Loading..." text
  → Triggered by: status == .unknown, !isPlaybackLikelyToKeepUp, playback stalled

Error State:
  errorMessage = "Error message"
  → Show: Error overlay + Retry button
  → Triggered by: status == .failed, or playback error notification

Success State:
  status == .readyToPlay
  → isLoading = false, errorMessage = nil
  → Ready to play video
```

### Buffering Monitoring

Tracked via **three sources**:
1. **`isPlaybackLikelyToKeepUp`** (AVPlayerItem published property)
   - Emits `false` when network can't keep up with playback
   - Increments `bufferingCount` on each change

2. **`AVPlayerItemPlaybackStalled`** (Notification)
   - Fired when playback unexpectedly stops
   - Shows "Buffering..." message

3. **Manual Counter** 
   - `bufferingCount` property tracks total buffering events
   - Displayed in debug mode

---

## 2️⃣ MVVM Architecture

```
┌────────────────────────────────────────────────────────────────────────┐
│                         View Layer                                     │
├─────────────────────────────────────────────────────────────────────┐
│ • steamApp.swift                    Entry point (WindowGroup)        │
│ • ContentView.swift                 Main UI + List management         │
│ • VideoPlayerView.swift             Player component + Loading/Error  │
│ • FullScreenPlayerView.swift        Fullscreen wrapper               │
│ • SuggestedVideoRow                 List item component              │
└─────────────────────────────────────────────────────────────────────┘
                              │ observes
                              ↓
┌─────────────────────────────────────────────────────────────────────┐
│                    ViewModel Layer                                   │
├─────────────────────────────────────────────────────────────────────┐
│ VideoPlayerViewModel: ObservableObject                              │
│                                                                      │
│ @Published Properties:                                             │
│  • currentStream: VideoStream          → triggers load()            │
│  • isPlaying: Bool                     → play/pause state          │
│  • isLoading: Bool                     → show spinner              │
│  • errorMessage: String?               → show error overlay        │
│  • bufferingCount: Int                 → debug metric              │
│                                                                      │
│ Core Component:                                                     │
│  • player: AVPlayer                    → manages playback           │
│  • cancellables: Set<AnyCancellable>   → manage Combine subs       │
│                                                                      │
│ Methods:                                                            │
│  • load(stream:)                       → create & setup item       │
│  • play() / pause()                    → control playback          │
│  • retry()                             → reload current stream     │
│  • setupObservers(for:)                → KVO monitoring            │
│                                                                      │
│ Debug Helpers:                                                      │
│  • resolutionText: String              → "Resolution: 1920x1080"   │
│  • bitrateText: String                 → "Bitrate: 5000 kbps"      │
│  • bufferingText: String               → "Buffering events: 2"     │
└─────────────────────────────────────────────────────────────────────┘
                              │ loads & manages
                              ↓
┌─────────────────────────────────────────────────────────────────────┐
│                         Model Layer                                  │
├─────────────────────────────────────────────────────────────────────┤
│ VideoStream: Identifiable, Hashable                                 │
│                                                                      │
│ Properties:                                                         │
│  • id: UUID                            → Unique identifier          │
│  • title: String                       → Video title               │
│  • urlString: String                   → HLS stream URL            │
│  • thumbnailURLString: String          → Thumbnail image URL       │
│                                                                      │
│ Computed Properties:                                                │
│  • url: URL?                           → Parsed from urlString     │
│  • thumbnailURL: URL?                  → Parsed from thumbnailURL  │
│                                                                      │
│ Sample Data:                                                        │
│  • Apple Advanced HLS                  → master.m3u8               │
│  • Apple Basic HLS 4:3                 → 4x3 variant               │
│  • Apple 16:9 HLS                      → 16x9 variant              │
└─────────────────────────────────────────────────────────────────────┘
```

### Architecture Flow

```
ContentView
  │
  ├─ @StateObject viewModel: VideoPlayerViewModel
  ├─ @State streams: [VideoStream]
  ├─ @State isFullScreen: Bool
  └─ @State showDebug: Bool
       │
       ├─ VideoPlayerView
       │  └─ observes: viewModel (player, isLoading, errorMessage)
       │
       ├─ FullScreenPlayerView (if isFullScreen)
       │  └─ contains: VideoPlayerView
       │
       └─ SuggestedVideoRow (ForEach streams)
          └─ onTapGesture → select(stream:) → update viewModel.currentStream

When user taps video:
  1. ContentView.select(stream:) called
  2. viewModel.currentStream = stream (didSet trigger)
  3. ViewModel.load(stream:) called
  4. Create AVPlayerItem(url:)
  5. player.replaceCurrentItem(with:)
  6. setupObservers() for KVO monitoring
  7. Published properties updated
  8. SwiftUI detects changes → views re-render
  9. Player shows loading → ready → playing → or error state
```

---

## 3️⃣ Reactive Data Flow (Combine & KVO)

```
Trigger Event
     │
     ├─ User selects stream
     │
     ↓
currentStream Updated (@Published)
     │
     ├─ didSet: load(stream:) called
     │
     ↓
Create AVPlayerItem(url:)
     │
     ↓
player.replaceCurrentItem(with: item)
     │
     ↓
setupObservers(for: item)
     │
     └─ Subscribe to THREE monitoring streams:
        │
        ├─ Stream 1: AVPlayerItem.status
        │   │
        │   └─ Observes: item.publisher(for: \.status)
        │       │
        │       ├─ .readyToPlay
        │       │  └─ isLoading = false
        │       │  └─ errorMessage = nil
        │       │
        │       ├─ .failed
        │       │  └─ errorMessage = "Failed to load..."
        │       │
        │       └─ .unknown
        │          └─ isLoading = true
        │
        ├─ Stream 2: isPlaybackLikelyToKeepUp
        │   │
        │   └─ Observes: item.publisher(for: \.isPlaybackLikelyToKeepUp)
        │       │
        │       └─ When false (and player.rate > 0)
        │          ├─ isLoading = true (BUFFERING)
        │          └─ bufferingCount += 1
        │
        └─ Stream 3: Playback Stalled
            │
            └─ Observes: NotificationCenter (.AVPlayerItemPlaybackStalled)
                │
                └─ When stall detected
                   ├─ isLoading = true
                   ├─ errorMessage = "Buffering..."
                   └─ bufferingCount += 1

                   ↓
                   ↓
             @Published Properties Updated
                   │
                   ├─ isLoading
                   ├─ errorMessage
                   ├─ isPlaying
                   └─ bufferingCount
                   │
                   ↓
                   ↓
             SwiftUI Detects Changes
                   │
                   ↓
                   ↓
             Views Re-render
                   │
                   ├─ Show spinner (isLoading = true)
                   ├─ Show error overlay (errorMessage != nil)
                   ├─ Show debug info (bufferingCount)
                   └─ Show playing state (isPlaying = true)
```

### Publisher Subscriptions

```swift
// Each subscription stored in cancellables Set
cancellables.store(in: &cancellables)

// Auto-cleanup when ViewModel deallocated
deinit { cancellables.removeAll() }
```

---

## 4️⃣ File Structure

```
steam/
├── steam/
│   ├── steamApp.swift                    (App entry point)
│   ├── Models/
│   │   └── VideoStream.swift             (Data model + sample data)
│   ├── ViewModels/
│   │   └── VideoPlayerViewModel.swift    (Playback logic + state)
│   └── Views/
│       ├── ContentView.swift             (Main UI + list)
│       ├── VideoPlayerView.swift         (Player component)
│       └── FullScreenPlayerView.swift    (Fullscreen wrapper)
│
└── steam.xcodeproj/                      (Xcode project)
```

---

## 5️⃣ Key Implementation Details

### AVPlayer Setup
```swift
// In ViewModel.load()
let item = AVPlayerItem(url: url)
player.replaceCurrentItem(with: item)
setupObservers(for: item)
```

### Combine Publishers (KVO)
```swift
// Status monitoring
item.publisher(for: \.status)
    .sink { status in ... }
    .store(in: &cancellables)

// Playback keep-up monitoring
item.publisher(for: \.isPlaybackLikelyToKeepUp)
    .sink { keepUp in ... }
    .store(in: &cancellables)
```

### Notification Center Monitoring
```swift
// Playback stalled
NotificationCenter.default.publisher(for: .AVPlayerItemPlaybackStalled, object: item)
    .sink { _ in ... }
    .store(in: &cancellables)

// Failed to play
NotificationCenter.default.publisher(for: .AVPlayerItemFailedToPlayToEndTime, object: item)
    .sink { notification in ... }
    .store(in: &cancellables)
```

### SwiftUI Binding Flow
```swift
// In ContentView
@StateObject private var viewModel = VideoPlayerViewModel(stream: .sample)

// In body
VideoPlayerView(viewModel: viewModel, isFullScreen: $isFullScreen)
    // Observes: @ObservedObject var viewModel
    // Updates trigger on ViewModel's @Published changes
```

---

## 6️⃣ State Diagram

```
                    ┌─────────────────┐
                    │   Initial Load  │
                    └────────┬────────┘
                             │
                             ↓
                   ┌─────────────────────┐
                   │ Create AVPlayerItem │
                   │ Setup Observers     │
                   └────────┬────────────┘
                            │
                ┌───────────┴───────────┐
                │                       │
                ↓                       ↓
        ┌──────────────┐        ┌──────────────┐
        │   LOADING    │        │    ERROR     │
        │ isLoading    │        │ errorMessage │
        │  = true      │        │   != nil     │
        └──────┬───────┘        └────┬─────────┘
               │                     │
               ├─────────────────────┤
               │   (Retry pressed)   │
               └─────────────────────┘
                       │
        ┌──────────────┴──────────────┐
        │                             │
        ↓                             ↓
   ┌────────────┐           ┌──────────────────┐
   │ BUFFERING  │           │  READY TO PLAY   │
   │ (stalled)  │           │ status           │
   │ isLoading  │           │  = .readyToPlay  │
   │  = true    │           └────────┬─────────┘
   └─────┬──────┘                    │
         │                           ↓
         │                    ┌─────────────┐
         │                    │   PLAYING   │
         │                    │ isPlaying   │
         │                    │  = true     │
         │                    └──────┬──────┘
         │                           │
         │                    ┌──────────────┐
         │                    │   PAUSED     │
         │                    │ isPlaying    │
         │                    │  = false     │
         │                    └──────┬───────┘
         │                           │
         └───────────────────────────┘
                    │
                    ↓
            (Network issue)
                    │
                    ↓
            ┌──────────────┐
            │   STALLED    │
            │ bufferingCount+
            └──────────────┘
```

---

## 7️⃣ Debug Mode Features

Press **"Debug"** button in ContentView to toggle debug panel:

```
┌─────────────────────────────────┐
│ Resolution: 1920x1080          │  ← Current video resolution
│ Bitrate: 5000 kbps             │  ← Current streaming bitrate
│ Buffering events: 2            │  ← Count of buffering stalls
└─────────────────────────────────┘
```

**Implementation:**
```swift
var resolutionText: String {
    let size = player.currentItem?.presentationSize
    return "Resolution: \(Int(size.width))x\(Int(size.height))"
}

var bitrateText: String {
    let event = player.currentItem?.accessLog()?.events.last
    let kbps = event.observedBitrate / 1000.0
    return String(format: "Bitrate: %.0f kbps", kbps)
}

var bufferingText: String {
    "Buffering events: \(bufferingCount)"
}
```

---

## Summary

| Layer | Component | Responsibility |
|-------|-----------|-----------------|
| **View** | ContentView, VideoPlayerView, FullScreenPlayerView | Render UI based on ViewModel state |
| **ViewModel** | VideoPlayerViewModel | Manage playback, handle errors, monitor buffering |
| **Model** | VideoStream | Store video metadata (title, URLs) |
| **Framework** | Combine + KVO | React to player state changes |
| **Playback** | AVFoundation (AVPlayer) | Handle HLS streaming and decoding |

---

**Created**: 2024  
**Architecture**: MVVM with Reactive Streams (Combine + KVO)  
**Platform**: iOS (SwiftUI)  
**Type**: Video Streaming Application
