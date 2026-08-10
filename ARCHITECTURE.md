# Steam - Video Streaming App Architecture

## Overview

iOS video streaming app using **Clean Swift (VIP)** architecture pattern with HLS playback, adaptive bitrate, fullscreen support, and debug metrics.

### Tech Stack
- **Language**: Swift
- **UI Framework**: SwiftUI
- **Architecture**: Clean Swift (VIP)
- **Playback**: AVFoundation (AVPlayer)
- **Reactive**: Combine + KVO
- **Threading**: GCD

---

## Clean Swift Components

### 1. Models

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

---

### 2. View Controller

**VideoPlayerViewController** - Holds state & routes user actions
- ObservableObject for SwiftUI binding
- @Published properties for reactive updates
- Strong references to components (Interactor, Presenter, Worker)
- Routes user actions to Interactor

```swift
class VideoPlayerViewController: ObservableObject, VideoPlayerPresenterOutput {
    @Published var playbackViewModel: PlaybackViewModel
    @Published var debugViewModel: DebugInfoViewModel
    
    // Strong references (keep components alive)
    private let interactor: VideoPlayerInteractorInput
    private let presenter: VideoPlayerPresenterInput
    private let worker: VideoPlayerWorker
    
    func didSelectStream(_ stream: VideoStream)
    func playStream()
    func pauseStream()
    func retryLoadStream()
    
    // Receive formatted data from Presenter
    func displayPlaybackState(_ viewModel: PlaybackViewModel)
    func displayDebugInfo(_ info: DebugInfoViewModel)
}
```

---

### 3. Interactor

**VideoPlayerInteractor** - Business logic & data fetching
- Load video streams
- Manage playback lifecycle
- Setup observers (KVO, Notifications)
- Handle buffering/error monitoring

```swift
protocol VideoPlayerInteractorInput {
    func loadStream(_ stream: VideoStream)
    func play()
    func pause()
    func retry()
    func setupObservers(for item: AVPlayerItem)
}

class VideoPlayerInteractor: VideoPlayerInteractorInput {
    var presenter: VideoPlayerPresenterInput?
    var worker: VideoPlayerWorker?
    var player: AVPlayer
    var cancellables = Set<AnyCancellable>()
    
    func loadStream(_ stream: VideoStream) {
        // Load & setup playback
    }
    
    func play() { player.play() }
    func pause() { player.pause() }
    
    func retry() {
        // Reload current stream
    }
    
    func setupObservers(for item: AVPlayerItem) {
        // Monitor status, buffering, errors
    }
}
```

---

### 4. Presenter

**VideoPlayerPresenter** - Format data for display
- Format resolution/bitrate text
- Transform state for View
- No UI framework dependencies

```swift
protocol VideoPlayerPresenterInput {
    func presentLoading(_ isLoading: Bool)
    func presentPlaybackState(_ state: PlaybackState)
    func presentError(_ message: String)
    func presentDebugInfo(resolution: String, bitrate: String, buffering: Int)
}

protocol VideoPlayerPresenterOutput: AnyObject {
    func displayLoading(_ isLoading: Bool)
    func displayPlaybackState(_ viewModel: PlaybackViewModel)
    func displayError(_ message: String)
    func displayDebugInfo(_ info: DebugInfoViewModel)
}

class VideoPlayerPresenter: VideoPlayerPresenterInput {
    weak var viewController: VideoPlayerPresenterOutput?
    
    func presentLoading(_ isLoading: Bool) {
        viewController?.displayLoading(isLoading)
    }
    
    func presentPlaybackState(_ state: PlaybackState) {
        let viewModel = PlaybackViewModel(
            isPlaying: state.isPlaying,
            isLoading: state.isLoading
        )
        viewController?.displayPlaybackState(viewModel)
    }
    
    func presentDebugInfo(resolution: String, bitrate: String, buffering: Int) {
        let info = DebugInfoViewModel(
            resolution: resolution,
            bitrate: bitrate,
            bufferingCount: buffering
        )
        viewController?.displayDebugInfo(info)
    }
}
```

