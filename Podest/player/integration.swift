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

private let log = OSLog(subsystem: "ink.codes.podest", category: "player")

extension RootViewController: Players {
  // Implementation of Players is broken down into extensions below.
}

// MARK: - Placing the Mini-Player

extension RootViewController {

  var isMiniPlayerHidden: Bool {
    return minivc.viewIfLoaded?.isHidden ?? true
  }

  private var miniLayout: NSLayoutConstraint {
    return view.constraints.first {
      guard $0.isActive else {
        return false
      }

      return $0.identifier == "Mini-Player-Layout-Top" ||
        $0.identifier == "Mini-Player-Layout-Leading"
      }!
  }

  var miniPlayerEdgeInsets: UIEdgeInsets {
    guard
      !isMiniPlayerHidden,
      miniLayout.identifier == "Mini-Player-Layout-Top",
      miniLayout.constant != 0 else {
      return .zero
    }

    let bottom = minivc.view.frame.height - view.safeAreaInsets.bottom

    return UIEdgeInsets(top: 0, left: 0, bottom: bottom, right: 0)
  }

  func hideMiniPlayer(_ animated: Bool) {
    os_log("hiding mini-player", log: log, type: .debug)

    func done() {
      minivc.locator = nil
    }

    guard animated else {
      miniPlayerTop.constant = 0
      miniPlayerBottom.constant = miniPlayerConstant
      miniPlayerLeading.constant = 0
      minivc.view.isHidden = true

      view.layoutIfNeeded()

      return done()
    }

    // For now this app has no state—I can think of—where animated hiding
    // would be executed. Should we remove this code path?

    os_log("** unexpectedly animating", log: log)

    if miniPlayerTop.isActive {
      miniPlayerTop.constant = 0
      miniPlayerBottom.constant = miniPlayerConstant

      UIView.animate(withDuration: 0.3, animations: {
        self.view.layoutIfNeeded()
      }) { ok in
        self.miniPlayerLeading.constant = 0
        self.view.layoutIfNeeded()
        self.minivc.view.isHidden = true
        done()
      }
    } else {
      miniPlayerLeading.constant = 0

      UIView.animate(withDuration: 0.3, animations: {
        self.view.layoutIfNeeded()
      }) { ok in
        self.miniPlayerTop.constant = 0
        self.miniPlayerBottom.constant = self.miniPlayerConstant

        self.view.layoutIfNeeded()

        self.minivc.view.isHidden = true

        done()
      }
    }
  }

  func showMiniPlayer(_ animated: Bool) {
    os_log("showing mini-player", log: log, type: .debug)

    minivc.view.isHidden = false

    guard animated, !isPresentingVideo else {
      os_log("** applying constant: %f",
             log: log, type: .debug, miniPlayerConstant)

      miniPlayerLeading.constant = miniPlayerConstant - view.safeAreaInsets.right
      miniPlayerTop.constant = miniPlayerConstant
      miniPlayerBottom.constant = 0

      return view.layoutIfNeeded()
    }

    if miniPlayerTop.isActive {
      os_log("animating portrait", log: log, type: .debug)

      miniPlayerLeading.constant = miniPlayerConstant
      miniPlayerTop.constant = miniPlayerConstant
      miniPlayerBottom.constant = 0
    } else {
      os_log("animating landscape", log: log, type: .debug)

      miniPlayerTop.constant = miniPlayerConstant
      miniPlayerBottom.constant = 0
      miniPlayerLeading.constant = miniPlayerConstant - view.safeAreaInsets.right
    }

    UIViewPropertyAnimator(duration: 0.3, curve: .easeOut) {
      self.view.layoutIfNeeded()
    }.startAnimation()
  }
}

// MARK: - Controlling Playback

extension RootViewController {
  
  func play(_ entry: Entry) {
    os_log("playing: %@", log: log, type: .debug, entry.title)

    Podest.userQueue.enqueue(entries: [entry], belonging: .user) { enqueued, er in
      if let error = er {
        os_log("enqueue error: %{public}@",
               log: log, type: .error, error as CVarArg)
      }

      if !enqueued.isEmpty {
        os_log("enqueued to play: %@", log: log, type: .debug, enqueued)
      }

      do {
        try Podest.userQueue.skip(to: entry)
      } catch {
        os_log("skip error: %{public}@",
               log: log, type: .error, error as CVarArg)
      }

      self.playbackControlProxy = SimplePlaybackState(entry: entry, isPlaying: true)

      Podest.playback.setCurrentEntry(entry)
      Podest.playback.resume()
    }
  }

  func isPlaying(_ entry: Entry) -> Bool {
    return Podest.playback.currentEntry == entry
  }

  func pause() {
    guard Podest.playback.currentEntry != nil else {
      return
    }
    
    Podest.playback.pause()
  }
}

/// Player view controllers must adopt this protocol. It specifies a view 
/// controller that knows how to navigate this app, is able to control playback, 
/// and forwards its entry.
protocol EntryPlayer: UIViewController, Navigator, PlaybackControlDelegate {
  var entryChangedBlock: ((Entry?) -> Void)? { get set }
}

// MARK: - Presenting the Audio Player

extension RootViewController {
  
  private enum PlayerVersion {
    case v1, v2
  }

  /// Returns a new player view controller of `version`.
  ///
  /// Within this factory function is the only place where concrete player view
  /// controller types (and identifiers) are allowed.
  private static func makeNowPlaying(version: PlayerVersion) -> EntryPlayer {
    switch version {
    case .v1:
      let sb = UIStoryboard(name: "PlayerV1", bundle: .main)
      
      return sb.instantiateViewController(withIdentifier: "PlayerV1ID")
        as! PlayerV1ViewController
      
    case .v2:
      let sb = UIStoryboard(name: "PlayerV2", bundle: .main)
      
      return sb.instantiateViewController(withIdentifier: "PlayerV2ID")
        as! PlayerV2ViewController
    }
  }
  
