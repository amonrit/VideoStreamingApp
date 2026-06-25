//
//  VideoStream.swift
//  steam
//

import Foundation

struct VideoStream: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let urlString: String          // HLS (.m3u8)
    let thumbnailURLString: String // รูป preview จากเน็ต
    
    var url: URL? {
        URL(string: urlString)
    }
    
    var thumbnailURL: URL? {
        URL(string: thumbnailURLString)
    }
}

// MARK: - Sample Data (.m3u8 + remote thumbnails)
extension VideoStream {
    static let sampleStreams: [VideoStream] = [
        VideoStream(
            title: "Apple Advanced HLS Example",
            urlString: "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8",
            thumbnailURLString: "https://images.unsplash.com/photo-1515378791036-0648a3ef77b2?auto=format&fit=crop&w=800&q=80"
        ),
        VideoStream(
            title: "Apple Basic HLS Example",
            urlString: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/bipbop_4x3_variant.m3u8",
            thumbnailURLString: "https://images.unsplash.com/photo-1587829741301-dc798b83add3?auto=format&fit=crop&w=800&q=80"
        ),
        VideoStream(
            title: "Apple 16:9 HLS Example",
            urlString: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8",
            thumbnailURLString: "https://images.unsplash.com/photo-1517602302552-471fe67acf66?auto=format&fit=crop&w=800&q=80"
        )
    ]
    
    static var sample: VideoStream {
        sampleStreams[0]
    }
}
