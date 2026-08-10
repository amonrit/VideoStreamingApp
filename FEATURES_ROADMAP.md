Last Modified: 08/10/2026 (1786362333) by amonrit

# Steam - Features Roadmap & Recommendations

## 📱 Project Overview

**Steam** is an iOS video streaming app using **MVVM (Model-View-ViewModel) Architecture** with HLS playback, adaptive bitrate, fullscreen support, and debug metrics.

### Current Features
- ✅ HLS video playback
- ✅ Adaptive bitrate streaming
- ✅ Loading/Error handling
- ✅ Debug metrics (resolution, bitrate, buffering)
- ✅ Fullscreen mode
- ✅ MVVM architecture
- ✅ Streaming server (MediaMTX, Docker)
- ✅ Multi-protocol support (RTMP, RTSP, WebRTC, SRT)
- ✅ CLAUDE.md AI guidance
- ✅ Antigravity semantic analysis
- ✅ Commit message template
- ✅ **Playback Controls** (Play/Pause, Seek, Speed)
- ✅ **Manual Quality Selection** (Auto/720p/480p/360p/240p)

---

## 💡 Recommended Features (Priority Order)

### **Tier 0: Development & Infrastructure** 🔵 (Foundation)

#### 0️⃣ **Development Guides (DONE!)** ⭐⭐⭐
- ✅ DEVELOPMENT.md - Local development guide
- ✅ AI_WORKFLOW.md - Working with AI effectively
- ✅ TROUBLESHOOTING.md - Common issues & solutions (defer)
- ✅ CONTRIBUTING.md - Contribution guidelines (defer)

**Why:** Essential for productivity and onboarding

**Effort:** 2-4 hours | **Impact:** 🔵 Foundation

---

#### 📊 **Streaming Server Features** ⭐⭐
**Problem it solves:**
```
- No way to manage multiple streams
- No recording management UI
- No stream statistics/analytics
- No authentication management
```

**Features to add:**
- [ ] Stream management dashboard (list active streams)
- [ ] Recording browser (view saved recordings)
- [ ] Stream analytics (viewers, bitrate, duration)
- [ ] Multi-server support (deploy to multiple machines)
- [ ] Stream on/off scheduler
- [ ] Webhook notifications (stream started/stopped)

**Implementation:** Companion web app or update server

**Why:** Makes server production-ready and manageable

**Effort:** 2-3 days | **Impact:** 🟠 High

---

### **Tier 1: Essential Playback Features** 🔴 (Add First)

#### 1️⃣ **Playback Controls** ⭐⭐⭐ ✅ DONE
**Problem it solves:**
```
- Users cannot Play/Pause during playback
- No progress bar or seek functionality
- No time display (current/total duration)
- Cannot control playback speed
```

**Features to add:**
- [x] Play/Pause button (toggle state)
- [x] Progress slider (Seek bar) with scrubbing
- [x] Current time / Total duration display (00:30 / 02:00)
- [x] Playback speed control (0.5x, 1x, 1.5x, 2x)
- [x] Time label updates (every 100ms)

**Implementation Files:**
- Update `VideoPlayerWorker` to expose `currentTime` and `duration` publishers
- Add time tracking properties to `PlaybackViewModel`
- Create playback control UI in `VideoPlayerView`
- Add time tracking and seeking methods to `PlaybackViewModel`

**Why:** This is essential - users expect basic playback controls from any video player

**Effort:** 1 day | **Impact:** 🔴 Critical

---

#### 2️⃣ **Manual Quality Selection** ⭐⭐⭐ ✅ DONE
**Problem it solves:**
```
- Users cannot manually select video quality
- On low bandwidth, stream may buffer unnecessarily
- No visibility into available quality options
```

**Features to add:**
- [x] Extract available qualities from HLS manifest (master.m3u8)
- [x] Display quality options: Auto, 720p, 480p, 360p, 240p
- [x] Quality selection menu/dropdown
- [x] Show current quality indicator badge
- [x] Persist quality preference

**Implementation Files:**
- Add `QualityManager` worker class
- Add `@Published var availableQualities` to `PlaybackViewModel`
- Create `QualitySelectionView` in Views/
- Add quality selection methods to `PlaybackViewModel`

**Why:** Gives users control over streaming quality based on their bandwidth

