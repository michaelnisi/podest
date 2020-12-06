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
  @State private var showDetail = false
  
  private var playHandler: VoidHandler?
  private var forwardHandler: VoidHandler?
  private var backwardHandler: VoidHandler?
  private var closeHandler: VoidHandler?
  private var pauseHandler: VoidHandler?
  
  private var paddingMultiplier: CGFloat {
    horizontalSizeClass == .compact ? 1 : 1
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
    VStack(spacing: 24) {
        CloseBarButton()
          .gesture(closeTap)
        
        Image(uiImage: model.image)
          .resizable()
          .cornerRadius(8)
          .aspectRatio(contentMode: .fit)
          .padding(model.padding)
          .shadow(radius: model.shadow)
          .animation(model.animation)
          .frame(maxHeight: .infinity)
        
        VStack(spacing: 12) {
          MarqueeText(model.title, maxWidth: 286)
          Text(model.subtitle)
            .font(.subheadline)
            .lineLimit(1)
        }
        .frame(maxWidth: 286)
        .clipped()
        .animation(nil)
        
        HStack(spacing: 16) {
          Text("00:00").font(.caption)
          Slider(value: $model.trackTime)
          Text("67:10").font(.caption)
        }
        
        ControlsView(
          play: play,
          pause: pause,
          forward: forward,
          backward: backward,
          isPlaying: $model.isPlaying
        )
    
        HStack(spacing: 48) {
          PlayerButton(action: nop, style: .moon)
            .frame(width: 20, height: 20 )
          AirPlayButton()
            .frame(width: 48, height: 48)
          PlayerButton(action: nop, style: .speaker)
            .frame(width: 20, height: 20 )
        }.foregroundColor(Color(.secondaryLabel))
      }
      .padding(EdgeInsets(top: 12, leading: 12, bottom: 0, trailing: 12))
      .foregroundColor(Color(.label))
    .animation(.easeInOut)
  }
}

// MARK: - API

extension PlayerView {
  
  private func nop() {
    
  }
  
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

struct PlayerView_Previews: PreviewProvider {
  
  private static func makePlayer() -> PlayerView {
    let player = PlayerView()
    
    player.configure(
      title: "#86 Man of the People but longer, much longer title",
      subtitle: "Reply All",
      image: UIImage(named: "Sample")!
    )
    
    return player
  }
  
  static var previews: some View {
    makePlayer()
  }
}
