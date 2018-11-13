//
//  PlaybackControlDelegate.swift
//  Podest
//
//  Created by Michael Nisi on 21.03.18.
//  Copyright © 2018 Michael Nisi. All rights reserved.
//

import Foundation
import FeedKit

/// Handles playback view relevant playback events. We can have few of these,
/// mini-player, player, now playing, etc.
protocol PlaybackControlDelegate: class {
  
  var entry: Entry? { get set }
  var isPlaying: Bool { get set }
  
  func playing(entry: Entry)
  func pausing(entry: Entry)
  func dismiss()

}

/// The default implementation is trivial.
extension PlaybackControlDelegate {

  func playing(entry: Entry) {
    DispatchQueue.main.async { [weak self] in
      self?.entry = entry
      self?.isPlaying = true
    }
  }
  
  func pausing(entry: Entry) {
    DispatchQueue.main.async { [weak self] in
      self?.entry = entry
      self?.isPlaying = false
    }
  }
  
  func dismiss() {
    DispatchQueue.main.async { [weak self] in
      self?.entry = nil
      self?.isPlaying = false
    }
  }
  
}