---

### 5. Worker

**VideoPlayerWorker** - Reusable utilities
- KVO setup & monitoring
- Notification handling
- Data parsing & formatting

```swift
class VideoPlayerWorker {
    func setupKVOObservers(
        for item: AVPlayerItem,
        onStatusChange: @escaping (AVPlayerItem.Status) -> Void,
        onBufferingChange: @escaping (Bool) -> Void,
        onStall: @escaping () -> Void
    ) {
        // Setup status publisher
        item.publisher(for: \.status)
            .sink { status in onStatusChange(status) }
            .store(in: &cancellables)
        
        // Setup buffering publisher
        item.publisher(for: \.isPlaybackLikelyToKeepUp)
            .sink { keepUp in onBufferingChange(!keepUp) }
            .store(in: &cancellables)
        
        // Setup stall notifications
        NotificationCenter.default.publisher(
            for: .AVPlayerItemPlaybackStalled,
            object: item
        ).sink { _ in onStall() }
            .store(in: &cancellables)
    }
    
    func formatResolution(_ size: CGSize) -> String {
        "Resolution: \(Int(size.width))x\(Int(size.height))"
    }
    
    func formatBitrate(_ kbps: Double) -> String {
        String(format: "Bitrate: %.0f kbps", kbps)
    }
}
```

---

### 6. View

**VideoPlayerView** - Pure SwiftUI, receives ViewModels
- Display playback state
- Show loading/error UI
- Render debug info
- No business logic

```swift
struct VideoPlayerView: View {
    @ObservedObject var viewModel: PlaybackViewModel
    
    var body: some View {
        ZStack {
            // Player
            VideoPlayer(player: viewModel.player)
                .ignoresSafeArea()
            
            // Loading overlay
            if viewModel.isLoading {
                LoadingOverlay()
            }
            
            // Error overlay
            if let error = viewModel.errorMessage {
                ErrorOverlay(message: error, onRetry: viewModel.onRetry)
            }
            
            // Debug panel
            if viewModel.showDebug {
                DebugPanel(info: viewModel.debugInfo)
            }
        }
    }
}
```

---

## Detailed Data Flow

### 1️⃣ User Selects Video (Tap on Video List)

