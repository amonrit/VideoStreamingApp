Last Modified: 08/19/2026 (1787138654) by amonrit

# Coordinator Pattern Migration Plan

## Executive Summary

**Issues:** #33 (remove unused DIContainer) + #35 (fix incomplete AppCoordinator)

**Recommendation:** Implement a **modern Coordinator pattern** (not traditional) optimized for SwiftUI 6.0 + MVVM + StateActor architecture. Replace deprecated NavigationView/NavigationLink with NavigationStack + state-based routing.

**Scope:** 3 phases, ~40 files affected, estimated 2-3 days of work

---

## Current State Analysis

### ❌ Problems Identified

| Issue | File | Impact | Severity |
|-------|------|--------|----------|
| Dead DIContainer | `Core/DI/DIContainer.swift` | ~70 lines of unused code, confusion about DI pattern | P1 |
| Incomplete AppCoordinator | `App/AppCoordinator.swift` | Just a template, no routing logic | P1 |
| Deprecated Navigation APIs | Multiple Views | NavigationView/NavigationLink (deprecated in iOS 16+) | P2 |
| Direct ViewModel Creation | All Views | No DI, hard to test, tight coupling | P2 |
| Mixed Navigation Patterns | HomeView, VideoStreamListView | Some use NavigationLink, some manual dismiss | P3 |

### Current Architecture

```
steamApp.swift
  └─ HomeView (NavigationView + NavigationLink)
       ├─ VideoStreamListView (creates PlaybackViewModel directly)
       │   ├─ VideoPlayerView
       │   ├─ AddStreamSheet
       │   └─ SuggestedVideoRow
       ├─ StreamAdminView (creates StreamAdminViewModel directly)
       └─ SettingsView (uses presentationMode)

DIContainer.swift (created but unused)
AppCoordinator.swift (incomplete template, not integrated)
```

**Navigation Flow:**
- Navigation state is **scattered** across views
- No centralized routing logic
- No dependency injection for ViewModels
- Mixing old and new navigation patterns

---

## Recommended Solution: Modern Coordinator Pattern

### Why Not Traditional Coordinator?

❌ **Traditional Coordinator** (used in UIKit):
- Requires complex delegate patterns
- Doesn't align well with SwiftUI's declarative nature
- Creates extra boilerplate

✅ **Modern Coordinator** (SwiftUI-native):
- Uses `NavigationStack` + `@State`-based routing
- Coordinates navigation + dependency injection
- Cleaner separation of concerns
- Works seamlessly with MVVM + StateActor

### Architecture Overview

```
steamApp.swift
  └─ AppCoordinator (manages navigation state + DI)
       ├─ @Published navigationPath: [NavigationPath]
       ├─ func createPlaybackViewModel() → PlaybackViewModel
       ├─ func createStreamAdminViewModel() → StreamAdminViewModel
       └─ func navigate(to: AppRoute)

AppRoute (enum for all navigation)
  case watchStreams
  case streamAdmin
  case settings
  case player(stream: VideoStream)

Views (presentation-only)
  ├─ HomeView (observe AppCoordinator, tap → coordinator.navigate())
  ├─ VideoStreamListView (uses injected ViewModel + coordinator)
  └─ etc.
```

### Key Concepts

1. **AppCoordinator** = Navigation hub + Dependency Injector
   - Holds navigation state (`@Published navigationPath`)
   - Creates ViewModels with proper dependencies
   - Routes navigation requests

2. **AppRoute** (enum) = All possible navigation destinations
   - Type-safe routing
   - Decodable for deep linking (future-proof)

3. **StateActor** Integration
   - ViewModels continue using StateActor for state
   - Coordinator doesn't manage screen state, only navigation

4. **Dependency Injection**
   - Coordinator creates ViewModels with injected dependencies
   - Views receive ViewModels via constructor, not @StateObject

---

## Implementation Plan

### Phase 1: Foundation (Day 1)

