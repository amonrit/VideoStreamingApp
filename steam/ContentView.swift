//
//  ContentView.swift
//  steam
//
//  Created by Amonrit on 25/6/2569 BE.
//

import SwiftUI

struct ContentView: View {
    
    @StateObject private var vm = VideoPlayerViewModel()
    
    var body: some View {
        VStack {
            
            VideoPlayerView(viewModel: vm)
                .frame(height: 250)
            
            HStack {
                
                Button("Play") {
                    vm.play()
                }
                .buttonStyle(.borderedProminent)
                
                Button("Pause") {
                    vm.pause()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
    }
}
