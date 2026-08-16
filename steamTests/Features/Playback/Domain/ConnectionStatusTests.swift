import XCTest
@testable import steam

final class ConnectionStatusTests: XCTestCase {
    // MARK: - isConnected Property Tests

    func testIsConnected_connectedState() {
        XCTAssertTrue(ConnectionStatus.connected.isConnected)
    }

    func testIsConnected_bufferingState() {
        XCTAssertTrue(ConnectionStatus.buffering.isConnected)
    }

    func testIsConnected_disconnectedState() {
        XCTAssertFalse(ConnectionStatus.disconnected.isConnected)
    }

    func testIsConnected_connectingState() {
        XCTAssertFalse(ConnectionStatus.connecting.isConnected)
    }

    func testIsConnected_failedState() {
        XCTAssertFalse(ConnectionStatus.failed("Error").isConnected)
    }

    // MARK: - isActive Property Tests

    func testIsActive_connectingState() {
        XCTAssertTrue(ConnectionStatus.connecting.isActive)
    }

    func testIsActive_connectedState() {
        XCTAssertTrue(ConnectionStatus.connected.isActive)
    }

    func testIsActive_bufferingState() {
        XCTAssertTrue(ConnectionStatus.buffering.isActive)
    }

    func testIsActive_disconnectedState() {
        XCTAssertFalse(ConnectionStatus.disconnected.isActive)
    }

    func testIsActive_failedState() {
        XCTAssertFalse(ConnectionStatus.failed("Error").isActive)
    }

    // MARK: - displayName Property Tests

    func testDisplayName_disconnected() {
        XCTAssertEqual(ConnectionStatus.disconnected.displayName, "Disconnected")
    }

    func testDisplayName_connecting() {
        XCTAssertEqual(ConnectionStatus.connecting.displayName, "Connecting...")
    }

    func testDisplayName_connected() {
        XCTAssertEqual(ConnectionStatus.connected.displayName, "Connected")
    }

    func testDisplayName_buffering() {
        XCTAssertEqual(ConnectionStatus.buffering.displayName, "Buffering...")
    }

    func testDisplayName_failed() {
        XCTAssertEqual(ConnectionStatus.failed("Network error").displayName, "Connection Failed")
    }

    func testDisplayName_nonEmpty() {
        // All display names should be non-empty
        let statuses: [ConnectionStatus] = [
            .disconnected,
            .connecting,
            .connected,
            .buffering,
            .failed("Error")
        ]

        for status in statuses {
            XCTAssertFalse(status.displayName.isEmpty)
        }
    }

    // MARK: - errorMessage Property Tests

    func testErrorMessage_failedState() {
        let error = "Network timeout"
        XCTAssertEqual(ConnectionStatus.failed(error).errorMessage, error)
    }

    func testErrorMessage_nonFailedStates() {
        XCTAssertNil(ConnectionStatus.disconnected.errorMessage)
        XCTAssertNil(ConnectionStatus.connecting.errorMessage)
        XCTAssertNil(ConnectionStatus.connected.errorMessage)
        XCTAssertNil(ConnectionStatus.buffering.errorMessage)
    }

    // MARK: - canRetry Property Tests

    func testCanRetry_failedState() {
        XCTAssertTrue(ConnectionStatus.failed("Error").canRetry)
    }

    func testCanRetry_disconnectedState() {
        XCTAssertTrue(ConnectionStatus.disconnected.canRetry)
    }

    func testCanRetry_connectingState() {
        XCTAssertFalse(ConnectionStatus.connecting.canRetry)
    }

    func testCanRetry_connectedState() {
        XCTAssertFalse(ConnectionStatus.connected.canRetry)
    }

    func testCanRetry_bufferingState() {
        XCTAssertFalse(ConnectionStatus.buffering.canRetry)
    }

    // MARK: - Equatable Tests

    func testEquatable_sameStatesEqual() {
        XCTAssertEqual(ConnectionStatus.disconnected, ConnectionStatus.disconnected)
        XCTAssertEqual(ConnectionStatus.connecting, ConnectionStatus.connecting)
        XCTAssertEqual(ConnectionStatus.connected, ConnectionStatus.connected)
        XCTAssertEqual(ConnectionStatus.buffering, ConnectionStatus.buffering)
    }

