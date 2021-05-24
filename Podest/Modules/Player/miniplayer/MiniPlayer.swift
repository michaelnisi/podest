//
//  MiniPlayer.swift
//  Podest
//
//  Created by Michael Nisi on 23.05.21.
//  Copyright © 2021 Michael Nisi. All rights reserved.
//

import Foundation
import Playback

class MiniPlayer {
  struct Item {
    let title: String
  }
  
  @Published private (set) var isPlaying = false
  @Published private (set) var item = Item(title: "")
}

extension MiniPlayer {
  func configure(item: Item, isPlaying: Bool) {
    self.item = item
    self.isPlaying = isPlaying
  }
}
