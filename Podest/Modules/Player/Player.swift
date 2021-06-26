//
//  integration.swift - integrate players
//  Podest
//
//  Created by Michael Nisi on 18.11.18.
//  Copyright © 2018 Michael Nisi. All rights reserved.
//

import FeedKit
import UIKit
import os.log
import Playback
import AVKit
import AVFoundation
import Ola
import FileProxy
import SwiftUI
import Epic
import Podcasts

private let log = OSLog(subsystem: "ink.codes.podest", category: "player")

// MARK: - Players

extension RootViewController {}

extension RootViewController {
  func subscribe() {
    Podcasts.player.$state.sink { [unowned self] state in
      os_log(.debug, log: log, "** new player state: %{public}@", state.description)
      switch state {
      case let .mini(entry, _, player):
        self.minivc.configure(with: player, entry: entry)
        self.showMiniPlayer(animated: true)
        
      case let .full(_, _, player):
        self.showNowPlaying(model: player, animated: true, completion: nil)
      
      default:
        break
      }
    }
    .store(in: &subscriptions)
  }
  
  func unsubscribe() {
    subscriptions.removeAll()
  }
}

// MARK: - Presenting the Audio Player

extension RootViewController {
  func showNowPlaying(model: Epic.Player, animated: Bool, completion: (() -> Void)?) {
    os_log("showing now playing", log: log, type: .info)
    dispatchPrecondition(condition: .onQueue(.main))
    
    let vc = PlayerViewController(model: model)
    playervc = vc
    playerTransitioningDelegate = PlayerTransitioningDelegate(from: self, to: vc)
    vc.transitioningDelegate = playerTransitioningDelegate
    
    present(vc, interactiveDismissalType: .vertical) {
      completion?()
    }
  }

  func hideNowPlaying(animated: Bool, completion: (() -> Void)?) {
    os_log("hiding now playing", log: log, type: .info)
    dispatchPrecondition(condition: .onQueue(.main))

    guard presentedViewController is EntryPlayer else {
      completion?()

      return
    }

    dismiss(animated: animated)  {
      completion?()
    }
  }
}

// MARK: - Playback Handlers

extension RootViewController {
  var isPresentingNowPlaying: Bool {
    presentedViewController is EntryPlayer
  }
}

