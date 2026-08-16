import Foundation

/// Represents the connection state of a video stream playback.
/// Tracks the lifecycle from disconnected through connecting, connected, buffering, to failed states.
public enum ConnectionStatus: Equatable, Hashable, Sendable {
    /// Not connected to any stream
    case disconnected

    /// Attempting to establish connection
    case connecting

    /// Successfully connected and ready to play
    case connected

    /// Connected but buffering/waiting for data
    case buffering

    /// Connection failed with error message
    case failed(String)

    // MARK: - Computed Properties

    /// Whether the connection is currently active (connected or buffering)
    public var isConnected: Bool {
        switch self {
        case .connected, .buffering:
            return true
        case .disconnected, .connecting, .failed:
            return false
        }
    }

    /// Whether there's an active connection attempt in progress
    public var isActive: Bool {
        switch self {
        case .connecting, .connected, .buffering:
            return true
        case .disconnected, .failed:
            return false
        }
    }

    /// Human-readable display name for the status
    public var displayName: String {
        switch self {
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Connecting..."
        case .connected:
            return "Connected"
        case .buffering:
            return "Buffering..."
        case .failed:
            return "Connection Failed"
        }
    }

    /// Error message if failed, nil otherwise
    public var errorMessage: String? {
        switch self {
        case .failed(let message):
            return message
        default:
            return nil
        }
    }

    /// Whether retry is allowed from this state
    public var canRetry: Bool {
        switch self {
        case .failed, .disconnected:
            return true
        case .connecting, .connected, .buffering:
            return false
        }
    }

    // MARK: - Hashable Conformance

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .disconnected:
            hasher.combine(0)
        case .connecting:
            hasher.combine(1)
        case .connected:
            hasher.combine(2)
        case .buffering:
            hasher.combine(3)
        case .failed(let message):
            hasher.combine(4)
            hasher.combine(message)
        }
    }

    // MARK: - Equatable Conformance

    public static func == (lhs: ConnectionStatus, rhs: ConnectionStatus) -> Bool {
        switch (lhs, rhs) {
        case (.disconnected, .disconnected):
            return true
        case (.connecting, .connecting):
            return true
        case (.connected, .connected):
            return true
        case (.buffering, .buffering):
            return true
        case (.failed(let lhsMessage), .failed(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
}

// MARK: - CustomStringConvertible

extension ConnectionStatus: CustomStringConvertible {
    public var description: String {
        switch self {
        case .disconnected:
            return "ConnectionStatus.disconnected"
        case .connecting:
            return "ConnectionStatus.connecting"
        case .connected:
            return "ConnectionStatus.connected"
        case .buffering:
            return "ConnectionStatus.buffering"
        case .failed(let message):
            return "ConnectionStatus.failed(\"\(message)\")"
        }
    }
}
