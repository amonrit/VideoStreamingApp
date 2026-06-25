//
//  FullScreenPlayerView.swift
//  steam
//
//  Created by Amonrit on 25/6/2569 BE.
//

import SwiftUI

struct FullScreenPlayerView: View {
    
    @ObservedObject var viewModel: VideoPlayerViewModel
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            
            VideoPlayerView(viewModel: viewModel, isFullScreen: $isPresented)
                .ignoresSafeArea()
            
            Button {
                isPresented = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white)
                    .shadow(radius: 4)
                    .padding()
            }
        }
        .statusBarHidden(true)
    }
}

#Preview {
    FullScreenPlayerView(
        viewModel: VideoPlayerViewModel(stream: .sample),
        isPresented: .constant(true)
    )
}
