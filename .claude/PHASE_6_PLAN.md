Last Modified: 08/17/2026 (1786919530) by amonrit

# Phase 6 Plan: Improve API Client Dependency Injection

## 📋 Overview

**Issue:** #26 - Improve API Client Dependency Injection (Optional)  
**Depends On:** Phase 1-5 (all previous phases)  
**Status:** PLANNING  
**Estimated Effort:** 2-3 hours  
**Priority:** Medium (Optional, improves testability)

---

## 🎯 Objective

Establish consistent, testable dependency injection pattern for MediaMTXAPIClient across all ViewModels:

1. Create APIClientProvider protocol
2. Implement DefaultAPIClientProvider (production)
3. Implement MockAPIClientProvider (testing)
4. Refactor ViewModels to use provider pattern
5. Improve testability without changing behavior

---

## 📊 Current State Analysis

### Current API Client Usage

**PlaybackViewModel:**
```swift
private var mediaMTXClient: MediaMTXAPIClient?

// Initialized when stream detected as MediaMTX
if let (baseURL, pathName) = MediaMTXConfig.mediaMTXTarget(for: url) {
    mediaMTXClient = MediaMTXAPIClient(baseURL: baseURL)
}
```

**StreamAdminViewModel:**
```swift
let client = MediaMTXAPIClient(baseURL: targetBaseURL)
```

**Issues:**
- Direct instantiation makes testing difficult
- No consistent pattern across ViewModels
- Mock clients require editing test code
- Hard to swap implementations

### Proposed Solution

**APIClientProvider Protocol:**
```swift
protocol APIClientProvider {
    func createAPIClient(baseURL: URL) -> MediaMTXAPIClient
    func getDefaultClient() -> MediaMTXAPIClient?
}

class DefaultAPIClientProvider: APIClientProvider {
    func createAPIClient(baseURL: URL) -> MediaMTXAPIClient {
        MediaMTXAPIClient(baseURL: baseURL)
    }
    
    func getDefaultClient() -> MediaMTXAPIClient? {
        guard let url = URL(string: "http://localhost:9997") else { return nil }
        return MediaMTXAPIClient(baseURL: url)
    }
}

class MockAPIClientProvider: APIClientProvider {
    var mockClient: MockMediaMTXAPIClient?
    
    func createAPIClient(baseURL: URL) -> MediaMTXAPIClient {
        mockClient ?? MediaMTXAPIClient(baseURL: baseURL)
    }
    
    func getDefaultClient() -> MediaMTXAPIClient? {
        mockClient
    }
}
```

---

## 🏗️ Phase 6 Implementation Plan

### Step 1: Create APIClientProvider Protocol (30 min)

**Location:** `steam/Core/DI/APIClientProvider.swift`

**Components:**
1. APIClientProvider protocol
2. DefaultAPIClientProvider implementation
3. MockAPIClientProvider implementation
4. Error types for provider failures

**Key Features:**
- Factory pattern for creating clients
- Consistent initialization
- Testable design
- Type-safe

### Step 2: Refactor PlaybackViewModel (30 min)

**Location:** `steam/Features/Playback/Presentation/PlaybackViewModel.swift`

**Changes:**
1. Add APIClientProvider property
2. Accept provider in init (with default)
3. Use provider to create clients
4. Maintain backward compatibility

**Before:**
```swift
private var mediaMTXClient: MediaMTXAPIClient?

if let (baseURL, pathName) = MediaMTXConfig.mediaMTXTarget(for: url) {
    mediaMTXClient = MediaMTXAPIClient(baseURL: baseURL)
}
```

**After:**
```swift
private var apiClientProvider: APIClientProvider = DefaultAPIClientProvider()
private var mediaMTXClient: MediaMTXAPIClient?

if let (baseURL, pathName) = MediaMTXConfig.mediaMTXTarget(for: url) {
    mediaMTXClient = apiClientProvider.createAPIClient(baseURL: baseURL)
}
```

### Step 3: Refactor StreamAdminViewModel (30 min)

**Location:** `steam/Features/StreamAdmin/Presentation/StreamAdminViewModel.swift`

**Changes:**
1. Add APIClientProvider property
2. Accept provider in init (with default)
3. Use provider for client creation
4. Maintain backward compatibility

**Before:**
```swift
let client = MediaMTXAPIClient(baseURL: targetBaseURL)
```

