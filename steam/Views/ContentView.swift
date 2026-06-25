//
//  ContentView.swift
//  steam
//
//  Created by Amonrit on 25/6/2569 BE.
//

import SwiftUI

struct ContentView: View {
    
    @StateObject private var viewModel = VideoPlayerViewModel()
    
    var body: some View {
        VStack {
            
            VideoPlayerView(viewModel: viewModel)
                .frame(height: 250)
            
            HStack {
                
                Button("Play") {
                    viewModel.play()
                }
                .buttonStyle(.borderedProminent)
                
                Button("Pause") {
                    viewModel.pause()
                }
                .buttonStyle(.bordered)
            }
            
            Spacer()
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
