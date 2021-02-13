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

private let log = OSLog(subsystem: "ink.codes.podest", category: "player")

/// Receives callbacks for playback status changes.
protocol PlaybackResponding: class {
  
  func playing(entry: Entry)
  func pausing(entry: Entry)
  func dismiss()
}

/// Handles playback view relevant playback events. We can have few of these,
/// mini-player, player, now playing, etc.
protocol PlaybackControlDelegate: PlaybackResponding {
  
  var entry: Entry? { get set }
  var isPlaying: Bool { get set }
  
  var isForwardable: Bool { get set }
  var isBackwardable: Bool { get set }
}

extension PlaybackControlDelegate {
  
  func playing(entry: Entry) {
    do {
      try Podest.userQueue.skip(to: entry)
    } catch {
      os_log("queue error: %{public}@", log: log, type: .error, error as CVarArg)
    }
    
    DispatchQueue.main.async { [weak self] in
      self?.entry = entry
      self?.isPlaying = true
      self?.isForwardable = Podest.userQueue.isForwardable
      self?.isBackwardable = Podest.userQueue.isBackwardable
    }
  }
  
  func pausing(entry: Entry) {
    DispatchQueue.main.async { [weak self] in
      self?.entry = entry
      self?.isPlaying = false
      self?.isForwardable = Podest.userQueue.isForwardable
      self?.isBackwardable = Podest.userQueue.isBackwardable
    }
  }
  
  func dismiss() {
    DispatchQueue.main.async { [weak self] in
      self?.entry = nil
      self?.isPlaying = false
    }
  }
}

/// Player view controllers must adopt this protocol. It specifies a view
/// controller that knows how to navigate this app, is able to control playback,
/// and forwards its entry.
protocol EntryPlayer: UIViewController, Navigator, PlaybackControlDelegate, InsetPresentable {
  
  var readyForPresentation: (() -> Void)? { get set }
}

