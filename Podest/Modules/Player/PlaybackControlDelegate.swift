//
//  PlaybackControlDelegate.swift
//  Podest
//
//  Created by Michael Nisi on 21.03.18.
//  Copyright © 2018 Michael Nisi. All rights reserved.
//

import Foundation
import FeedKit
import UIKit
import os.log
import InsetPresentation
import Playback
import Podcasts

private let log = OSLog(subsystem: "ink.codes.podest", category: "player")

/// Receives callbacks for playback status changes.
protocol PlaybackResponding: AnyObject {
  func playing(entry: Entry, asset: AssetState?)
  func pausing(entry: Entry, asset: AssetState?)
  func dismiss()
}

/// Handles playback view relevant playback events. We can have few of these,
/// mini-player, player, now playing, etc.
protocol PlaybackControlDelegate: PlaybackResponding {
  var entry: Entry? { get set }
  var isPlaying: Bool { get set }
  var asset: AssetState? { get set }
  
  var isForwardable: Bool { get set }
  var isBackwardable: Bool { get set }
}

extension PlaybackControlDelegate {
  func playing(entry: Entry, asset: AssetState?) {
    do {
      try Podcasts.userQueue.skip(to: entry)
    } catch {
      os_log("queue error: %{public}@", log: log, type: .error, error as CVarArg)
    }
    
    DispatchQueue.main.async { [weak self] in
      self?.entry = entry
      self?.isPlaying = true
      self?.isForwardable = Podcasts.userQueue.isForwardable
      self?.isBackwardable = Podcasts.userQueue.isBackwardable
      self?.asset = asset
    }
  }
  
  func pausing(entry: Entry, asset: AssetState?) {
    DispatchQueue.main.async { [weak self] in
      self?.entry = entry
      self?.isPlaying = false
      self?.isForwardable = Podcasts.userQueue.isForwardable
      self?.isBackwardable = Podcasts.userQueue.isBackwardable
      self?.asset = asset
    }
  }
  
  func dismiss() {
    DispatchQueue.main.async { [weak self] in
      self?.entry = nil
      self?.isPlaying = false
      self?.asset = nil
    }
  }
}

/// Player view controllers must adopt this protocol. It specifies a view
/// controller that knows how to navigate this app, is able to control playback,
/// and forwards its entry.
protocol EntryPlayer: Navigator, PlaybackControlDelegate, InsetPresentable {}

