# Development Guide

This guide explains how to develop, debug, and work on the Steam project locally.

---

## Quick Start (2 minutes)

```bash
# Start everything
make dev-all

# Or separately:
make dev-server    # Start streaming server
make dev-app       # Open iOS app in Xcode
```

---

## Project Structure

Understanding where things are:

```
steam/
├── steam/                           ← iOS App Source
│   ├── steamApp.swift               Entry point
│   ├── Models/
│   │   ├── VideoStream.swift        (URL, title, thumbnail)
│   │   └── PlaybackState.swift      (Enum: idle, loading, playing, etc.)
│   ├── ViewModels/
│   │   └── PlaybackViewModel.swift  ← CORE LOGIC (start here)
│   ├── Views/
│   │   ├── ContentView.swift        Main UI
│   │   ├── VideoPlayerView.swift    Player UI
│   │   └── FullScreenPlayerView.swift Fullscreen mode
│   └── Workers/
│       └── VideoPlayerWorker.swift  KVO observers, format extraction
│
├── streaming/                       ← Streaming Server (Docker)
│   ├── docker-compose.yml           Container definition
│   ├── mediamtx.yml                 Server configuration
│   ├── .env.example                 Environment template
│   └── recordings/                  Recorded streams
│
├── Makefile                         Development shortcuts
├── .editorconfig                    Code style rules
├── .gitmessage                      Commit message template
└── .claude/                         AI configuration

```

### Where to Make Changes

| Task | Location | Command |
|------|----------|---------|
| **Fix/Add UI** | `steam/Views/` | `make dev-app` then Cmd+R |
| **Fix business logic** | `steam/ViewModels/PlaybackViewModel.swift` | Edit + Cmd+R |
| **Fix data model** | `steam/Models/` | Edit + rebuild |
| **Fix server config** | `streaming/mediamtx.yml` | Edit + `make server-restart` |
| **Fix worker utility** | `steam/Workers/` | Edit + Cmd+R |

---

## Running Locally

### Start Everything

```bash
make dev-all
```

This:
1. Starts streaming server (Docker)
2. Opens Xcode with iOS app
3. Both ready to use!

### Start Separately

**Streaming Server:**
```bash
make dev-server
# Server runs on:
# - HLS:   http://localhost:8888/live/mystream/index.m3u8
# - RTMP:  rtmp://localhost:1935/live/mystream
# - RTSP:  rtsp://localhost:8554/live/mystream
```

**iOS App:**
```bash
make dev-app
# Xcode opens
# Press Cmd+R to run in simulator
```

---

## Common Development Tasks

### "I need to change the UI"

```bash
# 1. Edit the View
open steam/Views/ContentView.swift

# 2. See changes instantly
# In Xcode: Cmd+R (hot reload)

# 3. Verify it looks right
# Test in simulator
```

**File Guide:**
- `ContentView.swift` - Main layout
- `VideoPlayerView.swift` - Player + controls
- `FullScreenPlayerView.swift` - Fullscreen mode

### "I need to fix playback logic"

```bash
# 1. Edit ViewModel
open steam/ViewModels/PlaybackViewModel.swift

# 2. Look for the method you need to change
# Example: loadStream(), handleStatusChange(), etc.

# 3. Make your change

# 4. Write a test
open steam/Tests/PlaybackViewModelTests.swift
# Add test for your change

# 5. Run test
make test-app

# 6. Rebuild
Cmd+B in Xcode
```

**Key Methods in PlaybackViewModel:**
- `loadStream(_:)` - Load a new stream
- `play()` - Start playback
- `pause()` - Stop playback
- `retry()` - Retry after failure
- `handleStatusChange(_:)` - React to player status
- `handleBuffering()` - React to buffering
- `handleFailedToPlayToEnd(_:)` - React to errors

### "I need to debug the streaming server"

