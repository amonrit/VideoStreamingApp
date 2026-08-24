Last Modified: 08/24/2026 (1787587709) by amonrit

# ADR-004: Coordinator Pattern for Navigation & Dependency Injection

## Status

✅ **ACCEPTED** (implemented, resolving issues #33 and #35)

## Context

Early in the project, navigation used `NavigationLink` directly inside `HomeView`, and each destination view constructed its own ViewModel in a property initializer (e.g. `@StateObject private var viewModel = PlaybackViewModel()`). A `DIContainer` and a template `AppCoordinator` existed in the tree but were never wired up — `DIContainer` had no callers, and `AppCoordinator` had no routing logic.

Problems with the direct-construction approach:
- **No dependency injection** — Views hard-coded which `APIClientProvider`/dependencies their ViewModel used, making substitution for tests or previews awkward.
- **Scattered navigation state** — Each screen decided its own navigation, with no single source of truth for "where am I in the app".
- **Deprecated APIs crept in** — `NavigationView` and `NavigationLink(destination:)` are legacy patterns superseded by `NavigationStack` + `navigationDestination`.
- **Dead code** — `DIContainer` (~70 lines) existed but nothing called it, which is confusing for anyone reading the codebase.

## Decision

Adopt a lightweight, SwiftUI-native Coordinator:

1. **`AppCoordinator`** (`@MainActor @Observable`) owns the root `NavigationStack`'s path (`[AppRoute]`) and is the only place that builds feature ViewModels, via a `DIContainer` it holds privately.
2. **`AppRoute`** is a `Hashable` enum listing every reachable destination (`watchStreams`, `streamAdmin`, `settings`).
3. **`DIContainer`** is a plain factory (not observable — nothing observes it) that constructs ViewModels with their dependencies. It's owned by `AppCoordinator`, not accessed as a singleton, so a test can swap in a container built from mocks.
4. Views never construct their own ViewModels. They either receive one from `AppCoordinator.navigationView(for:)`, or read `@Environment(AppCoordinator.self)` and call `coordinator.navigate(to:)` to push a new route.
5. `steamApp` owns one `@State private var coordinator = AppCoordinator()`, binds `NavigationStack(path: $coordinator.navigationPath)`, and injects the coordinator via `.environment(coordinator)`.

This is deliberately **not** the traditional UIKit Coordinator (delegate-based, coordinator-per-flow). SwiftUI's declarative navigation doesn't need that machinery — one coordinator with an enum-based route list is enough for this app's navigation depth.

## Implementation

```swift
@MainActor
@Observable
final class AppCoordinator {
    var navigationPath: [AppRoute] = []
    private let diContainer: DIContainer

    init(diContainer: DIContainer = DIContainer()) {
        self.diContainer = diContainer
    }

    func navigate(to route: AppRoute) { navigationPath.append(route) }
    func goBack() { if !navigationPath.isEmpty { navigationPath.removeLast() } }
    func goToRoot() { navigationPath.removeAll() }

    func makePlaybackViewModel() -> PlaybackViewModel { diContainer.makePlaybackViewModel() }
    func makeStreamAdminViewModel() -> StreamAdminViewModel { diContainer.makeStreamAdminViewModel() }

    @ViewBuilder
    func navigationView(for route: AppRoute) -> some View {
        switch route {
        case .watchStreams: VideoStreamListView(playbackViewModel: makePlaybackViewModel())
        case .streamAdmin: StreamAdminView(viewModel: makeStreamAdminViewModel())
        case .settings: SettingsView()
        }
    }
}
```

```swift
@main
struct steamApp: App {
    @State private var coordinator = AppCoordinator()
    @State private var themeManager = ThemeManager()

    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $coordinator.navigationPath) {
                HomeView()
                    .navigationDestination(for: AppRoute.self) { route in
                        coordinator.navigationView(for: route)
                    }
            }
            .environment(coordinator)
            .environment(themeManager)
        }
    }
}
```

```swift
struct HomeView: View {
    @Environment(AppCoordinator.self) var coordinator

    var body: some View {
        MenuCardView(title: "Watch Streams", ...)
            .onTapGesture { coordinator.navigate(to: .watchStreams) }
    }
}
```

Note this uses `@Observable` + `@Environment`/`.environment(...)`, not `@StateObject`/`@EnvironmentObject` — see the note on ADR-001 about the project-wide move off Combine's `ObservableObject`.

## Consequences

### ✅ Advantages

- **Single source of truth for navigation** — `AppCoordinator.navigationPath` is the only place that knows "where am I".
- **Real dependency injection** — `DIContainer` now has exactly one caller (`AppCoordinator`), and tests can construct an `AppCoordinator` with a container built from mocks instead of a live `AVPlayer`/`APIClientProvider`.
- **No dead code** — `DIContainer` is load-bearing again.
- **Modern navigation APIs** — `NavigationStack` + `navigationDestination(for:)` replace the deprecated `NavigationLink(destination:)`.
- **Views stay pure presentation** — a view either takes its ViewModel as an init parameter or reads the coordinator to navigate; it never decides how a ViewModel gets built.

### ⚠️ Trade-offs

- **One more type to learn** — new contributors need to know that ViewModel construction goes through `AppCoordinator`/`DIContainer`, not `View.init`.
- **Coordinator can grow into a god object** — as more routes and features are added, watch for `navigationView(for:)` becoming a large switch; if it does, consider splitting per-feature coordinators that `AppCoordinator` composes.
- **Deep-linking isn't solved yet** — `[AppRoute]` supports push/pop but nothing yet decodes a URL or a push notification into a route array.

## Alternatives Considered

1. **Keep direct construction in Views** — status quo; rejected because it's what created issues #33/#35.
2. **Traditional UIKit-style Coordinator protocol with `start()`/child coordinators** — more powerful for deep, branching flows, but heavier than this app's navigation currently needs.
3. **Router/TCA-style single global state tree** — would also centralize navigation, but requires adopting a much larger architectural framework for a benefit (undo/replay, exhaustive testing) this app doesn't currently need.

**Why the lightweight Coordinator won:** it fixes the two concrete problems (dead `DIContainer`, incomplete `AppCoordinator`) with the smallest addition that still gives every view a single, testable path to its dependencies.

## Related Decisions

- **ADR-001:** Structured Concurrency / `@Observable` (the coordinator itself is `@Observable`, not `ObservableObject`)
- **ADR-003:** Dependency Injection via `APIClientProvider` (`DIContainer` composes `APIClientProvider`-based ViewModels)

## Implementation Checklist

- [x] `AppRoute` enum covering all reachable screens
- [x] `AppCoordinator` with navigation + ViewModel factory methods
- [x] `DIContainer` wired as `AppCoordinator`'s only caller
- [x] `steamApp` bound to `coordinator.navigationPath`
- [x] `HomeView` navigates via `coordinator.navigate(to:)` instead of `NavigationLink`
- [ ] Deep-linking (URL/push notification → `AppRoute`)
- [ ] Per-feature coordinators if `navigationView(for:)` grows unwieldy

---

**Follows:** Issues #33, #35
**Supersedes:** Direct ViewModel construction in Views; the unused `DIContainer`/template `AppCoordinator` pair
**Last Reviewed:** 08/24/2026