  /// Returns a matching transitioning delegate for `player`.
  private static func makePlayerTransition(
    player: EntryPlayer) -> UIViewControllerTransitioningDelegate? {
    guard player is PlayerV1ViewController else {
      return nil
    }
    
    player.modalPresentationStyle = .custom
    
    return PlayerTransitionDelegate()
  }

  func showNowPlaying(entry: Entry) {
    guard let now = playbackControlProxy else {
      fatalError("need something to play")
    }

    assert(entry == now.entry)

    var vc = RootViewController.makeNowPlaying(version: .v1)
    vc.navigationDelegate = self

    playervc = vc

    // Resetting nowPlaying to trigger updates.
    playbackControlProxy = now

    // Using a setter to drive this important change is unfortunate. Turns out,
    // we could need a callback now, for knowing when it’s done. Working around
    // the issue by installing a callback on the view controller.

    vc.entryChangedBlock = { [weak self] changedEntry in
      dispatchPrecondition(condition: .onQueue(.main))

      defer {
        vc.entryChangedBlock = nil
      }

      guard changedEntry == entry else {
        return
      }

      self?.playerTransition = RootViewController.makePlayerTransition(player: vc)
      vc.transitioningDelegate = self?.playerTransition

      self?.present(vc, animated: true) {
        self?.playerTransition = nil
      }
    }

  }

  func hideNowPlaying(animated flag: Bool, completion: (() -> Void)?) {
    guard presentedViewController is EntryPlayer else {
      return
    }
    
    playervc = nil
    playerTransition = PlayerTransitionDelegate()
    presentedViewController?.transitioningDelegate = playerTransition

    dismiss(animated: flag)  { [weak self] in
      self?.playerTransition = nil
      completion?()
    }
  }
}

// MARK: - Presenting the Video Player

extension RootViewController {

  var isPresentingVideo: Bool {
    return presentedViewController is AVPlayerViewController
  }

  func showVideo(player: AVPlayer) {
    DispatchQueue.main.async {
      let vc = AVPlayerViewController()

      vc.modalPresentationCapturesStatusBarAppearance = false
      vc.modalPresentationStyle = .fullScreen
      vc.updatesNowPlayingInfoCenter = false

      vc.player = player

      self.present(vc, animated: true) {
        os_log("presented video player", log: log, type: .debug)
      }
    }
  }

  func hideVideoPlayer() {
    DispatchQueue.main.async {
      guard self.isPresentingVideo else {
        return
      }

      self.dismiss(animated: true) {
        os_log("dismissed video player", log: log, type: .debug)
      }
    }
  }

  var isPlayerPresented: Bool {
    return isPresentingVideo || presentedViewController is EntryPlayer
  }
}


/// This extension hides the status bar in landscape.
extension AVPlayerViewController {

  override open var prefersStatusBarHidden: Bool {
    let c = UITraitCollection(horizontalSizeClass: .compact)
    return !traitCollection.containsTraits(in: c)
  }
}

// MARK: - PlaybackDelegate

extension RootViewController: PlaybackDelegate {

  func proxy(url: URL) -> URL? {
    do {
      return try Podest.files.url(for: url)
    } catch {
      os_log("returning nil: caught file proxy error: %{public}@",
             log: log, error as CVarArg)
      return nil
    }
  }

  var isPresentingNowPlaying: Bool {
    return presentedViewController is EntryPlayer
  }

  func playback(session: Playback, didChange state: PlaybackState) {
    os_log("playback state did change: %{public}@", 
           log: log, type: .debug, String(describing: state))
    
    switch state {
    case .paused(let entry, let error):
      defer {
        self.playbackControlProxy = SimplePlaybackState(entry: entry, isPlaying: false)
      }

      guard 
        let er = error, 
        let c = PlayerMessage.makeMessage(entry: entry, error: er) else {
        return
      }

      DispatchQueue.main.async {
        let alert = UIAlertController(
          title: c.0, message: c.1, preferredStyle: .alert
        )

        let ok = UIAlertAction(title: "OK", style: .default) { _ in
          alert.dismiss(animated: true)
        }

        alert.addAction(ok)

        // Now Playing or ourselves should be presenting the alert.

        let presenter = self.isPresentingNowPlaying ?
          self.presentedViewController : self
        presenter?.present(alert, animated: true, completion: nil)
      }

    case .listening(let entry):      
      self.playbackControlProxy = SimplePlaybackState(
        entry: entry, isPlaying: true)

    case .preparing(let entry, let shouldPlay):      
      self.playbackControlProxy = SimplePlaybackState(
        entry: entry, isPlaying: shouldPlay)

    case .viewing(let entry, let player):
      self.playbackControlProxy = SimplePlaybackState(
        entry: entry, isPlaying: true)

      if !isPresentingNowPlaying {
        self.showVideo(player: player)
      }

    case .inactive(let error, let resuming):
      if let er = error {
        os_log("session error: %{public}@", log: log, type: .error,
               er as CVarArg)
        fatalError(String(describing: er))
      }

      guard !resuming else {
        return
      }

      DispatchQueue.main.async {
        self.hideMiniPlayer(true)
      }
    }
  }

  func nextItem() -> Entry? {
    return Podest.userQueue.next()
  }

  func previousItem() -> Entry? {
    return Podest.userQueue.previous()
  }

  func dismissVideo() {
    hideVideoPlayer()
  }
}
