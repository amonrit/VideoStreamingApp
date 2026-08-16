Last Modified: 08/17/2026 (1786917831) by amonrit

# Phase 2 Plan: Extract & Organize State Models

## 📋 Overview

**Issue:** #22 - Extract & Organize State Models  
**Depends On:** Phase 1 (#21) ✅ COMPLETE  
**Status:** PLANNING  
**Estimated Effort:** 2-3 hours  

---

## 🎯 Objective

Extract state management concerns from ViewModels into focused, testable models:

1. Move `ConnectionStatus` enum from PlaybackViewModel
2. Create `RetryState` to track retry attempts and timing
3. Create `ViewerCountState` to manage polling and recovery
4. Update PlaybackViewModel to use these new models
5. Comprehensive testing for state transitions

---

## 📊 Current State Analysis

### Current PlaybackViewModel State (Lines 14-45)

**Published Properties:**
```swift
@Published var isLoading: Bool = false
@Published var isPlaying: Bool = false
@Published var errorMessage: String?
@Published var bufferingCount: Int = 0
@Published var currentStream: VideoStream?
@Published var connectionStatus: ConnectionStatus = .disconnected
@Published var retryAttempt: Int = 0
@Published var viewerCount: Int?
```

**Private Retry State:**
```swift
private var retryCount: Int = 0
private let maxRetries: Int = 2
private var retryTimer: Timer?
private var isAutoRetrying: Bool = false
private var totalRetryTime: TimeInterval = 0
```

**Private Viewer Count State:**
```swift
private var viewerCountTimer: Timer?
private var viewerCountFailureCount: Int = 0
private let maxViewerCountFailures: Int = 3
private let viewerCountPollInterval: TimeInterval = 4.0
```

**Constants (Should go to PlaybackConfiguration):**
```swift
private let loadTimeout: TimeInterval = 3.0
private let stallTimeout: TimeInterval = 2.0
```

---

## 🏗️ New State Models Architecture

### 1. ConnectionStatus.swift

**Purpose:** Represent the connection lifecycle of a video stream

**Current Location:** Inside PlaybackViewModel (lines 72-78)  
**New Location:** `steam/Features/Playback/Domain/Entities/ConnectionStatus.swift`

**Structure:**
```swift
public enum ConnectionStatus: Equatable, Hashable, Sendable {
    case disconnected
    case connecting
    case connected
    case buffering
    case failed(String)
    
    // Computed properties
    public var isConnected: Bool
    public var isActive: Bool
    public var displayName: String
    public var canRetry: Bool
}
```

**Computed Properties:**
- `isConnected` → true if connected or buffering
- `isActive` → true if any connection attempt in progress
- `displayName` → Human-readable status
- `canRetry` → Whether retry is allowed

**Tests:**
- ✅ All cases equatable
- ✅ Computed properties return correct values
- ✅ Hashable conformance
- ✅ Display names are non-empty

---

### 2. RetryState.swift

**Purpose:** Encapsulate retry attempt tracking, backoff calculation, and timing

**New Location:** `steam/Features/Playback/Domain/Entities/RetryState.swift`

**Structure:**
```swift
public struct RetryState: Equatable, Sendable {
    private let configuration: PlaybackConfiguration
    private let retryStrategy: RetryStrategy
    
    public private(set) var attemptCount: Int = 0
    public private(set) var lastAttemptTime: Date?
    public private(set) var totalRetryTime: TimeInterval = 0
    public private(set) var isRetrying: Bool = false
    
    public var maxAttempts: Int { configuration.maxRetryAttempts }
    public var nextDelay: TimeInterval { /* calculated from strategy */ }
    public var hasRetriesRemaining: Bool { attemptCount < maxAttempts }
    public var progress: Double { Double(attemptCount) / Double(maxAttempts) }
    
    public mutating func recordAttempt()
    public mutating func recordFailure(error: Error)
    public mutating func recordSuccess()
    public mutating func reset()
}
```

**Key Features:**
- Configuration-driven (uses PlaybackConfiguration)
- Strategy-aware retry calculations
- Tracks timing and attempts
- Progress calculation for UI
- Mutable state management

**Properties:**
- `attemptCount` — Number of retry attempts
- `lastAttemptTime` — When last attempt occurred
- `totalRetryTime` — Cumulative time spent retrying
- `isRetrying` — Currently in retry state
- `nextDelay` — Time to wait before next attempt
- `hasRetriesRemaining` — Can attempt again
- `progress` — Percentage complete (0.0 to 1.0)

**Methods:**
- `recordAttempt()` — Increment attempt count
- `recordFailure(error:)` — Track failed attempt with error
- `recordSuccess()` — Mark as successful and reset
- `reset()` — Clear all retry state

**Tests:**
- ✅ Initialization with configuration
- ✅ Attempt counting
- ✅ Delay calculation (uses RetryStrategy)
- ✅ Progress calculation (0.0 to 1.0)
- ✅ Remaining retries check
- ✅ Reset functionality
- ✅ Success/failure transitions

---

### 3. ViewerCountState.swift

**Purpose:** Manage polling state for viewer count with failure recovery

**New Location:** `steam/Features/Playback/Domain/Entities/ViewerCountState.swift`

**Structure:**
```swift
public struct ViewerCountState: Equatable, Sendable {
    private let configuration: PlaybackConfiguration
    
    public private(set) var currentCount: Int? = nil
    public private(set) var lastUpdateTime: Date?
    public private(set) var failureCount: Int = 0
    public private(set) var isPolling: Bool = false
    public private(set) var lastError: Error?
    
    public var pollingInterval: TimeInterval { 
        configuration.viewerCountPollingInterval 
    }
    public var maxFailures: Int { 
        configuration.maxConcurrentRequests  // or custom value
    }
    public var canContinuePolling: Bool { 
        failureCount < maxFailures 
    }
    public var shouldRetry: Bool { 
        failureCount < maxFailures && !isPolling 
    }
    
    public mutating func startPolling()
    public mutating func stopPolling()
    public mutating func updateCount(_ count: Int)
    public mutating func recordFailure(error: Error)
    public mutating func recordSuccess()
    public mutating func reset()
}
```

**Key Features:**
- Configuration-driven polling intervals
- Failure tracking with threshold
- Automatic retry logic
- Timestamp tracking for UI updates
- Clear state transitions

**Properties:**
- `currentCount` — Latest viewer count
- `lastUpdateTime` — When last update occurred
- `failureCount` — Consecutive poll failures
- `isPolling` — Currently polling
- `lastError` — Last error that occurred
- `pollingInterval` — Time between polls
- `maxFailures` — Failure threshold
- `canContinuePolling` — Check if polling should continue
- `shouldRetry` — Check if retry is appropriate

**Methods:**
- `startPolling()` — Begin polling cycle
- `stopPolling()` — Stop polling
- `updateCount(_:)` — Update viewer count and reset failures
- `recordFailure(error:)` — Increment failure count
- `recordSuccess()` — Mark successful update
- `reset()` — Clear all state

**Tests:**
- ✅ Polling state transitions
- ✅ Failure counting and thresholds
- ✅ Update timestamp tracking
- ✅ Retry logic
- ✅ Configuration integration
- ✅ Success resets failures
- ✅ Reset clears all state

---

## 🔄 Integration Points

### PlaybackViewModel Refactoring

**Before:**
```swift
@Published var retryAttempt: Int = 0
@Published var connectionStatus: ConnectionStatus = .disconnected
private var retryCount: Int = 0
private var totalRetryTime: TimeInterval = 0
private var viewerCountFailureCount: Int = 0
```

**After:**
```swift
@Published var connectionStatus: ConnectionStatus = .disconnected
private var retryState: RetryState
private var viewerCountState: ViewerCountState
```

**Methods to Update:**
- `loadStream(_:)` — Initialize states
- `handleRetry()` — Use `retryState.nextDelay`
- `recordRetryAttempt()` → `retryState.recordAttempt()`
- `stopViewerCountPolling()` → `viewerCountState.stopPolling()`
- `updateViewerCount(_:)` → `viewerCountState.updateCount(_:)`

---

## 📦 File Structure

```
steam/Features/Playback/Domain/Entities/
├── ConnectionStatus.swift          (NEW - move from ViewModel)
├── RetryState.swift                (NEW - extracted state)
├── ViewerCountState.swift          (NEW - extracted state)
├── PlaybackState.swift             (EXISTING)
└── VideoStream.swift               (EXISTING)

steamTests/Features/Playback/Domain/
├── ConnectionStatusTests.swift      (NEW)
├── RetryStateTests.swift            (NEW)
└── ViewerCountStateTests.swift      (NEW)
```

---

## 🧪 Testing Strategy

### ConnectionStatusTests.swift

**Test Cases:** 12-15 tests
- ✅ All cases are equatable
- ✅ Hashable conformance
- ✅ `isConnected` property
- ✅ `isActive` property
- ✅ `canRetry` property
- ✅ Display name generation
- ✅ Failed status with error message

### RetryStateTests.swift

**Test Cases:** 25-30 tests
- ✅ Initialization with configuration
- ✅ Attempt counting increments
- ✅ `hasRetriesRemaining` logic
- ✅ Progress calculation (0.0 to 1.0)
- ✅ `nextDelay` uses RetryStrategy
- ✅ Reset clears all state
- ✅ Success resets state
- ✅ Failure increments counter
- ✅ Timing tracking

### ViewerCountStateTests.swift

**Test Cases:** 20-25 tests
- ✅ Polling state transitions
- ✅ Failure threshold enforcement
- ✅ `canContinuePolling` logic
- ✅ `shouldRetry` logic
- ✅ Update resets failures
- ✅ Timestamp tracking
- ✅ Configuration integration
- ✅ Reset clears all state

---

## ✅ Acceptance Criteria

- [ ] ConnectionStatus.swift created with computed properties (isConnected, isActive)
- [ ] RetryState.swift tracks attempts, backoff, and total time
- [ ] ViewerCountState.swift manages polling failures
- [ ] All models tested with state transition tests (50+ total tests)
- [ ] PlaybackViewModel integration verified (no breaking changes)
- [ ] Build succeeds (DEBUG configuration)

---

## 📋 Implementation Checklist

### Step 1: Create State Models (30 min)
- [ ] ConnectionStatus.swift (move from ViewModel, add computed properties)
- [ ] RetryState.swift (new state model with timing)
- [ ] ViewerCountState.swift (new state model for polling)

### Step 2: Create Tests (45 min)
- [ ] ConnectionStatusTests.swift (12-15 tests)
- [ ] RetryStateTests.swift (25-30 tests)
- [ ] ViewerCountStateTests.swift (20-25 tests)

### Step 3: Refactor PlaybackViewModel (30 min)
- [ ] Update @Published properties
- [ ] Integrate RetryState
- [ ] Integrate ViewerCountState
- [ ] Update retry methods
- [ ] Update viewer count polling

### Step 4: Verification (15 min)
- [ ] Build succeeds
- [ ] All tests pass
- [ ] No breaking changes
- [ ] Commit and close #22

---

## 🚀 Benefits

✅ **Testability** — State models independent of ViewModels  
✅ **Reusability** — Can use states in other ViewModels  
✅ **Clarity** — Clear state transitions and logic  
✅ **Maintainability** — Easier to understand and modify  
✅ **Type Safety** — Enum-based state prevents invalid states  

---

## 🔗 Dependencies

**Requires:**
- ✅ Phase 1 (#21) — PlaybackConfiguration and RetryStrategy

**Required By:**
- Phase 3 (#23) — Extract Polling (uses ViewerCountState)
- Phase 4 (#24) — Extract Retry (uses RetryState)
- Phase 7 (#27) — Structured Concurrency (async/await ready)

---

## 📝 Notes

- Keep ConnectionStatus as public enum (used in UI)
- RetryState and ViewerCountState can be internal if not needed by other features
- All state models should be Sendable for actor compatibility in Phase 7
- Consider adding description properties for logging/debugging

---

**Ready to implement Phase 2! 🚀**