**Effort:** 1-2 days | **Impact:** 🟠 High

**Technical Note:** HLS files have multiple bitrate variants:
```swift
// master.m3u8 typically contains:
#EXT-X-STREAM-INF:BANDWIDTH=2560000,RESOLUTION=1280x720
variant-720p.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=1280000,RESOLUTION=854x480
variant-480p.m3u8
```

---

#### 3️⃣ **Network Status Indicator** ⭐⭐⭐
**Problem it solves:**
```
- Users cannot see if network is the problem
- Debug metrics are hidden/not obvious
- No indication of connection type/strength
```

**Features to add:**
- [ ] Network type indicator (WiFi, 4G, 5G, LTE)
- [ ] Connection strength bars (signal strength)
- [ ] Real-time throughput display (Mbps)
- [ ] Connection status in top bar
- [ ] Auto-quality adjustment indicator

**Implementation Files:**
- Create `NetworkMonitor` worker using `Network.framework`
- Add `@Published` properties to `PlaybackViewModel` for network state
- Create `NetworkStatusView` component in Views/
- Add network monitoring initialization to `PlaybackViewModel`

**Why:** Users understand buffering/lag better when they see network status

**Effort:** 0.5 days | **Impact:** 🟠 High

---

### **Tier 2: UX Enhancements** 🟠

#### 4️⃣ **Gesture Controls** ⭐⭐
**Problem it solves:**
```
- Must tap buttons for every action
- No intuitive swipe gestures like YouTube/Netflix
- Accessibility could be better
```

**Features to add:**
- [ ] Double tap to play/pause
- [ ] Single tap to show/hide controls (auto-hide after 5s)
- [ ] Swipe left = rewind 15 seconds
- [ ] Swipe right = forward 15 seconds
- [ ] Swipe up/down = brightness/volume control
- [ ] Long press = playback speed adjustment

**Implementation Files:**
- Add gesture recognizers to `VideoPlayerView`
- Add gesture handler methods to `PlaybackViewModel`
- Create helper methods for seek (rewind/forward 15s)
- Add auto-hide control logic via @State in VideoPlayerView

**Why:** Modern video players (YouTube, Netflix, Apple TV) use these gestures

**Effort:** 1 day | **Impact:** 🟡 Medium

---

#### 5️⃣ **Watch History & Continue Watching** ⭐⭐
**Problem it solves:**
```
- Users must remember which stream they watched last
- Cannot resume from last position
- No way to quickly access recently watched content
```

**Features to add:**
- [ ] Save playback position every 10 seconds
- [ ] Show "Continue Watching" section on home screen
- [ ] Display last watched timestamp (e.g., "2 minutes ago")
- [ ] Auto-resume from saved position
- [ ] Clear history option

**Implementation Files:**
- Create `HistoryManager` worker
- Add `PlaybackHistory` model to Models/
- Persist with UserDefaults or CoreData
- Update `ContentView` to show history section
- Add resume methods to `PlaybackViewModel`

**Why:** Makes app feel native and personalized

**Effort:** 1 day | **Impact:** 🟡 Medium

**Data Structure:**
```swift
struct PlaybackHistory {
    let streamId: UUID
    let title: String
    let thumbnailURL: URL
    let lastPosition: CMTime
    let lastWatchedDate: Date
}
```

---

#### 6️⃣ **Picture-in-Picture (PiP)** ⭐⭐
**Problem it solves:**
```
- Users must close app or go fullscreen to do other things
- Cannot multitask while watching
```

**Features to add:**
- [ ] PiP button in player controls
- [ ] Keep playback while switching apps
- [ ] Resizable floating window
- [ ] Quick return to fullscreen
- [ ] PiP support for backgrounded playback

**Implementation Files:**
- Add PiP button to `VideoPlayerView` or custom controls
- Use `AVPlayerViewController` with PiP support
- Add PiP state management to `PlaybackViewModel`
- Ensure AVPlayer lifecycle preserved during PiP transitions

**Why:** iOS users expect PiP (like YouTube, Apple TV+)

**Effort:** 1 day | **Impact:** 🟡 Medium

---

### **Tier 3: Content & Accessibility** 🟡

#### 7️⃣ **Subtitle/Caption Support** ⭐
**Problem it solves:**
```
- No subtitle support
- International content is inaccessible to non-native speakers
- Cannot watch without audio
```