```
┌─────────────────────────────────────────────────────────────────┐
│                         VIEW (SwiftUI)                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  @State var streams: [VideoStream]                            │
│  @ObservedObject var viewModel: PlaybackViewModel             │
│                                                                 │
│  VideoPlayerView(viewModel: viewModel)                         │
│  SuggestedVideoRow(stream: stream)                             │
│    .onTapGesture {                                             │
│      viewController.didSelectStream(stream)  ◄─── USER TAP     │
│    }                                                            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                          │
                          │ Calls
                          ↓
┌─────────────────────────────────────────────────────────────────┐
│              VIEW CONTROLLER (Router/ViewController)            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  func didSelectStream(_ stream: VideoStream) {                 │
│    interactor?.loadStream(stream)                              │
│  }                                                              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                          │
                          │ Calls
                          ↓
┌─────────────────────────────────────────────────────────────────┐
│                    INTERACTOR                                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  func loadStream(_ stream: VideoStream) {                      │
│    // 1. Reset state                                           │
│    updatePlaybackState(isLoading: true)                        │
│                                                                 │
│    // 2. Validate URL                                          │
│    guard let url = stream.url else {                           │
│      presentError("Invalid URL")                               │
│      return                                                     │
│    }                                                            │
│                                                                 │
│    // 3. Create AVPlayerItem                                   │
│    let item = AVPlayerItem(url: url)                           │
│    player.replaceCurrentItem(with: item)                       │
│                                                                 │
│    // 4. Setup Observers via Worker                            │
│    worker?.setupKVOObservers(for: item,                        │
│      onStatusChange: { [weak self] status in                   │
│        self?.handleStatusChange(status)                        │
│      },                                                         │
│      onBufferingChange: { [weak self] isBuffering in           │
│        self?.handleBuffering(isBuffering)                      │
│      },                                                         │
│      onStall: { [weak self] in                                 │
│        self?.handlePlaybackStall()                             │
│      }                                                          │
│    )                                                            │
│  }                                                              │
│                                                                 │
│  private var playbackState: PlaybackState = PlaybackState()    │
│  private func updatePlaybackState(_ state: PlaybackState) {    │
│    self.playbackState = state                                  │
│    presenter?.presentPlaybackState(state)                      │
│  }                                                              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

### 2️⃣ Interactor Setup Observers (Worker)

```
┌─────────────────────────────────────────────────────────────────┐
│                      WORKER                                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  func setupKVOObservers(for item: AVPlayerItem, ...) {        │
│                                                                 │
│    // Monitor AVPlayerItem Status Changes                       │
│    item.publisher(for: \.status)                              │
│      .sink { [weak self] status in                             │
│        switch status {                                         │
│          case .readyToPlay:                                    │
│            onStatusChange(.readyToPlay)                        │
│            // ✓ Ready to play                                  │
│                                                                 │
│          case .failed:                                         │
│            onStatusChange(.failed)                             │
│            // ✗ Failed to load                                 │
│                                                                 │
│          case .unknown:                                        │
│            onStatusChange(.unknown)                            │
│            // ⏳ Still loading                                 │
│        }                                                        │
│      }                                                          │
│      .store(in: &cancellables)                                 │
│                                                                 │
│    // Monitor Playback Keep-Up (Buffering)                     │
│    item.publisher(for: \.isPlaybackLikelyToKeepUp)            │
│      .sink { [weak self] keepUp in                             │
│        if !keepUp {                                            │
│          onBufferingChange(true)    // ⏳ Buffering            │
│        } else {                                                │
│          onBufferingChange(false)   // ✓ Ready                │
│        }                                                        │
│      }                                                          │
│      .store(in: &cancellables)                                 │
│                                                                 │
│    // Monitor Playback Stalled (Network Issue)                 │
│    NotificationCenter.default.publisher(                       │
│      for: .AVPlayerItemPlaybackStalled,                        │
│      object: item                                              │
│    ).sink { _ in                                               │
│      onStall()    // ⚠️ Playback interrupted                   │
│    }                                                            │
│    .store(in: &cancellables)                                   │
│  }                                                              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                          │
                          │ Callback: onStatusChange
                          │ Callback: onBufferingChange
                          │ Callback: onStall
                          ↓
┌─────────────────────────────────────────────────────────────────┐
│                    INTERACTOR (Continued)                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  private func handleStatusChange(_ status: AVPlayerItem.Status) {│
│    var state = playbackState                                  │
│                                                                 │
│    switch status {                                             │
│      case .readyToPlay:                                        │
│        state.isLoading = false                                │
│        state.errorMessage = nil                               │
│        // Get resolution & bitrate from player                 │
│        if let size = player.currentItem?.presentationSize {  │
│          state.resolution = worker?.formatResolution(size)    │
│                              ?? ""                             │
│        }                                                        │
│                                                                 │
│      case .failed:                                             │
│        state.isLoading = false                                │
│        state.errorMessage = "Failed to load video"            │
│                                                                 │
│      case .unknown:                                            │
│        state.isLoading = true                                 │
│        state.errorMessage = nil                               │
│    }                                                            │
│                                                                 │
│    updatePlaybackState(state)                                 │
│  }                                                              │
│                                                                 │
│  private func handleBuffering(_ isBuffering: Bool) {           │
│    var state = playbackState                                  │
│    state.isLoading = isBuffering                              │
│    if isBuffering {                                            │
│      state.bufferingCount += 1                                │
│    }                                                            │
│    updatePlaybackState(state)                                 │
│  }                                                              │
│                                                                 │
│  private func handlePlaybackStall() {                          │
│    var state = playbackState                                  │
│    state.isLoading = true                                     │
│    state.errorMessage = "Buffering..."                        │
│    state.bufferingCount += 1                                  │
│    updatePlaybackState(state)                                 │
│  }                                                              │
│                                                                 │
│  private func presentError(_ message: String) {                │
│    var state = playbackState                                  │
│    state.isLoading = false                                    │
│    state.errorMessage = message                               │
│    updatePlaybackState(state)                                 │
│  }                                                              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