    func testEquatable_failedStatesEqual() {
        let error = "Network error"
        XCTAssertEqual(
            ConnectionStatus.failed(error),
            ConnectionStatus.failed(error)
        )
    }

    func testEquatable_failedStatesDifferentMessages() {
        XCTAssertNotEqual(
            ConnectionStatus.failed("Error 1"),
            ConnectionStatus.failed("Error 2")
        )
    }

    func testEquatable_differentStatesNotEqual() {
        XCTAssertNotEqual(ConnectionStatus.disconnected, ConnectionStatus.connecting)
        XCTAssertNotEqual(ConnectionStatus.connected, ConnectionStatus.buffering)
        XCTAssertNotEqual(ConnectionStatus.connecting, ConnectionStatus.failed("Error"))
    }

    // MARK: - Hashable Tests

    func testHashable_sameStatesHaveSameHash() {
        let status1 = ConnectionStatus.disconnected
        let status2 = ConnectionStatus.disconnected

        XCTAssertEqual(status1.hashValue, status2.hashValue)
    }

    func testHashable_usableInSet() {
        let status1 = ConnectionStatus.disconnected
        let status2 = ConnectionStatus.disconnected
        let status3 = ConnectionStatus.connecting

        let set = Set([status1, status2, status3])
        XCTAssertEqual(set.count, 2)
    }

    func testHashable_usableInDict() {
        let dict: [ConnectionStatus: String] = [
            .disconnected: "Not connected",
            .connecting: "Connecting...",
            .connected: "Connected"
        ]

        XCTAssertEqual(dict[.disconnected], "Not connected")
        XCTAssertEqual(dict[.connecting], "Connecting...")
    }

    // MARK: - Sendable Tests

    func testSendable_conformance() {
        // This is compile-time verification
        let status: ConnectionStatus = .connected
        let _: any Sendable = status
    }

    // MARK: - Description Tests

    func testDescription_disconnected() {
        XCTAssertEqual(
            ConnectionStatus.disconnected.description,
            "ConnectionStatus.disconnected"
        )
    }

    func testDescription_connecting() {
        XCTAssertEqual(
            ConnectionStatus.connecting.description,
            "ConnectionStatus.connecting"
        )
    }

    func testDescription_connected() {
        XCTAssertEqual(
            ConnectionStatus.connected.description,
            "ConnectionStatus.connected"
        )
    }

    func testDescription_buffering() {
        XCTAssertEqual(
            ConnectionStatus.buffering.description,
            "ConnectionStatus.buffering"
        )
    }

    func testDescription_failed() {
        let error = "Network timeout"
        XCTAssertEqual(
            ConnectionStatus.failed(error).description,
            "ConnectionStatus.failed(\"Network timeout\")"
        )
    }

    // MARK: - State Transition Tests

    func testStateTransition_disconnectedToConnecting() {
        let initial = ConnectionStatus.disconnected
        XCTAssertFalse(initial.isActive)

        let next = ConnectionStatus.connecting
        XCTAssertTrue(next.isActive)
        XCTAssertFalse(next.isConnected)
    }

    func testStateTransition_connectingToConnected() {
        let connecting = ConnectionStatus.connecting
        let connected = ConnectionStatus.connected

        XCTAssertTrue(connecting.isActive)
        XCTAssertFalse(connecting.isConnected)

        XCTAssertTrue(connected.isActive)
        XCTAssertTrue(connected.isConnected)
    }

    func testStateTransition_connectedToBuffering() {
        let connected = ConnectionStatus.connected
        let buffering = ConnectionStatus.buffering

        XCTAssertTrue(connected.isConnected)
        XCTAssertTrue(buffering.isConnected)

        XCTAssertFalse(connected.canRetry)
        XCTAssertFalse(buffering.canRetry)
    }

    func testStateTransition_connectedToFailed() {
        let connected = ConnectionStatus.connected
        let failed = ConnectionStatus.failed("Stream ended")

        XCTAssertTrue(connected.isActive)
        XCTAssertFalse(failed.isActive)

        XCTAssertFalse(connected.canRetry)
        XCTAssertTrue(failed.canRetry)
    }
}
