//
//  PlayerUIView.swift
//  Podest
//
//  Created by Michael Nisi on 05.09.20.
//  Copyright © 2020 Michael Nisi. All rights reserved.
//

import SwiftUI
import FeedKit

struct PlayerView: View {
  
  class Model: ObservableObject {
    @Published var item: Entry!
  }
  
  var playHandler: VoidHandler?
  var forwardHandler: VoidHandler?
  var backwardHandler: VoidHandler?
  var closeHandler: VoidHandler?
  
  @ObservedObject private var model = Model()
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  
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
      ControlsView(play: play, pause: play, forward: forward, backward: backward)
      .padding(padding)
    }.environmentObject(model)
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
  
  mutating func install(
    playHandler: VoidHandler? = nil,
    forwardHandler: VoidHandler? = nil,
    backwardHandler: VoidHandler? = nil,
    closeHandler: VoidHandler? = nil
  ) {
    self.playHandler = playHandler
    self.forwardHandler = forwardHandler
    self.backwardHandler = backwardHandler
    self.closeHandler = closeHandler
  }
  
  mutating func uninstall() {
    self.playHandler = nil
    self.forwardHandler = nil
    self.backwardHandler = nil
    self.closeHandler = nil
  }
  
  func configure(with entry: Entry?) {
    guard let entry = entry else {
      return
    }
    
    model.item = entry
  }
}
