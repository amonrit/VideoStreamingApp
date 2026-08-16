Last Modified: 08/17/2026 (1786918261) by amonrit

# Phase 3 Plan: Extract Polling to Reusable Service

## 📋 Overview

**Issue:** #23 - Extract Polling to Reusable Service  
**Depends On:** Phase 1 (#21) ✅, Phase 2 (#22) ✅  
**Status:** PLANNING  
**Estimated Effort:** 3-4 hours  

---

## 🎯 Objective

Replace all Timer-based polling with unified PollingService implementation:

1. Create `ViewerCountPollingService` for viewer count polling
2. Refactor `StreamAdminViewModel` to use PollingService
3. Refactor `PlaybackViewModel` to use ViewerCountPollingService
4. Remove all Timer-based polling code
5. Integration tests for end-to-end polling

---

## 📊 Current Polling Analysis

### PlaybackViewModel

**Current Timer Usage:**
```swift
private var viewerCountTimer: Timer?
private let viewerCountPollInterval: TimeInterval = 4.0

// Line 342-349: startViewerCountPolling()
viewerCountTimer = Timer.scheduledTimer(withTimeInterval: viewerCountPollInterval, repeats: true) { [weak self] _ in
    self?.updateViewerCount()
}
viewerCountTimer?.fire()

// Line 354-357: stopViewerCountPolling()
viewerCountTimer?.invalidate()
viewerCountTimer = nil
```

**Polling Logic:**
- Fires immediately: `viewerCountTimer?.fire()`
- Repeats at interval
- Calls `updateViewerCount()`
- Manages failures with `viewerCountFailureCount`

### StreamAdminViewModel

**Current Timer Usage:**
```swift
private var refreshTimer: Timer?
private let refreshInterval: TimeInterval = 2.0

// Line 33-46: startPolling()
refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
    self?.loadStreams()
}

// Line 49-53: stopPolling()
refreshTimer?.invalidate()
refreshTimer = nil
```

**Polling Logic:**
- Repeats at interval (2.0 seconds)
- Calls `loadStreams()`

---

## 🏗️ Phase 3 Implementation Plan

### 1. ViewerCountPollingService.swift

**Purpose:** Specialized polling service for viewer count updates

**Location:** `steam/Features/Playback/Domain/Services/ViewerCountPollingService.swift`

**Structure:**
```swift
public actor ViewerCountPollingService {
    private let configuration: PlaybackConfiguration
    private var pollingService: PollingService<Int>?
    private var pollingTask: Task<Void, Never>?
    
    public init(
        configuration: PlaybackConfiguration = .production,
        fetchCount: @escaping () async throws -> Int
    )
    
    public func startPolling() async
    public func stopPolling() async
    public func getLastCount() async -> Int?
    public func isPolling() async -> Bool
}
```

**Key Features:**
- Uses PollingService<Int> internally
- Configuration-driven (from PlaybackConfiguration)
- Actor-based for thread safety
- Automatic failure tracking
- Clean start/stop API

**Implementation:**
1. Initialize PollingService with viewer count fetching closure
2. Start AsyncSequence iteration on demand
3. Update ViewerCountState with results
4. Handle failures with automatic retry

### 2. StreamAdminPollingService.swift

**Purpose:** Specialized polling service for stream list updates

**Location:** `steam/Features/StreamAdmin/Domain/Services/StreamAdminPollingService.swift`

**Structure:**
```swift
public actor StreamAdminPollingService {
    private let configuration: PlaybackConfiguration
    private var pollingService: PollingService<[MediaMTXConfig]>?
    private var pollingTask: Task<Void, Never>?
    
    public init(
        configuration: PlaybackConfiguration = .production,
        fetchStreams: @escaping () async throws -> [MediaMTXConfig]
    )
    
    public func startPolling() async
    public func stopPolling() async
    public func getLastStreams() async -> [MediaMTXConfig]?
    public func isPolling() async -> Bool
}
```

### 3. Refactor PlaybackViewModel

**Changes:**
- Remove `viewerCountTimer`
- Add `viewerCountPollingService`
- Replace `startViewerCountPolling()` with service call
- Replace `stopViewerCountPolling()` with service call
- Update `updateViewerCount()` to use service results
- Remove `viewerCountPollInterval` (use configuration)

**Before:**
```swift
private var viewerCountTimer: Timer?
private func startViewerCountPolling() {
    viewerCountTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { [weak self] _ in
        self?.updateViewerCount()
    }
}
```

**After:**
```swift
private var viewerCountPollingService: ViewerCountPollingService?
private func startViewerCountPolling() {
    Task {
        await viewerCountPollingService?.startPolling()
    }
}
```

### 4. Refactor StreamAdminViewModel

**Changes:**
- Remove `refreshTimer`
- Add `streamAdminPollingService`
- Replace `startPolling()` implementation
- Replace `stopPolling()` implementation
- Update `loadStreams()` to work with service

**Before:**
```swift
private var refreshTimer: Timer?
func startPolling(baseURL: URL? = nil) {
    refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
        self?.loadStreams()
    }
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

---

## 🧪 Test Strategy

### ViewerCountPollingServiceTests.swift

**Test Cases:** 15-20 tests
- ✅ Initialization with configuration
- ✅ Start/stop polling
- ✅ Fetch and update count
- ✅ Failure handling and retry
- ✅ Multiple concurrent operations
- ✅ Actor isolation

### StreamAdminPollingServiceTests.swift

**Test Cases:** 15-20 tests
- ✅ Initialization with configuration
- ✅ Start/stop polling
- ✅ Fetch and update streams
- ✅ Failure handling and retry
- ✅ Concurrent polling

### PlaybackViewModelPollingIntegrationTests.swift

**Test Cases:** 10-15 tests
- ✅ Viewer count polling integration
- ✅ Start/stop via view model
- ✅ State updates from polling
- ✅ Failure recovery

### StreamAdminViewModelPollingIntegrationTests.swift

**Test Cases:** 10-15 tests
- ✅ Stream polling integration
- ✅ Start/stop via view model
- ✅ State updates from polling
- ✅ Multiple stream handling

---

## ✅ Acceptance Criteria

- [ ] StreamAdminViewModel refactored to use PollingService
- [ ] ViewerCountPollingService created for PlaybackViewModel
- [ ] All Timer-based polling removed
- [ ] Polling behavior identical to original (intervals, failure handling)
- [ ] Integration tests verify end-to-end polling
- [ ] Build succeeds (DEBUG configuration)

---

## 📂 File Structure

**New Services:**
```
steam/Features/Playback/Domain/Services/
└── ViewerCountPollingService.swift

steam/Features/StreamAdmin/Domain/Services/
└── StreamAdminPollingService.swift
```

**New Tests:**
```
steamTests/Features/Playback/Domain/Services/
├── ViewerCountPollingServiceTests.swift
└── PlaybackViewModelPollingIntegrationTests.swift

steamTests/Features/StreamAdmin/Domain/Services/
├── StreamAdminPollingServiceTests.swift
└── StreamAdminViewModelPollingIntegrationTests.swift
```

**Modified Files:**
```
steam/Features/Playback/Presentation/PlaybackViewModel.swift
steam/Features/StreamAdmin/Presentation/StreamAdminViewModel.swift
```

---

## 🔧 Implementation Checklist

### Step 1: Create Polling Services (60 min)
- [ ] ViewerCountPollingService.swift (actor-based)
- [ ] StreamAdminPollingService.swift (actor-based)
- [ ] Both use PollingService<T> internally
- [ ] Both support start/stop/getState operations

### Step 2: Refactor ViewModels (45 min)
- [ ] PlaybackViewModel remove Timer, add service
- [ ] StreamAdminViewModel remove Timer, add service
- [ ] Update method signatures
- [ ] Preserve original polling behavior

### Step 3: Create Tests (75 min)
- [ ] ViewerCountPollingServiceTests (15-20 tests)
- [ ] StreamAdminPollingServiceTests (15-20 tests)
- [ ] Integration tests for ViewModels (20-30 tests)

### Step 4: Verification (30 min)
- [ ] Build succeeds
- [ ] All tests pass
- [ ] No Timer references remain
- [ ] Polling behavior preserved

---

## 🚀 Benefits

✅ **Unified Polling** — All polling uses PollingService  
✅ **Actor Safety** — Services are actors (thread-safe)  
✅ **Configuration Driven** — Use PlaybackConfiguration  
✅ **Testable** — Services can be mocked in tests  
✅ **Maintainable** — No more Timer management  
✅ **Composable** — Reusable for other features  

---

## 🔗 Dependencies

**Requires:**
- ✅ Phase 1 (#21) - PollingService<T> available
- ✅ Phase 2 (#22) - ViewerCountState available

**Enables:**
- Phase 4 (#24) - Extract Retry Logic (can use service for retry orchestration)
- Phase 5 (#25) - Consolidate Timers (all Timer usage eliminated)

---

**Ready to implement Phase 3!** 🚀
