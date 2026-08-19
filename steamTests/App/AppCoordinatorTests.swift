import XCTest
@testable import steam

/// Tests for `AppCoordinator`'s navigation state and ViewModel factories.
final class AppCoordinatorTests: XCTestCase {
    var coordinator: AppCoordinator!

    override func setUp() {
        super.setUp()
        coordinator = AppCoordinator()
    }

    override func tearDown() {
        coordinator = nil
        super.tearDown()
    }

    // MARK: - Navigation State

    func testStartsWithEmptyPath() {
        XCTAssertTrue(coordinator.navigationPath.isEmpty)
    }

    func testNavigateAppendsRouteToPath() {
        coordinator.navigate(to: .watchStreams)

        XCTAssertEqual(coordinator.navigationPath, [.watchStreams])
    }

    func testNavigateAppendsMultipleRoutesInOrder() {
        coordinator.navigate(to: .watchStreams)
        coordinator.navigate(to: .streamAdmin)
        coordinator.navigate(to: .settings)

        XCTAssertEqual(coordinator.navigationPath, [.watchStreams, .streamAdmin, .settings])
    }

    func testGoBackRemovesLastRoute() {
        coordinator.navigate(to: .watchStreams)
        coordinator.navigate(to: .settings)

        coordinator.goBack()

        XCTAssertEqual(coordinator.navigationPath, [.watchStreams])
    }

    func testGoBackOnEmptyPathIsNoOp() {
        coordinator.goBack()

        XCTAssertTrue(coordinator.navigationPath.isEmpty)
    }

    func testGoToRootClearsPath() {
        coordinator.navigate(to: .watchStreams)
        coordinator.navigate(to: .streamAdmin)

        coordinator.goToRoot()

        XCTAssertTrue(coordinator.navigationPath.isEmpty)
    }

    // MARK: - ViewModel Factories

    func testMakePlaybackViewModelReturnsNewInstanceEachTime() {
        let first = coordinator.makePlaybackViewModel()
        let second = coordinator.makePlaybackViewModel()

        XCTAssertNotNil(first)
        XCTAssertNotNil(second)
        XCTAssertFalse(first === second)
    }

    func testMakeStreamAdminViewModelReturnsNewInstanceEachTime() {
        let first = coordinator.makeStreamAdminViewModel()
        let second = coordinator.makeStreamAdminViewModel()

        XCTAssertNotNil(first)
        XCTAssertNotNil(second)
        XCTAssertFalse(first === second)
    }
}
