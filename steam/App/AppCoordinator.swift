import SwiftUI

/// Owns app-level navigation state and dependency injection.
///
/// `AppCoordinator` is the single source of truth for the root `NavigationStack`'s
/// path and the sole place that constructs feature ViewModels (via `DIContainer`).
/// Views never create their ViewModels directly — they receive them from the
/// coordinator, either through `navigationView(for:)` or by reading
/// `@Environment(AppCoordinator.self) var coordinator` and calling `navigate(to:)`.
@MainActor
@Observable
final class AppCoordinator {
    /// The root `NavigationStack`'s path. Appending a route pushes a screen;
    /// removing one pops it.
    var navigationPath: [AppRoute] = []

    private let diContainer: DIContainer

    init(diContainer: DIContainer = DIContainer()) {
        self.diContainer = diContainer
    }

    // MARK: - Navigation

    /// Push a new route onto the navigation stack.
    func navigate(to route: AppRoute) {
        navigationPath.append(route)
    }

    /// Pop the top-most route off the navigation stack, if any.
    func goBack() {
        guard !navigationPath.isEmpty else { return }
        navigationPath.removeLast()
    }

    /// Pop back to the root screen.
    func goToRoot() {
        navigationPath.removeAll()
    }

    // MARK: - ViewModel Factories

    func makePlaybackViewModel() -> PlaybackViewModel {
        diContainer.makePlaybackViewModel()
    }

    func makeStreamAdminViewModel() -> StreamAdminViewModel {
        diContainer.makeStreamAdminViewModel()
    }

    // MARK: - Navigation View Builder

    /// Maps a route to its destination view, injecting a freshly created
    /// ViewModel where the destination needs one.
    @ViewBuilder
    func navigationView(for route: AppRoute) -> some View {
        switch route {
        case .watchStreams:
            VideoStreamListView(playbackViewModel: makePlaybackViewModel())
        case .streamAdmin:
            StreamAdminView(viewModel: makeStreamAdminViewModel())
        case .settings:
            SettingsView()
        }
    }
}