**Goals:** 
- Create modern AppCoordinator
- Define AppRoute enum
- Update DIContainer to use Coordinator pattern
- Update steamApp.swift

**Files to Create/Modify:**

#### 1.1 Create AppRoute.swift
```swift
// steam/App/AppRoute.swift
enum AppRoute: Hashable {
    case watchStreams
    case streamAdmin
    case settings
}
```

#### 1.2 Refactor AppCoordinator.swift
**Before:** 12-line incomplete template
**After:** ~100-line full coordinator

Key responsibilities:
```swift
class AppCoordinator: ObservableObject {
    @Published var navigationPath: [AppRoute] = []
    private let diContainer: DIContainer
    
    // Navigation methods
    func navigate(to route: AppRoute)
    func goBack()
    
    // ViewModel factory methods
    func makePlaybackViewModel() → PlaybackViewModel
    func makeStreamAdminViewModel() → StreamAdminViewModel
}
```

**Changes:**
- Remove incomplete TODO
- Add navigation state management
- Add ViewModel factory methods
- Inject DIContainer

#### 1.3 Update DIContainer.swift
**Keep but transform:**
- ✅ Keep dependency creation (good abstraction)
- ❌ Remove singleton pattern (let Coordinator manage it)
- ✅ Add methods for each ViewModel

**New structure:**
```swift
class DIContainer {
    func makePlaybackViewModel() → PlaybackViewModel
    func makeStreamAdminViewModel() → StreamAdminViewModel
}
```

#### 1.4 Update steamApp.swift
**Before:**
```swift
@main
struct steamApp: App {
    @StateObject private var themeManager = ThemeManager()
    
    var body: some Scene {
        WindowGroup {
            HomeView()
        }
    }
}
```

**After:**
```swift
@main
struct steamApp: App {
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var coordinator = AppCoordinator()
    
    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $coordinator.navigationPath) {
                HomeView()
                    .navigationDestination(for: AppRoute.self) { route in
                        coordinator.navigationView(for: route)
                    }
            }
            .environmentObject(coordinator)
            .environmentObject(themeManager)
        }
    }
}
```

**Estimated effort:** 2-3 hours

---

### Phase 2: View Updates (Day 2)

**Goals:**
- Update HomeView to use modern navigation
- Update VideoStreamListView to use injected ViewModel
- Update StreamAdminView to use injected ViewModel
- Update SettingsView to use modern dismissal

**Files to Modify:**

#### 2.1 HomeView.swift
**Changes:**
- Remove `NavigationView`
- Remove `NavigationLink` with tag/selection
- Replace with `onTapGesture` → `coordinator.navigate()`
- Inject `@EnvironmentObject coordinator: AppCoordinator`

**Before (line 43-54):**
```swift
NavigationLink(
    destination: VideoStreamListView(),
    tag: MenuOption.watchStreams,
    selection: $selectedMenuOption
) {
    MenuCardView(...)
}
```

**After:**
```swift
MenuCardView(...)
    .onTapGesture {
        coordinator.navigate(to: .watchStreams)
    }
```

**Estimated effort:** 1 hour

#### 2.2 VideoStreamListView.swift
**Changes:**
- Remove `NavigationView`
- Remove `@StateObject private var playbackViewModel = PlaybackViewModel()`
- Add `@EnvironmentObject coordinator: AppCoordinator`
- Receive ViewModel from coordinator (pass as init parameter)
- Update navigation to use NavigationStack

**Before (line 11):**
```swift
@StateObject private var playbackViewModel = PlaybackViewModel()
```

**After:**
```swift
@EnvironmentObject var coordinator: AppCoordinator
let playbackViewModel: PlaybackViewModel
```

**Constructor:**
```swift
init(playbackViewModel: PlaybackViewModel) {
    self.playbackViewModel = playbackViewModel
}
```

**Estimated effort:** 1.5 hours

