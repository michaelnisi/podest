//===----------------------------------------------------------------------===//
//
// This source file is part of the Podest open source project
//
// Copyright (c) 2021 Michael Nisi and collaborators
// Licensed under MIT License
//
// See https://github.com/michaelnisi/podest/blob/main/LICENSE for license information
//
//===----------------------------------------------------------------------===//

import FeedKit
import UIKit
import os.log
import class Epic.Player
import Podcasts

private let log = OSLog(subsystem: "ink.codes.podest", category: "player")

extension RootViewController {
  func subscribe() {
    Podcasts.player.$state.sink { [unowned self] state in
      switch state {
      case let .mini(entry, _, player, message):
        self.alertIfNecessary(showing: message)
        self.hideVideoPlayer(animated: true) {
          self.minivc.configure(with: player, entry: entry)
          self.hideNowPlaying(animated: true) {
            self.showMiniPlayer(animated: true)
          }
        }

      case let .full(_, _, player):
        self.hideVideoPlayer(animated: true) {
          self.showNowPlaying(model: player, animated: true)
        }
        
      case let .video(_, player):
        self.hideNowPlaying(animated: true) {
          self.showVideo(player: player, animated: true, completion: nil)
        }
      
      case let .none(message):
        self.alertIfNecessary(showing: message)
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
  func showNowPlaying(model: Epic.Player, animated: Bool, completion: (() -> Void)? = nil) {
    os_log("showing now playing", log: log, type: .info)
    dispatchPrecondition(condition: .onQueue(.main))
    
    guard !isPresentingNowPlaying else {
      completion?()

      return
    }
    
    present(PlayerViewController(model: model), interactiveDismissalType: .vertical) {
      completion?()
    }
  }

  func hideNowPlaying(animated: Bool, completion: (() -> Void)?) {
    os_log("hiding now playing", log: log, type: .info)
    dispatchPrecondition(condition: .onQueue(.main))

    guard isPresentingNowPlaying else {
      completion?()

      return
    }

    dismiss(animated: animated)  {
      completion?()
    }
  }
}

// MARK: - Showing Messages

private extension RootViewController {
  func alertIfNecessary(showing message: PlaybackController.Meta) {
    switch message {
    case let .error(title, message):
      let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
      
      alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Default action"), style: .default))
      present(alert, animated: true, completion: nil)
      
    case let .more(entry):
      show(entry: entry)
      
    case .none:
      break
    }
  }
}

// MARK: - Playback Handlers

extension RootViewController {
  var isPresentingNowPlaying: Bool {
    presentedViewController is PlayerViewController
  }
}