### 3️⃣ Interactor → Presenter (Format Data)

```
┌─────────────────────────────────────────────────────────────────┐
│                    INTERACTOR                                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  private func updatePlaybackState(_ state: PlaybackState) {    │
│    self.playbackState = state                                  │
│    presenter?.presentPlaybackState(state)  ◄────┐             │
│  }                                                │             │
│                                                  │             │
└─────────────────────────────────────────────────────────────────┘
                                                   │
                                        Passes PlaybackState
                                                   │
                                                   ↓
┌─────────────────────────────────────────────────────────────────┐
│                    PRESENTER                                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  func presentPlaybackState(_ state: PlaybackState) {           │
│                                                                 │
│    // Transform raw state into ViewModel                        │
│    let viewModel = PlaybackViewModel(                           │
│      isLoading: state.isLoading,                               │
│      isPlaying: state.isPlaying,                               │
│      errorMessage: state.errorMessage,                         │
│      resolution: state.resolution,                             │
│      bitrate: state.bitrate,                                   │
│      bufferingCount: state.bufferingCount                      │
│    )                                                            │
│                                                                 │
│    // Pass formatted ViewModel to ViewController                │
│    viewController?.displayPlaybackState(viewModel)             │
│  }                                                              │
│                                                                 │
│  func presentDebugInfo(                                         │
│    resolution: String,                                          │
│    bitrate: String,                                             │
│    buffering: Int                                               │
│  ) {                                                            │
│    let debugViewModel = DebugInfoViewModel(                     │
│      resolution: resolution,                                    │
│      bitrate: bitrate,                                          │
│      bufferingCount: buffering                                  │
│    )                                                            │
│                                                                 │
│    viewController?.displayDebugInfo(debugViewModel)            │
│  }                                                              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

### 4️⃣ Presenter → View Controller → View (Display Update)

```
┌─────────────────────────────────────────────────────────────────┐
│              VIEW CONTROLLER (ViewController)                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  @Published var playbackViewModel: PlaybackViewModel           │
│  @Published var debugViewModel: DebugInfoViewModel             │
│                                                                 │
│  func displayPlaybackState(_ viewModel: PlaybackViewModel) {   │
│    DispatchQueue.main.async {                                  │
│      // Update properties instead of replacing                 │
│      self.playbackViewModel.isLoading = viewModel.isLoading    │
│      self.playbackViewModel.isPlaying = viewModel.isPlaying    │
│      self.playbackViewModel.errorMessage = viewModel.error     │
│      self.playbackViewModel.bufferingCount = viewModel.count   │
│    }                                                            │
│  }                                                              │
│                                                                 │
│  func displayDebugInfo(_ info: DebugInfoViewModel) {           │
│    DispatchQueue.main.async {                                  │
│      self.debugViewModel.resolution = info.resolution          │
│      self.debugViewModel.bitrate = info.bitrate                │
│      self.debugViewModel.bufferingCount = info.bufferingCount   │
│    }                                                            │
│  }                                                              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                          │
             @Published property changes
             SwiftUI observes changes
                          │
                          ↓