**After:**
```swift
let client = apiClientProvider.createAPIClient(baseURL: targetBaseURL)
```

### Step 4: Create Test Support Classes (30 min)

**Location:** `steamTests/Mocks/MockAPIClientProvider.swift`

**Components:**
1. MockAPIClientProvider with configurable behavior
2. MockMediaMTXAPIClient with stubs
3. Test helpers for common scenarios

**Features:**
- Control mock responses
- Track method calls
- Inject failures
- Verify behavior

### Step 5: Update Test Cases (30 min)

**Files to Update:**
- PlaybackViewModelTests.swift
- StreamAdminViewModelTests.swift

**Changes:**
1. Create ViewModels with mock provider
2. Control API responses in tests
3. Verify error handling
4. Test retry behavior with failures

**Example:**
```swift
let mockProvider = MockAPIClientProvider()
let viewModel = PlaybackViewModel(apiClientProvider: mockProvider)

// Configure mock to return specific data
mockProvider.mockClient?.setNextPaths([...])

// Verify behavior
viewModel.loadStream(stream)
XCTAssertEqual(viewModel.viewerCount, 42)
```

---

## ✅ Acceptance Criteria

- [ ] APIClientProvider protocol created
- [ ] DefaultAPIClientProvider implemented
- [ ] MockAPIClientProvider implemented
- [ ] PlaybackViewModel refactored to use provider
- [ ] StreamAdminViewModel refactored to use provider
- [ ] No behavioral changes (backward compatible)
- [ ] Test coverage improved
- [ ] Build succeeds (DEBUG configuration)
- [ ] All existing tests still pass

---

## 📂 File Structure

**New Files:**
```
steam/Core/DI/APIClientProvider.swift
steamTests/Mocks/MockAPIClientProvider.swift
steamTests/Mocks/MockMediaMTXAPIClient.swift
```

**Modified Files:**
```
steam/Features/Playback/Presentation/PlaybackViewModel.swift
steam/Features/StreamAdmin/Presentation/StreamAdminViewModel.swift
```

---

## 🔧 Implementation Checklist

### Step 1: Create Protocol (30 min)
- [ ] Create APIClientProvider.swift
- [ ] Define protocol with factory methods
- [ ] Implement DefaultAPIClientProvider
- [ ] Implement MockAPIClientProvider
- [ ] Add error types if needed
- [ ] Build succeeds

### Step 2: Refactor PlaybackViewModel (30 min)
- [ ] Add apiClientProvider property
- [ ] Update init to accept provider
- [ ] Replace direct instantiation with provider
- [ ] Add default initializer for backward compatibility
- [ ] Update all client creation sites
- [ ] Build succeeds

### Step 3: Refactor StreamAdminViewModel (30 min)
- [ ] Add apiClientProvider property
- [ ] Update init to accept provider
- [ ] Replace direct instantiation with provider
- [ ] Add default initializer for backward compatibility
- [ ] Update all client creation sites
- [ ] Build succeeds

### Step 4: Create Test Support (30 min)
- [ ] Create MockAPIClientProvider
- [ ] Create MockMediaMTXAPIClient
- [ ] Add configuration methods
- [ ] Add verification helpers
- [ ] Build succeeds

### Step 5: Update Tests (30 min)
- [ ] Create test cases using mock provider
- [ ] Test success scenarios
- [ ] Test failure scenarios
- [ ] Test retry behavior
- [ ] All tests pass

---

## 🚀 Benefits

✅ **Better Testability** — Mock clients injected, no HTTP calls in tests  
✅ **Cleaner Code** — Consistent pattern across ViewModels  
✅ **Flexible** — Easy to swap implementations  
✅ **Type-Safe** — Protocol-based design  
✅ **Backward Compatible** — Default behavior unchanged  

---

## 🔗 Dependencies

**Requires:**
- ✅ Phase 1-5 (foundation)

**Enables:**
- Better unit testing
- Easier integration testing
- Future: Alternative API implementations

---

## 📊 Expected Impact

**Code Changes:**
- New files: 3 (protocol, mock implementations)
- Modified files: 2 (ViewModels)
- Lines added: ~200 LOC
- Lines removed: ~10 LOC
- Net: +190 LOC (mostly tests/mocks, which is good)

**Testability:**
- Mock providers: Testable without network
- Behavior verification: Easier to test edge cases
- Error scenarios: Can be triggered predictably

---

**Ready to implement Phase 6!** 🚀
