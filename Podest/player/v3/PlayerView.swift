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
    @Published var trackTime: CGFloat = 0.5
  }
  
  @ObservedObject private var model = Model()
  @State var padding: CGFloat = 16
  @State var shadow: CGFloat = 16
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass: UserInterfaceSizeClass?
  
  private var paddingMultiplier: CGFloat {
    horizontalSizeClass == .compact ? 1 : 2
  }
  
  private var playHandler: VoidHandler?
  private var forwardHandler: VoidHandler?
  private var backwardHandler: VoidHandler?
  private var closeHandler: VoidHandler?
  private var pauseHandler: VoidHandler?
  
  private var closeTap: some Gesture {
    TapGesture()
      .onEnded { _ in
        close()
      }
  }
  
  private var imageAnimation: Animation {
    model.isPlaying ?
      .interpolatingSpring(stiffness: 200, damping: 15, initialVelocity: 10) :
      .default
  }
  
  private func updateForIsPlaying(_ isPlaying: Bool) {
    padding = (isPlaying ? 16 : 64) * paddingMultiplier
    shadow = (isPlaying ? 16 : 8) * paddingMultiplier
  }
  
  var body: some View {
    ZStack {
      Background(image: $model.image)
      
      VStack(spacing: 24) {
        CloseBarButton()
          .gesture(closeTap)
        
        Image(uiImage: model.image)
          .resizable()
          .cornerRadius(8)
          .aspectRatio(contentMode: .fit)
          .padding(padding)
          .shadow(radius: shadow)
          .frame(maxHeight: .infinity)
          .onAppear {
            updateForIsPlaying(model.isPlaying)
          }
        
        VStack(spacing: 12) {
          MarqueeText(model.title, maxWidth: 286)
          Text(model.subtitle)
            .font(.subheadline)
            .lineLimit(1)
        }
        .frame(maxWidth: 286)
        .clipped()
        
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
          isPlaying: $model.isPlaying.onChange { isPlaying in
            withAnimation(imageAnimation) {
              updateForIsPlaying(isPlaying)
            }
          }
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
      .padding(12)
      .foregroundColor(Color(.label))
    }
  }
}

// MARK: - API

extension PlayerView {
  
  private func nop() {}
  
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