#### 2.3 StreamAdminView.swift
**Similar to VideoStreamListView:**
- Remove NavigationView
- Receive ViewModel from coordinator
- Update navigation

**Estimated effort:** 1 hour

#### 2.4 SettingsView.swift
**Changes:**
- Replace `@Environment(\.presentationMode)` with `@EnvironmentObject coordinator: AppCoordinator`
- Replace `presentationMode.wrappedValue.dismiss()` with `coordinator.goBack()`

**Estimated effort:** 30 minutes

#### 2.5 Update FullScreenPlayerView.swift
**Changes:**
- Similar to VideoStreamListView
- Receive ViewModel as parameter
- Update presentation dismissal

**Estimated effort:** 30 minutes

**Total Phase 2 effort:** 4-5 hours

---

### Phase 3: Cleanup & Testing (Day 3)

**Goals:**
- Remove dead code
- Update tests
- Verify navigation flow
- Document patterns

**Files to Delete:**

| File | Reason |
|------|--------|
| Nothing yet | (Keep DIContainer refactored, keep AppCoordinator functional) |

**Files to Update:**

1. **Test Files**
   - Update PlaybackViewModelTests to mock DIContainer
   - Update StreamAdminViewModelTests
   - Add AppCoordinatorTests

2. **Documentation**
   - Update ARCHITECTURE.md with Coordinator pattern
   - Add example in REFACTORING_GUIDE.md

**Estimated effort:** 2-3 hours

---

## Breaking Changes & Migration Path

### ⚠️ Breaking Changes

1. **ViewModel Initialization**
   - Old: Views create ViewModels directly
   - New: ViewModels injected from Coordinator
   - Impact: All view tests need updating

2. **Navigation Pattern**
   - Old: NavigationView + NavigationLink
   - New: NavigationStack + state-based routing
   - Impact: Different navigation semantics

3. **Dismissal Pattern**
   - Old: `presentationMode.wrappedValue.dismiss()`
   - New: `coordinator.goBack()`
   - Impact: SettingsView, modal presentations

### Mitigation Strategy

1. **Backward Compatibility:**
   - Keep ViewModels with default initializers during transition
   - Support both patterns initially

2. **Testing:**
   - Write coordinator tests first
   - Test each view in isolation with mock coordinator
   - Integration tests with real coordinator

3. **Rollout:**
   - Phase 1: Core infrastructure
   - Phase 2: One screen at a time (test after each)
   - Phase 3: Cleanup when all screens passing tests

---

## File Summary

### Create (New)

| File | Lines | Purpose |
|------|-------|---------|
| `steam/App/AppRoute.swift` | 10 | Navigation enum |
| `steam/App/AppCoordinator+Factory.swift` | 50 | ViewModel creation (optional split) |

### Modify (Significant Changes)

| File | Current | Changes |
|------|---------|---------|
| `steam/App/AppCoordinator.swift` | 12 | 100+ (complete implementation) |
| `steam/App/steamApp.swift` | 22 | 35 (add NavigationStack + environment) |
| `steam/Features/Home/Presentation/HomeView.swift` | 184 | 150 (remove NavigationView/Link, add coordinator) |
| `steam/Features/Playback/Presentation/VideoStreamListView.swift` | 542 | 520 (inject ViewModel, update navigation) |
| `steam/Features/Playback/Presentation/FullScreenPlayerView.swift` | ? | Update to receive ViewModel |
| `steam/Features/StreamAdmin/Presentation/StreamAdminView.swift` | 100+ | 80 (inject ViewModel, remove NavigationView) |
| `steam/Features/Settings/Presentation/SettingsView.swift` | 100+ | 90 (use coordinator for dismissal) |
| `steam/Core/DI/DIContainer.swift` | 68 | 50 (remove singleton, add factory methods) |

### Modify (Minor Updates)

