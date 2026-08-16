Last Modified: 08/17/2026 (1786919310) by amonrit

# Phase 5 Plan: Consolidate Timer Management

## 📋 Overview

**Issue:** #25 - Consolidate Timer Management  
**Depends On:** Phase 3 (#23) ✅, Phase 4 (#24) ✅  
**Status:** PLANNING  
**Estimated Effort:** 2-3 hours  

---

## 🎯 Objective

Replace all remaining manual Timer instances with service-based polling and async/await patterns:

1. Replace `viewerCountTimer` in PlaybackViewModel with ViewerCountPollingService
2. Replace `refreshTimer` in StreamAdminViewModel with StreamAdminPollingService
3. Refactor VideoPlayerView timers to use async Task patterns
4. Remove all manual Timer management code
5. Improve testability and maintainability

---

## 📊 Current Timer Analysis

### PlaybackViewModel

**Current Timer Usage:**
```swift
private var viewerCountTimer: Timer?
private let viewerCountPollInterval: TimeInterval = 4.0

func startViewerCountPolling() {
    guard let client = mediaMTXClient, let pathName = mediaMTXPathName else { return }
    viewerCountTimer?.invalidate()
    viewerCountTimer = Timer.scheduledTimer(withTimeInterval: viewerCountPollInterval, repeats: true) { [weak self] _ in
        self?.pollViewerCount(client: client, pathName: pathName)
    }
    viewerCountTimer?.fire()
}

func stopViewerCountPolling() {
    viewerCountTimer?.invalidate()
    viewerCountTimer = nil
}
```

**Issue:** Manual Timer management, not testable, scattered code

**Solution:** Use ViewerCountPollingService (created in Phase 3)

### StreamAdminViewModel

**Current Timer Usage:**
```swift
private var refreshTimer: Timer?
private let refreshInterval: TimeInterval = 2.0

func startPolling(baseURL: URL? = nil) {
    refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
        self?.loadStreams()
    }
}

func stopPolling() {
    refreshTimer?.invalidate()
    refreshTimer = nil
}
```

**Issue:** Manual Timer management, not testable

**Solution:** Use StreamAdminPollingService (created in Phase 3)

### VideoPlayerView

**Current Timer Usages:**

1. **hideControlsTimer:**
```swift
@State private var hideControlsTimer: Timer?

private func resetHideControlsTimer() {
    hideControlsTimer?.invalidate()
    hideControlsTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { _ in
        withAnimation { isControlsVisible = false }
    }
}
```

**Issue:** Manual timer, UI-specific

**Solution:** Use async Task with Task.sleep()

2. **updateTimer:**
```swift
@State private var updateTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

.onReceive(updateTimer) { _ in
    // Update progress
}
```

**Issue:** Using Timer.publish, continuous polling

**Solution:** Use TimelineView or async Task

---

## 🏗️ Phase 5 Implementation Plan

### Step 1: Replace PlaybackViewModel Timer (45 min)

**File:** `steam/Features/Playback/Presentation/PlaybackViewModel.swift`

**Changes:**
1. Add ViewerCountPollingService property
2. Initialize service in init()
3. Replace startViewerCountPolling() with service call
4. Replace stopViewerCountPolling() with service call
5. Remove viewerCountTimer and related properties

**Before:**
```swift
private var viewerCountTimer: Timer?

func startViewerCountPolling() {
    viewerCountTimer = Timer.scheduledTimer(...)
}
```

**After:**
```swift
private var viewerCountPollingService: ViewerCountPollingService?

func startViewerCountPolling() {
    Task {
        await viewerCountPollingService?.startPolling()
    }
}
```

### Step 2: Replace StreamAdminViewModel Timer (45 min)

**File:** `steam/Features/StreamAdmin/Presentation/StreamAdminViewModel.swift`

**Changes:**
1. Add StreamAdminPollingService property
2. Initialize service when base URL set
3. Replace startPolling() with service call
4. Replace stopPolling() with service call
5. Remove refreshTimer and related properties

**Before:**
```swift
private var refreshTimer: Timer?

func startPolling(baseURL: URL? = nil) {
    refreshTimer = Timer.scheduledTimer(...)
}
```

**After:**
```swift
private var streamAdminPollingService: StreamAdminPollingService?

func startPolling(baseURL: URL? = nil) {
    Task {
        await streamAdminPollingService?.startPolling()
    }
}
```

### Step 3: Refactor VideoPlayerView Timers (30 min)

**File:** `steam/Features/Playback/Presentation/VideoPlayerView.swift`

**Changes for hideControlsTimer:**
1. Remove Timer property
2. Use Task.sleep() with async/await
3. Properly cancel task on view disappear

**Before:**
```swift
@State private var hideControlsTimer: Timer?
hideControlsTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { _ in
    withAnimation { isControlsVisible = false }
}
```

**After:**
```swift
@State private var hideControlsTask: Task<Void, Never>?

private func resetHideControlsTimer() {
    hideControlsTask?.cancel()
    hideControlsTask = Task {
        try await Task.sleep(nanoseconds: 5_000_000_000)
        withAnimation { isControlsVisible = false }
    }
}
```

**Changes for updateTimer:**
1. Replace Timer.publish with Task-based loop
2. Use async/await for periodic updates

**Before:**
```swift
@State private var updateTimer = Timer.publish(every: 0.5, ...).autoconnect()

.onReceive(updateTimer) { _ in
    // Update progress
}
```

**After:**
```swift
.task {
    while !Task.isCancelled {
        // Update progress
        try await Task.sleep(nanoseconds: 500_000_000)
    }
}
```

---

## ✅ Acceptance Criteria

- [ ] PlaybackViewModel uses ViewerCountPollingService instead of Timer
- [ ] StreamAdminViewModel uses StreamAdminPollingService instead of Timer
- [ ] VideoPlayerView hideControlsTimer replaced with async Task
- [ ] VideoPlayerView updateTimer replaced with TimelineView or Task loop
- [ ] All manual Timer properties removed
- [ ] Polling behavior identical to original
- [ ] Build succeeds (DEBUG configuration)
- [ ] All existing tests still pass

---

## 📂 File Structure

**Modified Files:**
```
steam/Features/Playback/Presentation/PlaybackViewModel.swift
steam/Features/StreamAdmin/Presentation/StreamAdminViewModel.swift
steam/Features/Playback/Presentation/VideoPlayerView.swift
```

**No new files required** (services already created in Phase 3)

---

## 🔧 Implementation Checklist

### Step 1: PlaybackViewModel (45 min)
- [ ] Add ViewerCountPollingService property
- [ ] Initialize service in init()
- [ ] Update startViewerCountPolling()
- [ ] Update stopViewerCountPolling()
- [ ] Remove viewerCountTimer property
- [ ] Remove viewerCountPollInterval constant
- [ ] Remove pollViewerCount() method if now handled by service
- [ ] Build succeeds

### Step 2: StreamAdminViewModel (45 min)
- [ ] Add StreamAdminPollingService property
- [ ] Update startPolling() method
- [ ] Update stopPolling() method
- [ ] Remove refreshTimer property
- [ ] Remove refreshInterval constant
- [ ] Build succeeds

### Step 3: VideoPlayerView (30 min)
- [ ] Refactor hideControlsTimer to Task-based
- [ ] Refactor updateTimer to Task loop or TimelineView
- [ ] Remove Timer imports/dependencies if no longer needed
- [ ] Build succeeds

### Step 4: Testing (20 min)
- [ ] Build succeeds (Debug)
- [ ] No compilation errors/warnings
- [ ] Manual testing of polling behavior
- [ ] UI responsiveness verified

---

## 🚀 Benefits

✅ **Zero Manual Timers** — All timing handled by services or async patterns  
✅ **Better Testing** — PollingServices are testable (created in Phase 3)  
✅ **Cleaner Code** — 40-50 LOC of boilerplate removed  
✅ **Async/Await** — Modern Swift concurrency patterns  
✅ **Maintainability** — Centralized timer patterns  

---

## 🔗 Dependencies

**Requires:**
- ✅ Phase 3 (#23) - ViewerCountPollingService, StreamAdminPollingService

**Notes:**
- ViewerCountPollingService already implemented in Phase 3
- StreamAdminPollingService already implemented in Phase 3
- Just need to wire them into ViewModels

---

**Ready to implement Phase 5!** 🚀
