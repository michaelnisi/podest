//
//  Players.swift
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

private let log = OSLog.disabled

extension RootViewController: Players {
  // Implementation of Players is broken down into caterogized extensions below.
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

    guard animated else {
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
    Podest.playback.pause()
  }

}

// MARK: - Presenting the Audio Player

extension RootViewController {

  private static func makeNowPlaying() -> PlayerViewController {
    let sb = UIStoryboard(name: "Player", bundle: Bundle.main)
    let vc = sb.instantiateViewController(withIdentifier: "PlayerID")
      as! PlayerViewController
    return vc
  }

  func showNowPlaying(entry: Entry) {
    guard let now = playbackControlProxy else {
      fatalError("need something to play")
    }

    assert(entry == now.entry)

    let vc = RootViewController.makeNowPlaying()

    vc.modalPresentationStyle = .custom
    vc.navigationDelegate = self

    playervc = vc

    // Resetting nowPlaying to trigger updates.
    playbackControlProxy = now

    // Using a setter to drive this important change is unfortunate. Turns out,
    // we could use callback now, for knowing when it’s done. Working around
    // the issue by installing a callback on the view controller.

    vc.entryChangedBlock = { [weak self] changedEntry in
      dispatchPrecondition(condition: .onQueue(.main))

      defer {
        vc.entryChangedBlock = nil
      }

      guard changedEntry == entry else {
        return
      }

      self?.playerTransition = PlayerTransitionDelegate()
      vc.transitioningDelegate = self?.playerTransition

      self?.present(vc, animated: true) {
        self?.playerTransition = nil
      }
    }

  }

  func hideNowPlaying(animated flag: Bool, completion: (() -> Void)?) {
    guard presentedViewController is PlayerViewController else {
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
      guard self.presentedViewController is AVPlayerViewController else {
        return
      }

      self.dismiss(animated: true) {
        os_log("dismissed video player", log: log, type: .debug)
      }
    }
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
    return presentedViewController is PlayerViewController
  }

  func playback(session: Playback, didChange state: PlaybackState) {
    switch state {
    case .paused(let entry, let error):
      defer {
        self.playbackControlProxy = SimplePlaybackState(entry: entry, isPlaying: false)
      }

      guard let er = error else {
        return
      }

      let content: (String, String)? = {
        switch er {
        case .log, .unknown:
          fatalError("unexpected error")
        case .unreachable:
          return (
            "You’re Offline",
            """
            Your episode – \(entry.title) – can’t be played because you are \
            not connected to the Internet.

            Turn off Airplane Mode or connect to Wi-Fi.
            """
          )
          //        case .unreachable:
          //          return (
          //            "Unreachable Content",
          //            """
          //            Your episode – \(entry.title) – can’t be played because it’s \
          //            currently unreachable.
          //
          //            Turn off Airplane Mode or connect to Wi-Fi.
          //            """
        //          )
        case .failed:
          return (
            "Playback Error",
            """
            Sorry, playback of your episode – \(entry.title) – failed.

            Try later or, if this happens repeatedly, remove it from your Queue.
            """
          )
        case .media:
          return (
            "Strange Data",
            """
            Your episode – \(entry.title) – cannot be played.

            It’s probably best to remove it from your Queue.
            """
          )
        case .surprising(let surprisingError):
          return (
            "Interesting Problem",
            """
            Your episode – \(entry.title) – is puzzling like that:
            \(surprisingError)
            """
          )
        case .session:
          return nil
        }
      }()

      guard let c = content else {
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



