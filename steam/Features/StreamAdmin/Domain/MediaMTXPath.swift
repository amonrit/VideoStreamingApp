//
//  MediaMTXPath.swift
//  steam
//

import Foundation

/// Response model for MediaMTX `GET /v3/paths/get/{name}` endpoint
public struct MediaMTXPath: Codable, Sendable {
    public let name: String
    public let confName: String?
    public let available: Bool?
    public let online: Bool?
    public let source: MediaMTXSource?
    public let readers: [MediaMTXReader]
    public let inboundBytes: Int?
    public let outboundBytes: Int?

    enum CodingKeys: String, CodingKey {
        case name
        case confName
        case available
        case online
        case source
        case readers
        case inboundBytes
        case outboundBytes
    }

    /// Visible viewer count — excludes MediaMTX's internal "hidden" reader type
    public var viewerCount: Int {
        readers.filter { $0.type != "hidden" }.count
    }

    /// Group readers by protocol type for display
    public var readersByType: [String: Int] {
        var grouped: [String: Int] = [:]
        for reader in readers {
            guard reader.type != "hidden" else { continue }
            grouped[reader.type, default: 0] += 1
        }
        return grouped
    }

    /// Human-readable status
    public var status: String {
        if online == true {
            return "🟢 Online"
        } else if available == true {
            return "🟡 Available"
        } else {
            return "⚫ Offline"
        }
    }
}

public struct MediaMTXSource: Codable, Sendable {
    public let type: String
    public let id: String
}

public struct MediaMTXReader: Codable, Sendable {
    public let type: String  // hlsSession, rtmpConn, rtspConn, webRTCSession, srtConn, moqSession, hidden, etc.
    public let id: String
}

/// Response model for MediaMTX `GET /v3/paths/list` endpoint
public struct MediaMTXPathList: Codable, Sendable {
    public let itemCount: Int
    public let pageCount: Int
    public let items: [MediaMTXPath]

    enum CodingKeys: String, CodingKey {
        case itemCount
        case pageCount
        case items
    }
}
