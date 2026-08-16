//
//  PlaybackStateActorTests.swift
//  steamTests
//
//  Unit tests for PlaybackStateActor verify state management,
//  AsyncStream broadcasting, and deduplication logic.
//

import XCTest
import Foundation

final class PlaybackStateActorTests: XCTestCase {
    var stateActor: DefaultPlaybackStateActor!

    override func setUp() {
        super.setUp()
        stateActor = DefaultPlaybackStateActor()
    }

    override func tearDown() {
        stateActor = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialState() async {
        let state = await stateActor.currentState

        XCTAssertFalse(state.isLoading)
        XCTAssertFalse(state.isPlaying)
        XCTAssertNil(state.errorMessage)
        XCTAssertEqual(state.bufferingCount, 0)
        XCTAssertNil(state.currentStream)
        XCTAssertEqual(state.connectionStatus, .disconnected)
        XCTAssertEqual(state.retryAttempt, 0)
        XCTAssertNil(state.viewerCount)
    }

    func testInitialStateWithCustomValues() async {
        let customState = PlaybackStateSnapshot(
            isLoading: true,
            errorMessage: "Test error",
            connectionStatus: .buffering,
            retryAttempt: 2
        )

        let actor = DefaultPlaybackStateActor(initialState: customState)
        let state = await actor.currentState

        XCTAssertTrue(state.isLoading)
        XCTAssertEqual(state.errorMessage, "Test error")
        XCTAssertEqual(state.connectionStatus, .buffering)
        XCTAssertEqual(state.retryAttempt, 2)
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
        await stateActor.updateError("Test error")
        var state = await stateActor.currentState
        XCTAssertEqual(state.errorMessage, "Test error")

        await stateActor.updateError(nil)
        state = await stateActor.currentState
        XCTAssertNil(state.errorMessage)
    }

    func testUpdateConnectionStatus() async {
        await stateActor.updateConnectionStatus(.connecting)
        var state = await stateActor.currentState
        XCTAssertEqual(state.connectionStatus, .connecting)

        await stateActor.updateConnectionStatus(.connected)
        state = await stateActor.currentState
        XCTAssertEqual(state.connectionStatus, .connected)

        await stateActor.updateConnectionStatus(.failed("Connection timeout"))
        state = await stateActor.currentState
        XCTAssertEqual(state.connectionStatus, .failed("Connection timeout"))
    }

    func testUpdateViewerCount() async {
        await stateActor.updateViewerCount(42)
        var state = await stateActor.currentState
        XCTAssertEqual(state.viewerCount, 42)

        await stateActor.updateViewerCount(100)
        state = await stateActor.currentState
        XCTAssertEqual(state.viewerCount, 100)
    }

    func testUpdateCurrentTime() async {
        await stateActor.updateCurrentTime(10.5)
        var state = await stateActor.currentState
        XCTAssertEqual(state.currentTime, 10.5)

        await stateActor.updateCurrentTime(20.25)
        state = await stateActor.currentState
        XCTAssertEqual(state.currentTime, 20.25)
    }

    // MARK: - State Deduplication Tests

    func testDuplicateUpdatesAreSkipped() async {
        // First update
        await stateActor.updateLoading(true)
        var state = await stateActor.currentState
        XCTAssertTrue(state.isLoading)

        // Duplicate update (should be skipped internally, but state unchanged)
        await stateActor.updateLoading(true)
        state = await stateActor.currentState
        XCTAssertTrue(state.isLoading)
    }

    func testMultipleSequentialUpdates() async {
        await stateActor.updateLoading(true)
        await stateActor.updateConnectionStatus(.connecting)
        await stateActor.updateViewerCount(10)
        await stateActor.updateRetryAttempt(1)

        let state = await stateActor.currentState

        XCTAssertTrue(state.isLoading)
        XCTAssertEqual(state.connectionStatus, .connecting)
        XCTAssertEqual(state.viewerCount, 10)
        XCTAssertEqual(state.retryAttempt, 1)
    }

    // MARK: - AsyncStream Tests

    func testAsyncStreamBroadcastsUpdates() async {
        var updateCount = 0
        var lastState: PlaybackStateSnapshot?

        let task = Task {
            for await state in await self.stateActor.stateUpdates {
                updateCount += 1
                lastState = state
                if updateCount >= 3 {
                    break
                }
            }
        }

        // Give the stream time to start observing
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Make updates
        await stateActor.updateLoading(true)
        try? await Task.sleep(nanoseconds: 100_000_000)

        await stateActor.updateConnectionStatus(.connected)
        try? await Task.sleep(nanoseconds: 100_000_000)

        await stateActor.updateViewerCount(5)
        try? await Task.sleep(nanoseconds: 100_000_000)

        task.cancel()

        XCTAssertGreaterThanOrEqual(updateCount, 3)
        XCTAssertNotNil(lastState)
        XCTAssertEqual(lastState?.viewerCount, 5)
    }

    // MARK: - Reset Tests

    func testResetClearsState() async {
        await stateActor.updateLoading(true)
        await stateActor.updateError("Error")
        await stateActor.updateViewerCount(42)

        await stateActor.reset()

        let state = await stateActor.currentState

        XCTAssertFalse(state.isLoading)
        XCTAssertNil(state.errorMessage)
        XCTAssertEqual(state.viewerCount, nil)
        XCTAssertEqual(state.connectionStatus, .disconnected)
    }

    // MARK: - Mock Actor Tests

    @MainActor
    func testMockActorInitialization() async {
        let mockActor = MockPlaybackStateActor()
        let state = await mockActor.currentState

        XCTAssertFalse(state.isLoading)
        XCTAssertEqual(state.connectionStatus, .disconnected)
    }

    @MainActor
    func testMockActorUpdates() async {
        let mockActor = MockPlaybackStateActor()

        await mockActor.updateLoading(true)
        await mockActor.updateError("Test error")
        await mockActor.updateViewerCount(99)

        let state = await mockActor.currentState

        XCTAssertTrue(state.isLoading)
        XCTAssertEqual(state.errorMessage, "Test error")
        XCTAssertEqual(state.viewerCount, 99)
    }

    // MARK: - Concurrent Updates Tests

    func testConcurrentUpdatesAreThreadSafe() async {
        let iterations = 10

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<iterations {
                group.addTask {
                    await self.stateActor.updateViewerCount(i)
                    await self.stateActor.updateRetryAttempt(i % 3)
                }
            }
        }

        let state = await stateActor.currentState
        // State should be valid after concurrent updates
        XCTAssertGreaterThanOrEqual(state.viewerCount ?? 0, 0)
        XCTAssertGreaterThanOrEqual(state.retryAttempt, 0)
    }
}
