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
    @Published var title = ""
    @Published var subtitle = ""
    @Published var isPlaying = false
    @Published var image = UIImage(named: "Oval")!
    @Published var padding: CGFloat = 64
    @Published var shadow: CGFloat = 16
    @Published var animation: Animation = .easeOut
    @Published var trackTime: CGFloat = 0.5
  }
    
  @ObservedObject private var model = Model()
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @State private var scale: CGFloat = 0
  
  private var playHandler: VoidHandler?
  private var forwardHandler: VoidHandler?
  private var backwardHandler: VoidHandler?
  private var closeHandler: VoidHandler?
  private var pauseHandler: VoidHandler?
  
  private var paddingMultiplier: CGFloat {
    horizontalSizeClass == .compact ? 1 : 1.5
  }
  
  private var closeTap: some Gesture {
    TapGesture()
      .onEnded { _ in
        close()
      }
  }
  
  private var springAnimation: Animation {
    .interpolatingSpring(stiffness: 200, damping: 15, initialVelocity: 10)
  }
  
  var body: some View {
    VStack {
      CloseBarButton()
        .padding(8)
        .gesture(closeTap)
      
      Image(uiImage: model.image)
        .resizable()
        .cornerRadius(8)
        .aspectRatio(contentMode: .fit)
        .padding(model.padding)
        .shadow(radius: model.shadow)
        .animation(model.animation)

      TitlesView(title: model.title, subtitle: model.subtitle)
      
      Slider(value: $model.trackTime)
        .padding(paddingMultiplier * 32)
      
      ControlsView(
        play: play,
        pause: pause,
        forward: forward,
        backward: backward,
        isPlaying: $model.isPlaying
      )
      
      HStack {
        PlayerButton(action: {}, style: .airplay)
          .frame(width: 30, height: 30)
      }.padding(paddingMultiplier * 12)
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
    pauseHandler: VoidHandler? = nil
  ) {
    self.playHandler = playHandler
    self.forwardHandler = forwardHandler
    self.backwardHandler = backwardHandler
    self.closeHandler = closeHandler
    self.pauseHandler = pauseHandler
  }
  
  func configure(title: String, subtitle: String, image: UIImage) {
    model.title = title
    model.subtitle = subtitle
    model.image = image
  }
  
  func configure(isPlaying: Bool) {
    model.isPlaying = isPlaying
    model.padding = isPlaying ? paddingMultiplier * 16 : paddingMultiplier * 32
    model.shadow = isPlaying ? paddingMultiplier * 16 : paddingMultiplier * 8
    model.animation = isPlaying ? springAnimation : .easeOut
  }
}