┌─────────────────────────────────────────────────────────────────┐
│                    VIEW (SwiftUI)                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  @ObservedObject var viewController: ViewController            │
│                                                                 │
│  var body: some View {                                         │
│    ZStack {                                                     │
│      VideoPlayer(player: viewController.player)                │
│                                                                 │
│      // Show loading spinner                                   │
│      if viewController.playbackViewModel.isLoading {           │
│        LoadingOverlay()                                         │
│      }                                                          │
│                                                                 │
│      // Show error overlay                                     │
│      if let error = viewController.playbackViewModel.error {   │
│        ErrorOverlay(                                            │
│          message: error,                                        │
│          onRetry: { viewController.retry() }                   │
│        )                                                        │
│      }                                                          │
│                                                                 │
│      // Show debug panel                                       │
│      if showDebug {                                             │
│        DebugPanel(info: viewController.debugViewModel)         │
│      }                                                          │
│    }                                                            │
│  }                                                              │
│                                                                 │
│  private func handleVideoTap(_ stream: VideoStream) {          │
│    viewController.didSelectStream(stream)                      │
│  }                                                              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

### Complete Cycle Diagram

```
STEP 1: USER INTERACTION
┌─────────────────────┐
│   VIEW              │
│ User taps video     │ ─────┐
└─────────────────────┘      │
                             │
                    User Action
                             │
                             ↓
STEP 2: ROUTE TO BUSINESS LOGIC
┌─────────────────────────────────────┐
│   VIEW CONTROLLER (Router)          │
│ • Receives user action              │
│ • Routes to Interactor              │
│ didSelectStream(stream)             │ ─────┐
└─────────────────────────────────────┘      │
                                             │
                                    Calls Interactor
                                             │
                                             ↓
STEP 3: BUSINESS LOGIC & DATA
┌──────────────────────────────────────────────────┐
│   INTERACTOR                                     │
│ • Load stream                                    │
│ • Create AVPlayerItem                           │
│ • Replace player item                           │
│ • Call Worker to setup observers                │
│ loadStream(stream)                              │ ─────┐
└──────────────────────────────────────────────────┘      │
            │                                              │
            │ Calls Worker                                │
            ↓                                              │
┌──────────────────────────────────────────┐              │
│   WORKER                                 │              │
│ • Setup KVO publishers                   │              │
│ • Monitor status changes                 │              │
│ • Monitor buffering                      │              │
│ • Monitor playback stalls                │              │
│ setupKVOObservers(for item, callbacks)   │              │
└──────────────────────────────────────────┘              │
            │                                              │
            │ Callbacks triggered by state changes        │
            ↓                                              │
        Back to Interactor                    Calls Presenter
            │                                              │
            └──────────────────────────────────────────────┤
                                                           │
                                         Interactor passes state
                                                           │
                                                           ↓
STEP 4: FORMAT DATA
┌─────────────────────────────────────┐
│   PRESENTER                         │
│ • Receives PlaybackState            │
│ • Formats for display               │
│ • Creates ViewModel                 │
│ presentPlaybackState(state)         │ ─────┐
└─────────────────────────────────────┘      │
                                             │
                                 Calls ViewController
                                             │
                                             ↓
STEP 5: UPDATE VIEW CONTROLLER
┌──────────────────────────────────────────┐
│   VIEW CONTROLLER                        │
│ • Receives ViewModel                     │
│ • Updates @Published properties          │
│ displayPlaybackState(viewModel)          │
└──────────────────────────────────────────┘
            │
     SwiftUI Observes
     @Published changes
            │
            ↓
STEP 6: RE-RENDER UI
┌──────────────────────────────────────────┐
│   VIEW (SwiftUI)                         │
│ • Re-renders based on ViewModel          │
│ • Shows/hides loading, error, debug      │
│ • Updates UI elements                    │
│ ✓ Loading spinner                        │
│ ✓ Error overlay                          │
│ ✓ Debug info                             │
│ ✓ Video playback state                   │
└──────────────────────────────────────────┘
```

---

### Models Used in Each Layer

