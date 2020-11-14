//
//  PlayButton.swift
//  Podest
//
//  Created by Michael Nisi on 13.09.20.
//  Copyright © 2020 Michael Nisi. All rights reserved.
//

import SwiftUI

struct ImageButtonStyle: ButtonStyle {
  let systemName: String

  func makeBody(configuration: Self.Configuration) -> some View {
    Image(systemName: systemName)
      .resizable()
      .aspectRatio(contentMode: .fit)
  }
}

struct PlayButton: View {
  @State var action: () -> Void
  
  var body: some View {
    Button(action: action) {}.buttonStyle(ImageButtonStyle(systemName: "play.circle"))
  }
}

struct VolumeButton: View {
  var body: some View {
    Button(action: {
      print("Button action")
    }) {}.buttonStyle(ImageButtonStyle(systemName: "speaker.fill"))
  }
}

struct TimelineButton: View {
  var body: some View {
    Button(action: {
      print("Button action")
    }) {}.buttonStyle(ImageButtonStyle(systemName: "goforward.30"))
  }
}

struct SkipButton: View {
  var body: some View {
    Button(action: {
      print("Button action")
    }) {}.buttonStyle(ImageButtonStyle(systemName: "shuffle"))
  }
}