**Features to add:**
- [ ] Parse subtitle tracks from HLS manifest
- [ ] Support VTT and SRT subtitle formats
- [ ] Subtitle selection dropdown
- [ ] Multiple language support
- [ ] Subtitle size/style customization
- [ ] Toggle on/off

**Implementation Files:**
- Create `SubtitleManager` worker with parsing logic
- Add `SubtitleTrack` model to Models/
- Add `@Published var subtitleTracks` to `PlaybackViewModel`
- Create subtitle selector UI in Views/
- Add subtitle rendering component (text overlay)

**Why:** Expands audience to international users and hearing-impaired users

**Effort:** 2-3 days | **Impact:** 🟡 Medium

**Technical Note:**
```swift
// HLS manifests can include:
#EXT-X-MEDIA:TYPE=SUBTITLES,LANGUAGE="en",NAME="English",
  GROUP-ID="subs",CHARACTERISTICS="public.accessibility.describes-music-and-sound"
#EXT-X-MEDIA:TYPE=SUBTITLES,LANGUAGE="es",NAME="Español",
  GROUP-ID="subs"
```

---

#### 8️⃣ **Offline Download** 
**Problem it solves:**
```
- Requires internet connection to watch
- Cannot save content for airplane/subway viewing
```

**Features to add:**
- [ ] Download button with progress indicator
- [ ] Local cache management
- [ ] Offline playback support
- [ ] Downloaded video expiration policy
- [ ] Storage usage display
- [ ] Batch download support

**Implementation Files:**
- Create `DownloadManager` worker using `AVAssetDownloadTask`
- Add `DownloadedVideo` model to Models/
- Add download state to `PlaybackViewModel`
- Create download progress view
- Add offline playback detection to `PlaybackViewModel`

**Why:** Common feature in streaming apps (Netflix, YouTube, Disney+)

**Effort:** 3-4 days | **Impact:** 🟢 Nice-to-have

---

### **Tier 4: Testing & Quality** 🟢

#### 9️⃣ **Comprehensive Test Suite** ⭐⭐
**Problem it solves:**
```
- Limited test coverage
- No integration tests
- No UI tests
- Manual testing required before release
```

**Features to add:**
- [ ] Unit tests (PlaybackViewModel, Workers)
- [ ] Integration tests (ViewModel + Worker)
- [ ] UI tests (SwiftUI components)
- [ ] Snapshot tests (visual regression)
- [ ] Performance tests (memory, CPU)
- [ ] E2E tests (full flow)
- [ ] CI/CD pipeline (automated testing on every PR)

**Implementation:**
- XCTest framework (built-in)
- Consider: SnapshotTesting library
- GitHub Actions for CI/CD

**Why:** Catch bugs early, ensure quality, enable refactoring safely

**Effort:** 3-5 days | **Impact:** 🟢 Quality Assurance

---

### **Tier 5: Analytics & Monitoring** 🟢

#### 🔟 **Enhanced Debug Dashboard** ⭐
**Problem it solves:**
```
- Debug metrics are hidden behind toggle
- Developers need better visibility into streaming health
- No historical data or trends
```

**Features to add:**
- [ ] Full-screen debug dashboard
- [ ] Real-time graph widgets (bitrate, buffering over time)
- [ ] Frame drops counter
- [ ] Network latency indicator
- [ ] Buffer health percentage
- [ ] Memory usage tracking
- [ ] Video quality history
- [ ] Export debug logs

**Implementation Files:**
- Create `DebugDashboardView` in Views/ with Charts framework
- Create `MetricsCollector` worker for historical tracking
- Add metrics history to `PlaybackViewModel`
- Create persistent metrics storage (UserDefaults/CoreData)
- Enhance debug panel with real-time graphs

**Why:** Helps developers and QA diagnose streaming issues quickly

**Effort:** 2 days | **Impact:** 🟢 Development Tool

---

#### 1️⃣1️⃣ **App Analytics** ⭐
**Problem it solves:**
```
- No visibility into how users interact with app
- Can't measure feature adoption
- Can't identify performance bottlenecks in production
```

**Features to add:**
- [ ] Analytics event tracking (stream loaded, played, errors)
- [ ] User session tracking
- [ ] Crash reporting (Sentry/Firebase)
- [ ] Performance monitoring
- [ ] Feature adoption metrics
- [ ] Error trend analysis

