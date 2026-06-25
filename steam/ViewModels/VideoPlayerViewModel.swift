//
//  VideoPlayerViewModel.swift
//  steam
//
//  Created by Amonrit on 25/6/2569 BE.
//

import Foundation
import AVFoundation
import Combine

final class VideoPlayerViewModel: ObservableObject {
    
    let player: AVPlayer
    
    init(urlString: String = "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8") {
        guard let url = URL(string: urlString) else {
            fatalError("Invalid stream URL: \(urlString)")
        }
        self.player = AVPlayer(url: url)
    }
    
    func play() {
        player.play()
    }
    
    func pause() {
        player.pause()
    }
}