```bash
# 1. Watch live logs
make server-logs

# 2. Look for error patterns
# ERR:  Something failed
# INFO: Normal operation

# 3. Common issues:
# - "Port already in use" → Kill process: lsof -i :8888
# - "Config error" → Check mediamtx.yml syntax
# - "Stream not found" → Check if publishing

# 4. Restart after changes
make server-restart
```

### "I need to test a URL/stream"

```bash
# Check if HLS endpoint works
curl -v http://localhost:8888/live/mystream/index.m3u8

# Should return:
# - 200 OK if stream running
# - 404 if stream not publishing
# - 302 if redirect

# Play in command line
ffplay "http://localhost:8888/live/mystream/index.m3u8"
```

### "I need to debug the iOS app"

```bash
# 1. Open Console in Xcode
# View → Debug Area → Show Console

# 2. Filter by category [playback]
# Click the funnel icon, type: [playback]

# 3. Look for log messages
# ✅ = Success
# ❌ = Error
# 📊 = Debug info

# 4. Find specific log lines
# Example: logger.error("Failed to load stream")
# Appears as: [playback] ❌ Failed to load stream

# 5. Check for crashes
# Search for "EXC_BAD_ACCESS" or "signal 11"
# Usually means memory issue
```

---

## Debugging Tips

### Memory Leaks

```bash
# In Xcode:
# 1. Product → Scheme → Edit Scheme
# 2. Run → Diagnostics tab
# 3. Enable "Malloc Stack Logging"
# 4. Run: Cmd+R
# 5. Xcode will show memory warnings
```

### Performance Issues

```bash
# In Xcode:
# 1. Product → Profile (Cmd+I)
# 2. Select "Time Profiler"
# 3. Record for 30 seconds
# 4. Look for hot spots (red)
# 5. Click to see which method is slow
```

### Network Issues

```bash
# Test connectivity
ping -c 5 localhost

# Test streaming
curl -I http://localhost:8888/live/mystream/index.m3u8

# Check ports are open
lsof -i :8888  # HLS
lsof -i :1935  # RTMP
lsof -i :8554  # RTSP
```

---

## Architecture Patterns

### MVVM Pattern (Used Here)

**Views** observe ViewModel:
```swift
struct ContentView: View {
    @ObservedObject var viewModel: PlaybackViewModel
    
    var body: some View {
        // Reads from viewModel.isPlaying, currentStream, etc.
        // Calls viewModel.loadStream() on user action
    }
}
```

**ViewModel** owns logic:
```swift
class PlaybackViewModel: ObservableObject {
    @Published var isPlaying = false
    
    func loadStream(_ stream: VideoStream) {
        // Business logic here
        // Updates @Published properties
        // Views re-render automatically
    }
}
```

**Workers** do reusable work:
```swift
let worker = VideoPlayerWorker()
worker.setupKVOObservers(
    for: item,
    onStatusChange: { status in
        viewModel.handleStatusChange(status)
    }
)
```

### Key Patterns to Follow

✅ **Use @StateObject** for objects you create:
```swift
@StateObject private var viewModel = PlaybackViewModel()
```

✅ **Use [weak self]** in closures:
```swift
worker.setupObservers { [weak self] in
    self?.handleChange()
}
```

✅ **Keep business logic in ViewModel**:
```swift
// ✅ Good - logic in ViewModel
class PlaybackViewModel {
    func handleBuffering() { /* logic */ }
}

// ❌ Bad - logic in View
struct VideoPlayerView: View {
    var body: some View {
        if isBuffering {
            // Complex logic here - WRONG!
        }
    }
}
```

---

## File Editing Tips

### Swift Files

Files that matter most:
- `steam/ViewModels/PlaybackViewModel.swift` - If changing logic
- `steam/Views/ContentView.swift` - If changing main UI
- `steam/Views/VideoPlayerView.swift` - If changing player UI
- `steam/Workers/VideoPlayerWorker.swift` - If changing observers