| Component | Models Used | Purpose |
|-----------|-------------|---------|
| **View** | `PlaybackViewModel`, `DebugInfoViewModel` | Display formatted data |
| **ViewController** | `PlaybackState`, `PlaybackViewModel` | Translate & store state |
| **Interactor** | `VideoStream`, `PlaybackState` | Manage playback & state |
| **Presenter** | `PlaybackState` → `PlaybackViewModel` | Transform raw to display |
| **Worker** | `AVPlayerItem`, `AVPlayerItem.Status` | Observe & report changes |
| **Models** | `VideoStream`, `PlaybackState` | Raw data entities |

---

## File Structure

```
steam/
├── steam/
│   ├── steamApp.swift
│   │
│   ├── Scenes/
│   │   └── VideoPlayer/
│   │       ├── VideoPlayerRouter.swift            (Dependency Injection)
│   │       ├── VideoPlayerViewController.swift    (ViewController)
│   │       ├── VideoPlayerInteractor.swift        (Business Logic + PlaybackState)
│   │       ├── VideoPlayerPresenter.swift         (Data Formatting)
│   │       ├── VideoPlayerView.swift              (SwiftUI View)
│   │       └── VideoPlayerModels.swift            (ViewModels)
│   │
│   ├── Workers/
│   │   └── VideoPlayerWorker.swift                (Reusable Utilities)
│   │
│   ├── Models/
│   │   └── VideoStream.swift                      (Entity)
│   │
│   └── Views/
│       ├── ContentView.swift
│       └── FullScreenPlayerView.swift
│
└── steam.xcodeproj/
```

---

## Component Responsibilities

| Component | Responsibility |
|-----------|-----------------|
| **View** | Render UI from ViewModels, handle user gestures |
| **ViewController** | Wire components (Router), present View, observe ViewModel |
| **Interactor** | Business logic, playback management, state tracking |
| **Presenter** | Format data for display, create ViewModels |
| **Router** | Wire up dependencies, handle navigation |
| **Worker** | Reusable utilities (KVO, Notifications, formatting) |
| **Models** | Data entities (VideoStream, PlaybackState) |

---

## Request/Response Flow

```swift
// Request (from View to Interactor)
struct VideoPlayerInteractorRequest {
    let stream: VideoStream
}

// Response (from Interactor to Presenter)
struct VideoPlayerInteractorResponse {
    let state: PlaybackState
}

// ViewModel (from Presenter to View)
struct PlaybackViewModel: ObservableObject {
    @Published var isLoading: Bool
    @Published var isPlaying: Bool
    @Published var errorMessage: String?
    @Published var player: AVPlayer
}
```

---

## Dependency Injection (Router)

```swift
class VideoPlayerRouter {
    static func createModule(stream: VideoStream = .sample) -> VideoPlayerViewController {
        // Create Components
        let player = AVPlayer()
        let playbackViewModel = PlaybackViewModel(player: player)

        let presenter = VideoPlayerPresenter()
        let worker = VideoPlayerWorker()
        let interactor = VideoPlayerInteractor(player: player)

        // Wire up dependencies
        interactor.presenter = presenter
        interactor.worker = worker

        // Create ViewController with strong references to all components
        let viewController = VideoPlayerViewController(
            playbackViewModel: playbackViewModel,
            interactor: interactor,
            presenter: presenter,
            worker: worker
        )

        // Set presenter's viewController reference
        presenter.viewController = viewController

        // Load initial stream
        interactor.loadStream(stream)

        return viewController
    }
}
```

---

## Key Benefits

✅ **Separation of Concerns** - Each class has single responsibility  
✅ **Testability** - Easy to mock dependencies  
✅ **Reusability** - Workers can be shared across modules  
✅ **Scalability** - Clear structure for adding features  
✅ **Maintainability** - Data flow is predictable & traceable

---

**Architecture**: Clean Swift (VIP)  
**Platform**: iOS (SwiftUI)  
**Last Updated**: 2024
