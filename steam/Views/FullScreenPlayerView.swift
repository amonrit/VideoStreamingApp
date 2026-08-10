//
//  FullScreenPlayerView.swift
//  steam
//
//  Created by Amonrit on 25/6/2569 BE.
//

import SwiftUI

struct FullScreenPlayerView: View {
    @ObservedObject var viewController: VideoPlayerViewController
    @Binding var isPresented: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            VideoPlayerView(viewController: viewController, isFullScreen: $isPresented)
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
#if os(iOS)
        .statusBarHidden(true)
#endif
    }
}

#Preview {
    let viewController = VideoPlayerRouter.createModule(stream: .sample)
    return FullScreenPlayerView(
        viewController: viewController,
        isPresented: .constant(true)
    )
}
