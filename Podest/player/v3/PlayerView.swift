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
  
  class Model: ObservableObject {
    @Published var item: Entry?
    @Published var isPlaying: Bool = false
  }
  
  var playHandler: ArgHandler<Entry?>?
  var forwardHandler: VoidHandler?
  var backwardHandler: VoidHandler?
  var closeHandler: VoidHandler?
  var pauseHandler: VoidHandler?
  
  @ObservedObject private var model = Model()
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  
  @State var scale: CGFloat = 0
  
  var body: some View {
    VStack {
      CloseBarButton()
        .padding(8)
        .gesture(closeTap)
      if let item = model.item {
        ImageView(image: FetchImage(item: item))
          .padding(padding)
          .scaleEffect(scale)
          .onAppear {
            withAnimation(imageAnimation) {
              self.scale = 1
            }
          }
      }
 
      TitlesView()
      ControlsView(play: play, pause: pause, forward: forward, backward: backward)
      Spacer()
    }
    .environmentObject(model)
  }
}

// MARK: - Infrastructure

extension PlayerView {
  
  private func forward() {
    forwardHandler?()
  }
  
  private func backward() {
    backwardHandler?()
  }
  
  private func play() {
    playHandler?(model.item)
  }
  
  private func close() {
    closeHandler?()
  }
  
  private func pause() {
    pauseHandler?()
  }
  
  mutating func install(
    playHandler: ArgHandler<Entry?>? = nil,
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
  
  mutating func uninstall() {
    self.playHandler = nil
    self.forwardHandler = nil
    self.backwardHandler = nil
    self.closeHandler = nil
    self.pauseHandler = nil
  }
  
  func configure(with entry: Entry?) {
    guard let entry = entry else {
      return
    }
    
    model.item = entry
  }
  
  var isPlaying: Bool {
    get { model.isPlaying }
    set { model.isPlaying = newValue }
  }
}

// MARK: - Factory

extension PlayerView {
  
  private var padding: CGFloat {
    horizontalSizeClass == .compact ? 64 : 128
  }
  
  private var closeTap: some Gesture {
    TapGesture()
      .onEnded { _ in
        close()
      }
  }
  
  private var imageAnimation: Animation {
    .interpolatingSpring(stiffness: 350, damping: 15, initialVelocity: 10)
  }
}