Edit with:
```bash
# Open in Xcode (recommended)
make dev-app

# Or edit directly
open steam/ViewModels/PlaybackViewModel.swift
```

### Configuration Files

- `streaming/mediamtx.yml` - Server config (edit + restart)
- `.editorconfig` - Code style (automatic, no edit needed)
- `.gitmessage` - Commit template (used automatically)
- `.claude/settings.json` - AI config (loaded automatically)

---

## Testing

### Run All Tests

```bash
make test-app
```

### Write Tests

Create tests in `steam/Tests/`:

```swift
import XCTest
@testable import steam

class PlaybackViewModelTests: XCTestCase {
    var viewModel: PlaybackViewModel!
    
    override func setUp() {
        super.setUp()
        viewModel = PlaybackViewModel()
    }
    
    func testLoadStreamWithValidURL() {
        let stream = VideoStream(
            id: UUID(),
            title: "Test",
            urlString: "http://localhost:8888/live/test/index.m3u8",
            thumbnailURLString: "http://example.com/thumb.jpg"
        )
        
        viewModel.loadStream(stream)
        
        XCTAssertEqual(viewModel.currentStream, stream)
        XCTAssertTrue(viewModel.isLoading)
    }
}
```

### Run Specific Test

```bash
# Run one test class
make test-app -- PlaybackViewModelTests

# Run one test method
make test-app -- PlaybackViewModelTests/testLoadStreamWithValidURL
```

---

## Useful Commands

```bash
# Start/Stop
make dev-all           # Start everything
make dev-server        # Start server only
make dev-app           # Open iOS app only
make server-stop       # Stop streaming server
make clean             # Clean build artifacts

# Debugging
make server-logs       # Watch server logs
make server-status     # Check if running
make server-test       # Run verification test
make test-app          # Run unit tests

# Info
make help              # Show all commands
make info              # Show project info
```

---

## Common Issues & Solutions

### "Can't connect to streaming server"

```bash
# 1. Check if it's running
make server-status

# 2. If not, start it
make dev-server

# 3. Check logs
make server-logs

# 4. Look for "listening on" messages
```

### "Xcode says 'No such file or directory'"

```bash
# 1. Clean build
Cmd+Shift+K in Xcode

# 2. Delete derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# 3. Rebuild
Cmd+B in Xcode
```

### "App crashes when loading stream"

```bash
# 1. Check console for error
# Xcode: View → Debug Area → Show Console

# 2. Look for log messages
# Search for "❌" or "error"

# 3. Check streaming server is running
make server-status

# 4. Verify URL format
# Should be: http://IP:8888/live/mystream/index.m3u8
# NOT: http://localhost:8888/... (use IP for network access)
```

### "Can't access from iPhone on WiFi"

```bash
# 1. Get server IP
ifconfig | grep "inet "
# Should show: inet 192.168.x.x

# 2. Phone must be on SAME WiFi
# Check WiFi network name matches

# 3. Update URL with IP
# http://192.168.x.x:8888/live/mystream/index.m3u8

# 4. Check firewall
# macOS: System Preferences → Security & Privacy → Firewall
# Allow incoming connections on port 8888
```

---

## Next Steps

- Read `ARCHITECTURE.md` for deep architecture understanding
- Read `AI_WORKFLOW.md` for working with AI effectively
- Read `.claude/antigravity-guide.md` for using Antigravity
- Check `.claude/instructions/swift-style.md` for code style

---

## Quick Reference

| Need | Command | Time |
|------|---------|------|
| Quick test | `make dev-all` | 2 min |
| See logs | `make server-logs` | 1 min |
| Run tests | `make test-app` | 2 min |
| Full rebuild | `Cmd+Shift+K` then `Cmd+B` | 5 min |
| Fresh start | `make clean && make dev-all` | 10 min |

**Pro Tip:** Keep `make server-logs` running in a terminal window while developing. You'll spot issues immediately!