| File | Changes |
|------|---------|
| `steam/Features/Playback/Presentation/VideoPlayerView.swift` | Receive ViewModel as parameter (already designed for this) |
| Various test files | Update mocking to support new DI pattern |

**Total files affected:** ~15 files (actual changes)

---

## Testing Strategy

### Unit Tests

**AppCoordinatorTests** (new)
```swift
func testNavigationStateUpdates() // navigate() updates path
func testViewModelCreation() // factory methods work
func testGoBack() // path removal works
```

**UpdatedViewModelTests**
```swift
// Each ViewModel test should:
- Mock DIContainer
- Verify ViewModel behavior independently
- Not care how it's created
```

### Integration Tests

**NavigationFlowTests** (new)
```swift
func testHomeToWatchStreams() // HomeView → VideoStreamListView
func testHomeToStreamAdmin() // HomeView → StreamAdminView
func testHomeToSettings() // HomeView → SettingsView
func testSettingsGoBack() // Settings → back to previous screen
```

**ViewControllerTests**
```swift
// For each screen:
- View receives correct ViewModel
- Navigation actions trigger coordinator
- Display state updates correctly
```

### Manual Testing Checklist

- [ ] App launches to HomeView
- [ ] Tap "Watch Streams" → navigates to VideoStreamListView
- [ ] Tap stream in list → plays
- [ ] Tap "Stream Admin" → navigates correctly
- [ ] Tap "Settings" → navigates correctly
- [ ] Settings back button → returns to HomeView
- [ ] FullScreen player → dismiss works
- [ ] Add Stream sheet → dismiss works
- [ ] Deep linking works (when implemented)

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|-----------|
| **Large refactor scope** | Bugs in navigation, breaking changes | Phase implementation, test after each phase |
| **View tester learning curve** | Slower development during transition | Document patterns in ARCHITECTURE.md |
| **Missing edge cases** | Crashes in runtime | Comprehensive integration tests |
| **Performance regression** | Slower navigation | Profile NavigationStack vs old API (unlikely) |
| **Deep linking broken** | Users can't open links to specific screens | Implement after basic navigation working |

---

## Success Criteria

- ✅ Issue #33: DIContainer refactored (still used, just not singleton)
- ✅ Issue #35: AppCoordinator complete and integrated
- ✅ No deprecated NavigationView/NavigationLink warnings
- ✅ All navigation centralized in AppCoordinator
- ✅ All ViewModels created via coordinator
- ✅ All tests passing
- ✅ Navigation flow works for all screens
- ✅ Settings back button works
- ✅ FullScreen player dismiss works
- ✅ Add Stream sheet dismiss works

---

## Estimated Timeline

| Phase | Tasks | Estimated Time | Dependencies |
|-------|-------|-----------------|---|
| Phase 1 | Coordinator + Route + DIContainer refactor | 2-3 hours | None |
| Phase 2 | Update 5 main views | 4-5 hours | Phase 1 |
| Phase 3 | Tests + Documentation | 2-3 hours | Phase 1-2 |
| **Total** | | **8-11 hours** | **1-2 days** |

**Recommended approach:** Start with Phase 1, fully test it, then move to Phase 2 screen by screen.

---

## Implementation Sequence (Detailed)

### Session 1: Phase 1 Foundation

1. Create `AppRoute.swift`
   - Define enum with all routes
   - Make Hashable for NavigationStack

2. Refactor `AppCoordinator.swift`
   - Add @Published navigationPath
   - Add factory methods (delegate to DIContainer)
   - Add navigate() method
   - Add goBack() method

3. Update `DIContainer.swift`
   - Remove singleton pattern
   - Simplify to pure factory

4. Update `steamApp.swift`
   - Add NavigationStack
   - Add @EnvironmentObject coordinator
   - Wire navigationDestination

5. Test Phase 1
   - Compile check
   - Create AppCoordinatorTests
   - Verify navigation path updates

### Session 2: Phase 2 Views - Screen 1

