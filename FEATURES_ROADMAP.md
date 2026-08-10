# Steam - Features Roadmap & Recommendations

## 📱 Project Overview

**Steam** is an iOS video streaming app using **Clean Swift (VIP) Architecture** with HLS playback, adaptive bitrate, fullscreen support, and debug metrics.

### Current Features
- ✅ HLS video playback
- ✅ Adaptive bitrate streaming
- ✅ Loading/Error handling
- ✅ Debug metrics (resolution, bitrate, buffering)
- ✅ Fullscreen mode
- ✅ Clean Swift (VIP) architecture

---

## 💡 Recommended Features (Priority Order)

### **Tier 1: Essential Playback Features** 🔴 (Add First)

#### 1️⃣ **Playback Controls** ⭐⭐⭐
**Problem it solves:**
```
- Users cannot Play/Pause during playback
- No progress bar or seek functionality
- No time display (current/total duration)
- Cannot control playback speed
```

**Features to add:**
- [ ] Play/Pause button (toggle state)
- [ ] Progress slider (Seek bar) with scrubbing
- [ ] Current time / Total duration display (00:30 / 02:00)
- [ ] Playback speed control (0.5x, 1x, 1.5x, 2x)
- [ ] Time label updates (every 100ms)

**Implementation Files:**
- Update `VideoPlayerWorker` to expose `currentTime` and `duration` publishers
- Add time tracking in `VideoPlayerInteractor`
- Create playback control UI in `VideoPlayerView`
- Add `PlaybackControlsViewModel` to `VideoPlayerModels.swift`

**Why:** This is essential - users expect basic playback controls from any video player

**Effort:** 1 day | **Impact:** 🔴 Critical

---

#### 2️⃣ **Manual Quality Selection** ⭐⭐⭐
**Problem it solves:**
```
- Users cannot manually select video quality
- On low bandwidth, stream may buffer unnecessarily
- No visibility into available quality options
```

**Features to add:**
- [ ] Extract available qualities from HLS manifest (master.m3u8)
- [ ] Display quality options: Auto, 720p, 480p, 360p, 240p
- [ ] Quality selection menu/dropdown
- [ ] Show current quality indicator badge
- [ ] Persist quality preference

**Implementation Files:**
- Add `QualityManager` to `VideoPlayerWorker`
- Add `availableQualities` property to playback state
- Create `QualitySelectionView` in UI
- Parse HLS variant streams from manifest

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
- Add `NetworkMonitor` using `NetworkFramework`
- Update `DebugInfoViewModel` with network properties
- Create `NetworkStatusView` component
- Add network monitoring to `VideoPlayerWorker`

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
- Create `GestureHandlerWorker`
- Connect gestures to `VideoPlayerInteractor` methods
- Add auto-hide control logic

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
- Create `HistoryManager` (new Worker)
- Add `PlaybackHistory` model
- Persist with UserDefaults or CoreData
- Update `ContentView` to show history
- Add resume UI in video selection

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
- Update `VideoPlayerViewController` to support PiP
- Add `AVPlayerViewController` for PiP handling
- Create PiP button in UI controls
- Manage AVPlayer lifecycle for background

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
- Add subtitle parsing to `VideoPlayerWorker`
- Create `SubtitleManager` class
- Add `SubtitleTrack` model
- Update UI with subtitle selector
- Create subtitle rendering component

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
- Create `DownloadManager` using `AVAssetDownloadTask`
- Add `DownloadedVideo` model
- Create download queue/manager
- Update `VideoPlayerInteractor` for offline playback
- Create download progress view

**Why:** Common feature in streaming apps (Netflix, YouTube, Disney+)

**Effort:** 3-4 days | **Impact:** 🟢 Nice-to-have

---

### **Tier 4: Analytics & Monitoring** 🟢

#### 9️⃣ **Enhanced Debug Dashboard** ⭐
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
- Create `DebugDashboardView` with Charts
- Add data persistence for metrics history
- Create `MetricsCollector` worker
- Enhance `DebugInfoViewModel` with historical data

**Why:** Helps developers and QA diagnose streaming issues quickly

**Effort:** 2 days | **Impact:** 🟢 Development Tool

---

## 🔧 Implementation Roadmap

### **Recommended Implementation Order**

```
Phase 1 (Week 1):
├── 1. Playback Controls (1 day)
├── 2. Quality Selection (1-2 days)
└── 3. Network Status (0.5 days)

Phase 2 (Week 2):
├── 4. Gesture Controls (1 day)
├── 5. Watch History (1 day)
└── 6. PiP Support (1 day)

Phase 3 (Week 3+):
├── 7. Subtitles (2-3 days)
├── 8. Offline Download (3-4 days)
└── 9. Enhanced Debug Dashboard (2 days)
```

---

## 📊 Impact & Effort Matrix

| Feature | Effort | Impact | Priority | Timeline |
|---------|--------|--------|----------|----------|
| **Playback Controls** | 1 day | 🔴 Critical | P0 | Week 1 |
| **Quality Selection** | 1-2 days | 🟠 High | P0 | Week 1 |
| **Network Status** | 0.5 days | 🟠 High | P0 | Week 1 |
| **Gesture Controls** | 1 day | 🟡 Medium | P1 | Week 2 |
| **Watch History** | 1 day | 🟡 Medium | P1 | Week 2 |
| **PiP Support** | 1 day | 🟡 Medium | P1 | Week 2 |
| **Subtitles** | 2-3 days | 🟡 Medium | P2 | Week 3+ |
| **Offline Download** | 3-4 days | 🟢 Nice | P2 | Week 4+ |
| **Debug Dashboard** | 2 days | 🟢 Dev Tool | P2 | Week 3+ |

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

### Adding Features Maintains Clean Swift

All recommended features can be integrated while maintaining the **VIP architecture**:

```
View (UI Components)
    ↓
ViewController (Routing & State)
    ↓
Interactor (Business Logic + new features)
    ↓
Presenter (Format Data)
    ↓
Workers (Utilities - new ones as needed)
```

### New Workers to Create

As you add features, create new workers:
- `PlaybackControlsWorker` - Time tracking, seeking
- `QualityManager` - Quality selection logic
- `NetworkMonitor` - Network status tracking
- `GestureHandlerWorker` - Gesture recognition
- `HistoryManager` - Watch history persistence
- `SubtitleManager` - Subtitle handling
- `DownloadManager` - Offline download

Each worker stays testable, reusable, and independent.

---

## 📝 Notes

- All features can be toggled via debug settings initially
- Maintain debug mode for QA testing
- Create feature flags for gradual rollout
- Test each feature on low-bandwidth network
- Monitor app performance as features grow

---

**Last Updated:** 2026-08-10
