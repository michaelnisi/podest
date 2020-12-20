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
  
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass: UserInterfaceSizeClass?
  
  @ObservedObject var model = NowPlaying(
    title: "",
    subtitle: "",
    image: UIImage(named: "Oval")!
  )
  
  @ObservedObject var info = PlaybackInfo(isPlaying: false)
  
  @State var padding: CGFloat = 16
  @State var shadow: CGFloat = 16
  @State var cornerRadius: CGFloat = 8
  @State var trackTime: CGFloat = 0.5
  @State var imageAnimation: Animation?
  @State var imageWidth: CGFloat = 0
  
  private var paddingMultiplier: CGFloat {
    horizontalSizeClass == .compact ? 2 / 3 : 1
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
    
  private var outerPadding: EdgeInsets {
    EdgeInsets(top: 12, leading: 0, bottom: 0, trailing: 0)
  }
  
  private var innerPadding: EdgeInsets {
    EdgeInsets(top: 0, leading: 12, bottom: 12, trailing: 12)
  }
  
  private var image: some View {
    Image(uiImage: model.image)
      .resizable()
      .cornerRadius(cornerRadius)
      .aspectRatio(contentMode: .fit)
      .padding(padding)
      .shadow(radius: shadow)
      .frame(maxHeight: .infinity)
      .foregroundColor(Color(.quaternaryLabel))
      .background(GeometryReader { geometry in
        Color.clear.preference(key: SizePrefKey.self, value: geometry.size)
      })
      .onPreferenceChange(SizePrefKey.self) { size in
        imageWidth = size.width
      }
  }
  
  private var titles: some View {
    VStack(spacing: 6) {
      MarqueeText(string: $model.title, width: $imageWidth)
      Text(model.subtitle)
        .font(.subheadline)
        .lineLimit(1)
    }
  }
  
  private var track: some View {
    HStack(spacing: 16) {
      Text("00:00").font(.caption)
      Slider(value: $trackTime)
      Text("67:10").font(.caption)
    }
  }
  
  private var controls: some View {
    ControlsView(
      play: play,
      pause: pause,
      forward: forward,
      backward: backward,
      isPlaying: $info.isPlaying
    )
  }
  
  private var actions: some View {
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
  
  var body: some View {
    HStack {
      ZStack {
        Background(image: $model.image)
        VStack {
          CloseBarButton()
            .gesture(closeTap)
          
          VStack(spacing: 24) {
            image
            titles
            track
            controls
            actions
          }
          .padding(innerPadding)
          .foregroundColor(Color(.label))
          .frame(maxWidth: 600)
          .onAppear {
            imageAnimation = nil
          }
          .onReceive(info.$isPlaying) { isPlaying in
            DispatchQueue.main.async {
              withAnimation(imageAnimation) {
                updateState(isPlaying)
              }
            }
          }
        }.padding(outerPadding)
      }
    }
  }
  
  private var spring: Animation {
    .interpolatingSpring(mass: 1, stiffness: 250, damping: 15, initialVelocity: -5)
  }
  
  private func makeImageAnimation(isPlaying: Bool) -> Animation {
    isPlaying ? .default : spring
  }
  
  private func updateState(_ isPlaying: Bool) {
    padding = (isPlaying ? 16 : 64) * paddingMultiplier
    shadow = (isPlaying ? 16 : 8) * paddingMultiplier
    cornerRadius = isPlaying ? 16 : 8
    imageAnimation = makeImageAnimation(isPlaying: isPlaying)
  }
}

// MARK: - Actions

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