**Why:** Data-driven decisions for prioritizing features

**Effort:** 2 days | **Impact:** 🟢 Analytics

---

## 🔧 Implementation Roadmap

### **Recommended Implementation Order**

**Foundation (Complete):**
- ✅ Phase 0: Development guides (DEVELOPMENT.md, AI_WORKFLOW.md)

```
Phase 1 (In Progress):
├── ✅ 1. Playback Controls (DONE!)
├── ✅ 2. Quality Selection (DONE!)
└── 3. Network Status (0.5 days) ← NEXT

Phase 2 (Week 3-4):
├── 4. Gesture Controls (1 day)
├── 5. Watch History (1 day)
├── 6. PiP Support (1 day)
└── 7. Test Suite (3-5 days) ← Parallel

Phase 3 (Week 5+):
├── 8. Streaming Server Features (2-3 days)
├── 9. Subtitles (2-3 days)
├── 10. Offline Download (3-4 days)
└── 11. Debug Dashboard + Analytics (4 days)
```

---

## 📊 Impact & Effort Matrix

| Feature | Effort | Impact | Priority | Timeline |
|---------|--------|--------|----------|----------|
| **Development Guides** | 2-4 hrs | 🔵 Foundation | P0 | ✅ Done |
| **Playback Controls** | 1 day | 🔴 Critical | P0 | ✅ Done |
| **Quality Selection** | 1-2 days | 🟠 High | P0 | ✅ Done |
| **Network Status** | 0.5 days | 🟠 High | P0 | Next |
| **Test Suite** | 3-5 days | 🟠 High | P0 | Week 2+ |
| **Gesture Controls** | 1 day | 🟡 Medium | P1 | Week 2 |
| **Watch History** | 1 day | 🟡 Medium | P1 | Week 2 |
| **PiP Support** | 1 day | 🟡 Medium | P1 | Week 2 |
| **Server Features** | 2-3 days | 🟠 High | P1 | Week 3+ |
| **Subtitles** | 2-3 days | 🟡 Medium | P2 | Week 3+ |
| **Offline Download** | 3-4 days | 🟢 Nice | P2 | Week 4+ |
| **Debug Dashboard** | 2 days | 🟢 Dev Tool | P2 | Week 3+ |
| **Analytics** | 2 days | 🟢 Analytics | P2 | Week 4+ |

---

## 🎯 Recommended Strategy

### **Start with Tier 1** (Playback Controls + Quality Selection + Network Status)

**Why?**
1. ✅ **Complete core loop** - App becomes actually usable
2. ✅ **Quick wins** - 80% benefit with 20% effort
3. ✅ **Clean Swift compatible** - Fits current architecture
4. ✅ **User retention** - Users return if controls work
5. ✅ **Foundation** - Base for future features

**Timeline:** 2-3 days to MVP-quality streaming experience

---

## 🏗️ Architecture Considerations

### Adding Features Maintains MVVM

All recommended features can be integrated while maintaining the **MVVM architecture**:

```
Views (UI Components)
    ↓ observe
PlaybackViewModel (State + Business Logic + new features)
    ↓ use
Workers (Utilities - new ones as needed)
    ↓ observe/control
AVPlayer & Model Entities
```

### Adding Features to PlaybackViewModel

As you add features, extend `PlaybackViewModel`:
- Add `@Published` properties for new state (currentTime, duration, qualities, etc.)
- Add public methods for user actions (seek, selectQuality, toggleSubtitles, etc.)
- Add private handlers for observer callbacks
- Keep business logic encapsulated in the ViewModel

### New Workers to Create

Create specialized workers for complex tasks:
- `PlaybackControlsWorker` - Time tracking, seeking helpers
- `QualityManager` - Quality selection logic
- `NetworkMonitor` - Network status tracking (via Network framework)
- `HistoryManager` - Watch history persistence
- `SubtitleManager` - Subtitle handling & parsing
- `DownloadManager` - Offline download via AVAssetDownloadTask

Each worker stays testable, reusable, and independent.

---

## 📝 Notes

- All features can be toggled via debug settings initially
- Maintain debug mode for QA testing
- Create feature flags for gradual rollout
- Test each feature on low-bandwidth network
- Monitor app performance as features grow
