//
//  PlayButton.swift
//  Podest
//
//  Created by Michael Nisi on 13.09.20.
//  Copyright © 2020 Michael Nisi. All rights reserved.
//

import SwiftUI

struct ImageButtonStyle: ButtonStyle {
  
  @State var systemName: String

  func makeBody(configuration: Self.Configuration) -> some View {
    Image(systemName: systemName)
      .resizable()
      .aspectRatio(contentMode: .fit)
      .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
  }
}

struct PlayButton: View {
  
  @Binding var isPlaying: Bool
  
  var style: ImageButtonStyle {
    ImageButtonStyle(systemName: isPlaying ? "pause.fill" : "play.fill")
  }
  
  var insets: EdgeInsets {
    EdgeInsets(top: 0, leading: isPlaying ? 0 : 8, bottom: 0, trailing: 0)
  }

  var body: some View {
    Button(action: {
      self.isPlaying.toggle()
    }) {}
    .buttonStyle(style)
    .padding(insets)
  }
}

struct ForwardButton: View {
  
  let action: VoidHandler
  
  var body: some View {
    Button(action: action) {}
      .buttonStyle(ImageButtonStyle(systemName: "forward.fill"))
  }
}

struct BackwardButton: View {
  
  let action: VoidHandler
  
  var body: some View {
    Button(action: action) {}
      .buttonStyle(ImageButtonStyle(systemName: "backward.fill"))
  }
}

