//
//  MediaMTXPath.swift
//  steam
//

import Foundation

/// Response model for MediaMTX `GET /v3/paths/get/{name}` endpoint
struct MediaMTXPath: Codable {
    let name: String
    let confName: String?
    let available: Bool?
    let online: Bool?
    let source: MediaMTXSource?
    let readers: [MediaMTXReader]
    let inboundBytes: Int?
    let outboundBytes: Int?

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
    var viewerCount: Int {
        readers.filter { $0.type != "hidden" }.count
    }

    /// Group readers by protocol type for display
    var readersByType: [String: Int] {
        var grouped: [String: Int] = [:]
        for reader in readers {
            guard reader.type != "hidden" else { continue }
            grouped[reader.type, default: 0] += 1
        }
        return grouped
    }

    /// Human-readable status
    var status: String {
        if online == true {
            return "🟢 Online"
        } else if available == true {
            return "🟡 Available"
        } else {
            return "⚫ Offline"
        }
    }
}

struct MediaMTXSource: Codable {
    let type: String
    let id: String
}

struct MediaMTXReader: Codable {
    let type: String  // hlsSession, rtmpConn, rtspConn, webRTCSession, srtConn, moqSession, hidden, etc.
    let id: String
}

/// Response model for MediaMTX `GET /v3/paths/list` endpoint
struct MediaMTXPathList: Codable {
    let itemCount: Int
    let pageCount: Int
    let items: [MediaMTXPath]

    enum CodingKeys: String, CodingKey {
        case itemCount
        case pageCount
        case items
    }
}
