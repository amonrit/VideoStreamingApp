Last Modified: 08/17/2026 (1786918722) by amonrit

# Phase 4 Plan: Extract Retry Logic into RetryOrchestrator

## 📋 Overview

**Issue:** #24 - Extract Retry Logic  
**Depends On:** Phase 1 (#21) ✅, Phase 2 (#22) ✅, Phase 3 (#23) ✅  
**Status:** IN PROGRESS  
**Progress:** RetryOrchestrator implemented, needs tests + integration  

---

## 🎯 Objective

Complete the RetryOrchestrator implementation by:

1. Create comprehensive unit tests for RetryOrchestrator
2. Integrate RetryOrchestrator into PlaybackViewModel
3. Remove old retry properties from PlaybackViewModel
4. Verify all retry behavior matches original implementation

---

## 📊 Current State

### RetryOrchestrator ✅ (95 LOC)
**Location:** `steam/Features/Playback/Domain/Services/RetryOrchestrator.swift`

**Features Implemented:**
- Generic `attemptWithRetry<T>()` method
- Uses RetryState from Phase 2
- Uses RetryStrategy from Phase 1
- Uses PlaybackConfiguration from Phase 1
- Async/await error handling
- Status message notifications (callbacks)
- Sendable conformance for thread safety

**Ready For:**
- PlaybackViewModel integration
- Unit tests

### PlaybackViewModel Current Retry Code ⚠️
**Location:** `steam/Features/Playback/Presentation/PlaybackViewModel.swift`

**Old Retry Properties to Remove:**
```swift
@Published var retryAttempt: Int = 0              // Lines 21
private var retryCount: Int = 0                   // Line 28
private let maxRetries: Int = 2                   // Line 29
private var retryTimer: Timer?                    // Line 30
private var isAutoRetrying: Bool = false          // Line 32
private var totalRetryTime: TimeInterval = 0      // Line 33
```

**Old Retry Methods/Logic:**
- `handleLoadingTimeout()` — implements backoff logic
- `retry()` method — manual retry trigger
- Timeout handling with retryTimer

---

## 🏗️ Phase 4 Implementation Plan

### Step 1: Create RetryOrchestrator Unit Tests (45 min)

**File:** `steamTests/Features/Playback/Domain/Services/RetryOrchestratorTests.swift`

**Test Suite (25-30 tests):**

#### A. Initialization Tests (3 tests)
- ✅ Initialize with default configuration
- ✅ Initialize with custom configuration
- ✅ Initialize with status callback

#### B. Basic Retry Tests (5 tests)
- ✅ Successful operation on first attempt
- ✅ Successful operation on second attempt after failure
- ✅ Successful operation on final attempt (max retries)
- ✅ Failure after max retries
- ✅ Error types propagate correctly

#### C. Retry State Tests (5 tests)
- ✅ Attempt count increments correctly
- ✅ Retry delay increases exponentially (1s → 2s → 4s)
- ✅ Jitter applied to delay (±25%)
- ✅ Max delay cap at 5 seconds
- ✅ hasRetriesRemaining computed correctly

#### D. Status Callback Tests (4 tests)
- ✅ Status callback fires on each attempt
- ✅ Success message format correct
- ✅ Failure message with backoff time
- ✅ Final failure message

#### E. Error Handling Tests (3 tests)
- ✅ Last error tracked correctly
- ✅ Error propagates to caller
- ✅ RetryOrchestratorError.maxRetriesExceeded

#### F. State Management Tests (3 tests)
- ✅ Reset clears attempt count
- ✅ Reset clears last error
- ✅ getState() returns current state

#### G. Sendable Conformance Tests (2 tests)
- ✅ Can be passed to async/await contexts
- ✅ Works with Task.detached

---

### Step 2: Integrate RetryOrchestrator into PlaybackViewModel (60 min)

**File:** `steam/Features/Playback/Presentation/PlaybackViewModel.swift`

**Changes Required:**

#### 2a. Add RetryOrchestrator Property
```swift
private var retryOrchestrator: RetryOrchestrator?
```

#### 2b. Update loadStream() Method
- Initialize RetryOrchestrator when loading new stream
- Set status callback to update UI
- Replace timeout/retry timer logic with orchestrator

#### 2c. Update retry() Method
```swift
// OLD:
func retry() {
    retryCount = 0
    // ... manual retry logic
}

// NEW:
func retry() {
    // Use retryOrchestrator.attemptWithRetry() in loadStream continuation
}
```

#### 2d. Update UI State Binding
- Keep `@Published var retryAttempt: Int` (for UI)
- Update it from RetryOrchestrator status callbacks
- Remove `isAutoRetrying` property (no longer needed)

#### 2e. Replace Timeout Handler
**Current:** `handleLoadingTimeout()` with manual backoff
**New:** Use `retryOrchestrator.attemptWithRetry()` wrapper

**Pseudo-code:**
```swift
func loadStreamWithRetry(_ stream: VideoStream) {
    Task {
        do {
            let result = try await retryOrchestrator.attemptWithRetry {
                // Original stream loading operation
                try await loadStreamOperation(stream)
            } onError: { error, attempt in
                logger.error("Retry attempt \(attempt): \(error)")
                self.retryAttempt = attempt
            }
            // Handle result
        } catch {
            // Handle final failure
            presentError(error.localizedDescription)
        }
    }
}
```

---

### Step 3: Remove Old Retry Code (30 min)

**Delete/Modify:**
- ❌ `retryCount` property
- ❌ `maxRetries` constant (use PlaybackConfiguration instead)
- ❌ `retryTimer` property
- ❌ `isAutoRetrying` property
- ❌ `totalRetryTime` property
- ❌ Timeout timer handlers for retry
- ❌ Manual backoff calculation logic

**Keep:**
- ✅ `@Published var retryAttempt` (for UI)
- ✅ `connectionStatus` (still needed)
- ✅ Manual `retry()` method (now uses orchestrator)
- ✅ Error display logic

---

### Step 4: Create Integration Tests (30 min)

**File:** `steamTests/Features/Playback/Presentation/PlaybackViewModelIntegrationTests.swift`

**Test Cases (12-15 tests):**
- ✅ Load stream with successful retry
- ✅ Load stream fails after max retries
- ✅ Retry count UI updates correctly
- ✅ Status messages appear during retry
- ✅ Manual retry() method still works
- ✅ Multiple stream loads in sequence

---

## ✅ Acceptance Criteria

- [ ] RetryOrchestrator unit tests (25-30 tests, all passing)
- [ ] PlaybackViewModel refactored to use RetryOrchestrator
- [ ] Old retry properties removed (retryCount, retryTimer, isAutoRetrying)
- [ ] Retry behavior identical to original (delays, max attempts)
- [ ] UI updates still work (retryAttempt published property)
- [ ] Integration tests verify end-to-end retry flow
- [ ] Build succeeds (DEBUG configuration)
- [ ] All existing tests still pass

---

## 📂 File Structure

**New Files:**
```
steamTests/Features/Playback/Domain/Services/
└── RetryOrchestratorTests.swift

steamTests/Features/Playback/Presentation/
└── PlaybackViewModelIntegrationTests.swift
```

**Modified Files:**
```
steam/Features/Playback/Presentation/PlaybackViewModel.swift
steam/Features/Playback/Domain/Services/RetryOrchestrator.swift (may add helpers)
```

---

## 🔧 Implementation Checklist

### Step 1: Write RetryOrchestrator Tests (45 min)
- [ ] Create RetryOrchestratorTests.swift
- [ ] Write initialization tests (3)
- [ ] Write basic retry tests (5)
- [ ] Write state tests (5)
- [ ] Write callback tests (4)
- [ ] Write error handling tests (3)
- [ ] Write state management tests (3)
- [ ] Write Sendable conformance tests (2)
- [ ] All tests pass

### Step 2: Integrate into PlaybackViewModel (60 min)
- [ ] Add retryOrchestrator property
- [ ] Initialize in loadStream()
- [ ] Wrap stream loading in attemptWithRetry()
- [ ] Connect status callbacks to UI
- [ ] Update retry() method
- [ ] Fix compilation errors
- [ ] Build succeeds

### Step 3: Remove Old Code (30 min)
- [ ] Remove retryCount property
- [ ] Remove maxRetries constant
- [ ] Remove retryTimer property
- [ ] Remove isAutoRetrying property
- [ ] Remove totalRetryTime property
- [ ] Remove timeout timer retry logic
- [ ] Fix any references to old properties

### Step 4: Create Integration Tests (30 min)
- [ ] Create PlaybackViewModelIntegrationTests.swift
- [ ] Write integration test cases (12-15 tests)
- [ ] All tests pass
- [ ] Integration tests verify behavior

### Step 5: Verification (20 min)
- [ ] Build succeeds (Debug)
- [ ] All unit tests pass
- [ ] All integration tests pass
- [ ] Manual testing in simulator
- [ ] Retry behavior works correctly

---

## 🚀 Expected Benefits

✅ **Centralized Retry Logic** — All retry behavior in one place  
✅ **Testable** — RetryOrchestrator can be tested independently  
✅ **Reusable** — Other ViewModels can use same orchestrator  
✅ **Configuration Driven** — Uses PlaybackConfiguration for settings  
✅ **Observable** — Status callbacks for UI updates  
✅ **Cleaner Code** — Removes 50+ lines of retry boilerplate  

---

## 🔗 Dependencies

**Requires:**
- ✅ Phase 1 (#21) - RetryStrategy, PlaybackConfiguration
- ✅ Phase 2 (#22) - RetryState, ViewerCountState
- ✅ Phase 3 (#23) - PollingService (for reference)

**Enables:**
- Phase 5+ - Enhanced testing, feature modules

---

## 📊 Metrics

**Current State:**
- RetryOrchestrator: 95 LOC ✅
- Tests: 0 LOC ❌
- Integration: 0 LOC ❌

**After Phase 4:**
- RetryOrchestrator: ~95 LOC (stable)
- RetryOrchestratorTests: ~400 LOC
- PlaybackViewModel: -50 LOC (cleaner)
- Integration tests: ~300 LOC
- **Total Addition:** ~650 LOC

---

**Ready to implement Phase 4!** 🎯
