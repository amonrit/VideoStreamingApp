//
//  VideoStreamingApp.swift
//  steam
//
//  Created by Amonrit on 25/6/2569 BE.
//

import SwiftUI
import AVKit
import Combine

final class VideoPlayerViewModel: ObservableObject {
    
    let player: AVPlayer
    
    init() {
        let url = URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8")!
        self.player = AVPlayer(url: url)
    }
    
    func play() {
        player.play()
    }
    
    func pause() {
        player.pause()
    }
}
