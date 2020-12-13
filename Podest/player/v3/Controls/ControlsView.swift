//
//  ControlsView.swift
//  Podest
//
//  Created by Michael Nisi on 05.09.20.
//  Copyright © 2020 Michael Nisi. All rights reserved.
//

import SwiftUI

struct ControlsView: View {
  
  let play: VoidHandler
  let pause: VoidHandler
  let forward: VoidHandler
  let backward: VoidHandler
  
  @Binding var isPlaying: Bool
  
  private func isPlayingChange(value: Bool) {
    value ? play() : pause()
  }

  var body: some View {
      HStack(spacing: 32) {
        PlayerButton(action: forward, style: .gobackward15)
          .frame(width: 24, height: 24 ).foregroundColor(Color(.secondaryLabel))
        PlayerButton(action: backward, style: .backward)
          .frame(width: 48, height: 48)
        PlayButton(isPlaying: $isPlaying.onChange(isPlayingChange))
          .frame(width: 48, height: 48)
        PlayerButton(action: forward, style: .forward)
          .frame(width: 48, height: 64)
        PlayerButton(action: forward, style: .goforward15)
          .frame(width: 24, height: 24 ).foregroundColor(Color(.secondaryLabel))
      }
  }
}
