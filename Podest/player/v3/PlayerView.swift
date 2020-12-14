//
//  PlayerView.swift
//  Podest
//
//  Created by Michael Nisi on 05.09.20.
//  Copyright © 2020 Michael Nisi. All rights reserved.
//

import SwiftUI
import FeedKit

class NowPlaying: ObservableObject {
  
  @Published var title: String
  @Published var subtitle: String
  @Published var image: UIImage
  
  init(title: String, subtitle: String, image: UIImage) {
    self.title = title
    self.subtitle = subtitle
    self.image = image
  }
}

class PlaybackInfo: ObservableObject {
  
  @Published var isPlaying: Bool
  
  init(isPlaying: Bool) {
    self.isPlaying = isPlaying
  }
}

struct PlayerView: View {
  
  @ObservedObject var model = NowPlaying(
    title: "",
    subtitle: "",
    image: UIImage(named: "Oval")!
  )
  
  @ObservedObject var info = PlaybackInfo(isPlaying: false)
  
  @State var padding: CGFloat = 16
  @State var shadow: CGFloat = 16
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass: UserInterfaceSizeClass?
  @State var cornerRadius: CGFloat = 8
  @State var trackTime: CGFloat = 0.5
  
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
    info.isPlaying ?
      .interpolatingSpring(stiffness: 200, damping: 15, initialVelocity: 10) :
      .default
  }
  
 private func updateState() {
    let isPlaying = info.isPlaying
    padding = (isPlaying ? 16 : 64) * paddingMultiplier
    shadow = (isPlaying ? 16 : 8) * paddingMultiplier
    cornerRadius = isPlaying ? 16 : 8
  }
  
  var body: some View {
    ZStack {
      Background(image: $model.image)
      
      VStack(spacing: 24) {
        CloseBarButton()
          .gesture(closeTap)
        
        Image(uiImage: model.image)
          .resizable()
          .cornerRadius(cornerRadius)
          .aspectRatio(contentMode: .fit)
          .padding(padding)
          .shadow(radius: shadow)
          .frame(maxHeight: .infinity)
          .onAppear {
            DispatchQueue.main.async {
              updateState()
            }
          }
          .onDisappear {
            DispatchQueue.main.async {
              updateState()
            }
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
          Slider(value: $trackTime)
          Text("67:10").font(.caption)
        }
        
        ControlsView(
          play: play,
          pause: pause,
          forward: forward,
          backward: backward,
          isPlaying: $info.isPlaying.onChange { _ in
            DispatchQueue.main.async {
              withAnimation(imageAnimation) {
                updateState()
              }
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
        }
        .foregroundColor(Color(.secondaryLabel))
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
}