1. Update `HomeView.swift`
   - Remove NavigationView
   - Replace NavigationLink with onTapGesture
   - Test navigation from home

2. Test
   - Manually test "Watch Streams" navigation
   - Verify coordinator receives navigation event
   - Check path updates correctly

### Session 3: Phase 2 Views - Screen 2

1. Update `VideoStreamListView.swift`
   - Accept ViewModel as parameter
   - Test with mock from coordinator
   - Update internal navigation (fullscreen, sheet)

2. Test
   - Stream loads
   - Selection works
   - FullScreen works
   - Sheet dismiss works

### Session 4: Phase 2 Views - Remaining Screens

1. Update `StreamAdminView.swift`
2. Update `SettingsView.swift`
3. Update `FullScreenPlayerView.swift`
4. Test all together

### Session 5: Phase 3 Cleanup

1. Update all tests
2. Verify no warnings
3. Document new pattern
4. Clean up dead code

---

## Code Examples

### Example 1: Updated HomeView

```swift
struct HomeView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    
    var body: some View {
        VStack(spacing: 0) {
            // Header...
            
            ScrollView {
                VStack(spacing: 12) {
                    MenuCardView(
                        title: "Watch Streams",
                        subtitle: "Browse and play live streams",
                        icon: "play.circle.fill",
                        iconColor: .blue
                    )
                    .onTapGesture {
                        coordinator.navigate(to: .watchStreams)
                    }
                    
                    MenuCardView(
                        title: "Stream Admin",
                        subtitle: "Monitor live streams & viewers",
                        icon: "chart.bar.fill",
                        iconColor: .purple
                    )
                    .onTapGesture {
                        coordinator.navigate(to: .streamAdmin)
                    }
                    
                    MenuCardView(
                        title: "Settings",
                        subtitle: "Configure your preferences",
                        icon: "gearshape.fill",
                        iconColor: .gray
                    )
                    .onTapGesture {
                        coordinator.navigate(to: .settings)
                    }
                }
            }
            // Footer...
        }
    }
}
```

### Example 2: AppCoordinator

```swift
class AppCoordinator: ObservableObject {
    @Published var navigationPath: [AppRoute] = []
    private let diContainer: DIContainer
    
    init(diContainer: DIContainer = DIContainer()) {
        self.diContainer = diContainer
    }
    
    func navigate(to route: AppRoute) {
        navigationPath.append(route)
    }
    
    func goBack() {
        if !navigationPath.isEmpty {
            navigationPath.removeLast()
        }
    }
    
    // MARK: - ViewModel Factories
    
    func makePlaybackViewModel() -> PlaybackViewModel {
        diContainer.makePlaybackViewModel()
    }
    
    func makeStreamAdminViewModel() -> StreamAdminViewModel {
        diContainer.makeStreamAdminViewModel()
    }
    
    // MARK: - Navigation View Builder
    
    @ViewBuilder
    func navigationView(for route: AppRoute) -> some View {
        switch route {
        case .watchStreams:
            VideoStreamListView(
                viewModel: makePlaybackViewModel()
            )
        case .streamAdmin:
            StreamAdminView(
                viewModel: makeStreamAdminViewModel()
            )
        case .settings:
            SettingsView()
        }
    }
}
```

### Example 3: Updated steamApp.swift

```swift
@main
struct steamApp: App {
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var coordinator = AppCoordinator()
    
    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $coordinator.navigationPath) {
                HomeView()
                    .navigationDestination(for: AppRoute.self) { route in
                        coordinator.navigationView(for: route)
                    }
            }
            .environmentObject(coordinator)
            .environmentObject(themeManager)
        }
    }
}
```

---

## Related Documentation

- [[phase-9-clean-view-layer]] - Current phase work
- [[phase-7-structured-concurrency]] - StateActor pattern (still used)
- [[phase-4-retry-orchestrator-complete]] - Dependency infrastructure
