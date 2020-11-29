//
//  PlayerView.swift
//  Podest
//
//  Created by Michael Nisi on 05.09.20.
//  Copyright © 2020 Michael Nisi. All rights reserved.
//

import SwiftUI
import FeedKit

struct PlayerView: View {
  
  private class Model: ObservableObject {
    @Published var title: String = ""
    @Published var subtitle: String = ""
    @Published var isPlaying: Bool = false
  }
    
  @ObservedObject private var model = Model()
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @State private var scale: CGFloat = 0
  
  private var playHandler: VoidHandler?
  private var forwardHandler: VoidHandler?
  private var backwardHandler: VoidHandler?
  private var closeHandler: VoidHandler?
  private var pauseHandler: VoidHandler?
  private var loadImage: LoadImage?
  
  private var padding: CGFloat {
    horizontalSizeClass == .compact ? 64 : 128
  }
  
  private var closeTap: some Gesture {
    TapGesture()
      .onEnded { _ in
        close()
      }
  }
  
  var body: some View {
    VStack {
      CloseBarButton()
        .padding(8)
        .gesture(closeTap)
      
      ImageView(image: FetchImage(loadImage: loadImage))
        .padding(padding)
        .shadow(radius: 16)
      
      TitlesView(title: model.title, subtitle: model.subtitle)
      
      ControlsView(
        play: play,
        pause: pause,
        forward: forward,
        backward: backward,
        isPlaying: model.isPlaying
      )
      
      Spacer()
    }
  }
}

// MARK: - API

extension PlayerView {
  
  private func forward() {
    forwardHandler?()
  }
  
  private func backward() {
    backwardHandler?()
  }
  
  private func play() {
    playHandler?()
  }
  
  private func close() {
    closeHandler?()
  }
  
  private func pause() {
    pauseHandler?()
  }
  
  mutating func install(
    playHandler: VoidHandler? = nil,
    forwardHandler: VoidHandler? = nil,
    backwardHandler: VoidHandler? = nil,
    closeHandler: VoidHandler? = nil,
    pauseHandler: VoidHandler? = nil,
    loadImage: ((CGSize, ((UIImage) -> Void)?) -> Void)? = nil
  ) {
    self.playHandler = playHandler
    self.forwardHandler = forwardHandler
    self.backwardHandler = backwardHandler
    self.closeHandler = closeHandler
    self.pauseHandler = pauseHandler
    self.loadImage = loadImage
  }
  
  func configure(title: String, subtitle: String) {
    model.title = title
    model.subtitle = subtitle
  }
  
  func configure(isPlaying: Bool) {
    model.isPlaying = isPlaying
  }
}
