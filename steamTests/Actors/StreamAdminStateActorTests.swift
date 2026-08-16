//
//  StreamAdminStateActorTests.swift
//  steamTests
//
//  Unit tests for StreamAdminStateActor verify state management,
//  AsyncStream broadcasting, and admin-specific state handling.
//

import XCTest
import Foundation

final class StreamAdminStateActorTests: XCTestCase {
    var stateActor: DefaultStreamAdminStateActor!

    override func setUp() {
        super.setUp()
        stateActor = DefaultStreamAdminStateActor()
    }

    override func tearDown() {
        stateActor = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialState() async {
        let state = await stateActor.currentState

        XCTAssertFalse(state.isLoading)
        XCTAssertNil(state.errorMessage)
        XCTAssertTrue(state.paths.isEmpty)
        XCTAssertNil(state.selectedPath)
        XCTAssertNil(state.baseURL)
        XCTAssertFalse(state.isOnline)
        XCTAssertEqual(state.totalViewers, 0)
    }

    func testInitialStateWithCustomValues() async {
        let testURL = URL(string: "http://localhost:9997")!
        let customState = StreamAdminStateSnapshot(
            isLoading: true,
            errorMessage: "Test error",
            baseURL: testURL,
            isOnline: true,
            totalViewers: 5
        )

        let actor = DefaultStreamAdminStateActor(initialState: customState)
        let state = await actor.currentState

        XCTAssertTrue(state.isLoading)
        XCTAssertEqual(state.errorMessage, "Test error")
        XCTAssertEqual(state.baseURL, testURL)
        XCTAssertTrue(state.isOnline)
        XCTAssertEqual(state.totalViewers, 5)
    }

    // MARK: - State Update Tests

    func testUpdateLoading() async {
        await stateActor.updateLoading(true)
        var state = await stateActor.currentState
        XCTAssertTrue(state.isLoading)

        await stateActor.updateLoading(false)
        state = await stateActor.currentState
        XCTAssertFalse(state.isLoading)
    }

    func testUpdateError() async {
        await stateActor.updateError("Connection failed")
        var state = await stateActor.currentState
        XCTAssertEqual(state.errorMessage, "Connection failed")

        await stateActor.updateError(nil)
        state = await stateActor.currentState
        XCTAssertNil(state.errorMessage)
    }

    func testUpdateBaseURL() async {
        let testURL = URL(string: "http://localhost:9997")!
        await stateActor.updateBaseURL(testURL)
        var state = await stateActor.currentState
        XCTAssertEqual(state.baseURL, testURL)

        await stateActor.updateBaseURL(nil)
        state = await stateActor.currentState
        XCTAssertNil(state.baseURL)
    }

    func testUpdateOnline() async {
        await stateActor.updateOnline(true)
        var state = await stateActor.currentState
        XCTAssertTrue(state.isOnline)

        await stateActor.updateOnline(false)
        state = await stateActor.currentState
        XCTAssertFalse(state.isOnline)
    }

    func testUpdateTotalViewers() async {
        await stateActor.updateTotalViewers(50)
        var state = await stateActor.currentState
        XCTAssertEqual(state.totalViewers, 50)

        await stateActor.updateTotalViewers(100)
        state = await stateActor.currentState
        XCTAssertEqual(state.totalViewers, 100)
    }

    // MARK: - Paths Management Tests

    func testUpdatePaths() async {
        let testPaths = createTestPaths(count: 3)

        await stateActor.updatePaths(testPaths)
        let state = await stateActor.currentState

        XCTAssertEqual(state.paths.count, 3)
        XCTAssertEqual(state.totalViewers, testPaths.reduce(0) { $0 + $1.viewerCount })
    }

    func testUpdatePathsAutoCalculatesTotalViewers() async {
        let testPaths = createTestPaths(count: 2, viewersPerPath: 10)

        await stateActor.updatePaths(testPaths)
        let state = await stateActor.currentState

        XCTAssertEqual(state.totalViewers, 20)
    }

    func testUpdateSelectedPath() async {
        let testPath = createTestPath(name: "test-stream", viewers: 5)

        await stateActor.updateSelectedPath(testPath)
        var state = await stateActor.currentState
        XCTAssertEqual(state.selectedPath?.name, "test-stream")

        await stateActor.updateSelectedPath(nil)
        state = await stateActor.currentState
        XCTAssertNil(state.selectedPath)
    }

    // MARK: - Timestamp Tests

    func testUpdateLastUpdateTime() async {
        let now = Date()
        await stateActor.updateLastUpdateTime(now)
        let state = await stateActor.currentState

        XCTAssertEqual(state.lastUpdateTime, now)
    }

    // MARK: - State Deduplication Tests

    func testDuplicateLoadingUpdatesAreSkipped() async {
        await stateActor.updateLoading(true)
        var state = await stateActor.currentState
        XCTAssertTrue(state.isLoading)

        await stateActor.updateLoading(true)
        state = await stateActor.currentState
        XCTAssertTrue(state.isLoading)
    }

    func testDuplicatePathsUpdateAreSkipped() async {
        let testPaths = createTestPaths(count: 2)

        await stateActor.updatePaths(testPaths)
        var state = await stateActor.currentState
        XCTAssertEqual(state.paths.count, 2)

        await stateActor.updatePaths(testPaths)
        state = await stateActor.currentState
        XCTAssertEqual(state.paths.count, 2)
    }

    // MARK: - Multiple Updates Tests

    func testMultipleSequentialUpdates() async {
        let testURL = URL(string: "http://localhost:9997")!
        let testPaths = createTestPaths(count: 2)

        await stateActor.updateLoading(true)
        await stateActor.updateBaseURL(testURL)
        await stateActor.updateOnline(true)
        await stateActor.updatePaths(testPaths)

        let state = await stateActor.currentState

        XCTAssertTrue(state.isLoading)
        XCTAssertEqual(state.baseURL, testURL)
        XCTAssertTrue(state.isOnline)
        XCTAssertEqual(state.paths.count, 2)
    }

    // MARK: - AsyncStream Tests

    func testAsyncStreamBroadcasts() async {
        var updateCount = 0
        var lastState: StreamAdminStateSnapshot?

        let task = Task {
            for await state in await self.stateActor.stateUpdates {
                updateCount += 1
                lastState = state
                if updateCount >= 2 {
                    break
                }
            }
        }

        try? await Task.sleep(nanoseconds: 100_000_000)

        let testPaths = createTestPaths(count: 1)
        await stateActor.updatePaths(testPaths)

        try? await Task.sleep(nanoseconds: 100_000_000)

        task.cancel()

        XCTAssertGreaterThanOrEqual(updateCount, 1)
        XCTAssertNotNil(lastState)
    }

    // MARK: - Reset Tests

    func testResetClearsState() async {
        let testURL = URL(string: "http://localhost:9997")!
        let testPaths = createTestPaths(count: 2)

        await stateActor.updateLoading(true)
        await stateActor.updateBaseURL(testURL)
        await stateActor.updatePaths(testPaths)
        await stateActor.updateOnline(true)

        await stateActor.reset()

        let state = await stateActor.currentState

        XCTAssertFalse(state.isLoading)
        XCTAssertNil(state.baseURL)
        XCTAssertTrue(state.paths.isEmpty)
        XCTAssertFalse(state.isOnline)
    }

    // MARK: - Mock Actor Tests

    @MainActor
    func testMockActorInitialization() async {
        let mockActor = MockStreamAdminStateActor()
        let state = await mockActor.currentState

        XCTAssertFalse(state.isLoading)
        XCTAssertTrue(state.paths.isEmpty)
    }

    @MainActor
    func testMockActorUpdates() async {
        let mockActor = MockStreamAdminStateActor()
        let testPaths = createTestPaths(count: 2)

        await mockActor.updateLoading(true)
        await mockActor.updatePaths(testPaths)
        await mockActor.updateOnline(true)

        let state = await mockActor.currentState

        XCTAssertTrue(state.isLoading)
        XCTAssertEqual(state.paths.count, 2)
        XCTAssertTrue(state.isOnline)
    }

    // MARK: - Helper Methods

    private func createTestPath(name: String, viewers: Int) -> MediaMTXPath {
        var readers: [MediaMTXReader] = []
        for i in 0..<viewers {
            readers.append(MediaMTXReader(type: "hls", id: "reader-\(i)"))
        }

        return MediaMTXPath(
            name: name,
            confName: "test-conf",
            available: true,
            online: true,
            source: nil,
            readers: readers,
            inboundBytes: nil,
            outboundBytes: nil
        )
    }

    private func createTestPaths(count: Int, viewersPerPath: Int = 0) -> [MediaMTXPath] {
        var paths: [MediaMTXPath] = []
        for i in 0..<count {
            paths.append(createTestPath(name: "stream-\(i)", viewers: viewersPerPath))
        }
        return paths
    }
}
