//
//  PlayerUIView.swift
//  Podest
//
//  Created by Michael Nisi on 05.09.20.
//  Copyright © 2020 Michael Nisi. All rights reserved.
//

import SwiftUI
import FeedKit

struct PlayerUIView: View {
  
  private var nextHandler: VoidHandler?
  private var closeHandler: VoidHandler?
  
  class Model: ObservableObject {
    @Published var item: Entry!
  }
  
  @ObservedObject private var model = Model()
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  
  private var padding: CGFloat {
    horizontalSizeClass == .compact ? 64 : 128
  }
  
  private func next() {
    nextHandler?()
  }
  
  private func close() {
    closeHandler?()
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
      HStack {
        PlayButton(action: next)
          .frame(width: 64, height: 64)
        PlayButton(action: next)
          .frame(width: 64, height: 64)
        PlayButton(action: next)
          .frame(width: 64, height: 64)
      }
      .padding(padding)
    }.environmentObject(model)
  }
  
  mutating func install(nextHandler: VoidHandler?, closeHandler: VoidHandler?) {
    self.nextHandler = nextHandler
    self.closeHandler = closeHandler
  }
  
  mutating func uninstall() {
    self.nextHandler = nil
    self.closeHandler = nil
  }
  
  func configure(with entry: Entry?) {
    guard let entry = entry else {
      return
    }
    
    model.item = entry
  }
}
