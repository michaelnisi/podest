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
import Podcasts

private let log = OSLog(subsystem: "ink.codes.podest", category: "player")

// MARK: - Players

extension RootViewController: Players {
  // Players explodes into following extensions:
}

// MARK: - ✨ New Player

extension RootViewController {
  func subscribe() {
    Podcasts.player.$state.sink { state in
      os_log(.debug, log: log, "** new player state: %{public}@", state.description)
      switch state {
      case let .mini(entry, player):
        self.minivc.configure(with: player, entry: entry)
      
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

// MARK: - Placing the Mini-Player

extension RootViewController {

  var isMiniPlayerHidden: Bool {
    minivc.viewIfLoaded?.isHidden ?? true
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

  func hideMiniPlayer(animated: Bool, completion: (() -> Void)? = nil) {
    os_log("hiding mini-player", log: log, type: .info)

    func done() {
      completion?()
    }

    guard animated else {
      miniPlayerTop.constant = 0
      miniPlayerBottom.constant = miniPlayerConstant
      miniPlayerLeading.constant = 0
      minivc.view.isHidden = true

      view.layoutIfNeeded()

      return done()
    }

    if miniPlayerTop.isActive {
      miniPlayerTop.constant = 0
      miniPlayerBottom.constant = miniPlayerConstant
      
      let anim = UIViewPropertyAnimator(duration: 0.3, curve: .linear) {
        self.view.layoutIfNeeded()
      }
      
      anim.addCompletion { position in
        self.miniPlayerLeading.constant = 0
        
        self.view.layoutIfNeeded()
        
        self.minivc.view.isHidden = true
        
        done()
      }
      
      anim.startAnimation()
    } else {
      miniPlayerLeading.constant = 0
      
      let anim = UIViewPropertyAnimator(duration: 0.3, curve: .linear) {
        self.view.layoutIfNeeded()
      }
      
      anim.addCompletion { position in
        self.miniPlayerTop.constant = 0
        self.miniPlayerBottom.constant = self.miniPlayerConstant
        
        self.view.layoutIfNeeded()
        
        self.minivc.view.isHidden = true
        
        done()
      }
      
      anim.startAnimation()
    }
  }

  func showMiniPlayer(animated: Bool, completion: (() -> Void)? = nil) {
    os_log("showing mini-player", log: log, type: .info)
    dispatchPrecondition(condition: .onQueue(.main))

    minivc.view.isHidden = false

    guard animated, !isPresentingVideo else {
      os_log("applying constant: %f", log: log, type: .info, miniPlayerConstant)

      miniPlayerLeading.constant = miniPlayerConstant - view.safeAreaInsets.right
      miniPlayerTop.constant = miniPlayerConstant
      miniPlayerBottom.constant = 0

      view.layoutIfNeeded()
      completion?()

      return
    }

    if miniPlayerTop.isActive {
      os_log("animating portrait", log: log, type: .info)

      miniPlayerLeading.constant = miniPlayerConstant
      miniPlayerTop.constant = miniPlayerConstant
      miniPlayerBottom.constant = 0
    } else {
      os_log("animating landscape", log: log, type: .info)

      miniPlayerTop.constant = miniPlayerConstant
      miniPlayerBottom.constant = 0
      miniPlayerLeading.constant = miniPlayerConstant - view.safeAreaInsets.right
    }

    let anim = UIViewPropertyAnimator(duration: 0.3, curve: .easeOut) {
      self.view.layoutIfNeeded()
    }

    anim.addCompletion { position in
      completion?()
    }

    anim.startAnimation()
  }
}


// MARK: - Presenting the Audio Player

extension RootViewController {

  private enum PlayerVersion {
    case v3
  }

  private func makeV3Player() -> EntryPlayer {
    let player = PlayerViewController()
    player.delegate = self
  
    return player
  }

  /// Returns a new player view controller of `version`.
  ///
  /// Within this factory function is the only place where concrete player view
  /// controller types (and identifiers) are allowed.
  private func makeNowPlaying(version: PlayerVersion) -> EntryPlayer {
    switch version {
    case .v3:
      return makeV3Player()
    }
  }
  
  func showNowPlaying(entry: Entry, animated: Bool, completion: (() -> Void)?) {
    os_log("showing now playing", log: log, type: .info)
    dispatchPrecondition(condition: .onQueue(.main))

    let vc = makeNowPlaying(version: .v3)
    vc.navigationDelegate = self

    playervc = vc
    let isPlaying = Podcasts.playback.isPlaying(guid: entry.guid)

    update(state: SimplePlaybackState(entry: entry, isPlaying: isPlaying, assetState: nil))
    
    vc.readyForPresentation = { [weak self] in
      self?.playerTransitioningDelegate = PlayerTransitioningDelegate(from: self!, to: vc)
      vc.readyForPresentation = nil
      vc.transitioningDelegate = self?.playerTransitioningDelegate
      
      self?.present(vc, interactiveDismissalType: .vertical) {
        completion?()
      }
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

// MARK: - Presenting the Video Player

extension RootViewController {

  var videoPlayer: AVPlayerViewController? {
    dispatchPrecondition(condition: .onQueue(.main))
    return presentedViewController as? AVPlayerViewController
  }

  var isPresentingVideo: Bool {
    videoPlayer != nil
  }

  func showVideo(player: AVPlayer, animated: Bool, completion: (() -> Void)? = nil) {
    guard videoPlayer == nil else {
      videoPlayer?.player = player

      return
    }

    hideMiniPlayer(animated: true) { [weak self] in
      let vc = AVPlayerViewController()

      vc.modalPresentationCapturesStatusBarAppearance = false
      vc.modalPresentationStyle = .fullScreen
      vc.updatesNowPlayingInfoCenter = false
      vc.allowsPictureInPicturePlayback = false
      vc.player = player

      self?.present(vc, animated: animated) {
        os_log("presented video player", log: log, type: .info)
        completion?()
      }
    }
  }

  func hideVideoPlayer(animated: Bool, completion: (() -> Void)? = nil) {
    dispatchPrecondition(condition: .onQueue(.main))

    guard isPresentingVideo else {
      completion?()

      return
    }

    dismiss(animated: animated) { [weak self] in
      os_log("dismissed video player", log: log, type: .info)
      self?.showMiniPlayer(animated: animated) {
        completion?()
      }
    }
  }

  var isPlayerPresented: Bool {
    isPresentingVideo || presentedViewController is EntryPlayer
  }
}

/// This extension hides the status bar in landscape.
extension AVPlayerViewController {

  override open var prefersStatusBarHidden: Bool {
    !traitCollection.containsTraits(in: UITraitCollection(horizontalSizeClass: .compact))
  }
}

// MARK: - Updating Playback Controls

extension RootViewController {

  /// Simplified playback state for playback UI.
  struct SimplePlaybackState {
    let entry: Entry
    let isPlaying: Bool
    let assetState: AssetState?
  }

  /// Updates all playback responding participants (players) with `state`.
  func update(state: SimplePlaybackState?) {
    dispatchPrecondition(condition: .onQueue(.main))

    var targets: [PlaybackResponding] = [self.qvc]
    if let t = self.playervc { targets.append(t) }

    guard let now = state else {
      for t in targets { t.dismiss() }
      return
    }

    for t in targets {
      let entry = now.entry

      now.isPlaying ? t.playing(entry: entry, asset: state?.assetState) : t.pausing(entry: entry, asset: state?.assetState)
    }
  }
}

// MARK: - Playback Handlers

extension RootViewController {
  
  func makeURL(url: URL) -> URL? {
    do {
      return try Podcasts.files.url(for: url)
    } catch {
      switch error {
      case FileProxyError.fileSizeRequired:
        os_log("** missing file size", log: log, type: .info)
        return url
      default:
        return nil
      }
    }
  }

  var isPresentingNowPlaying: Bool {
    presentedViewController is EntryPlayer
  }

  func playbackDidChange(session: PlaybackSession<Entry>, state: PlaybackState<Entry>) {
    os_log("playback state did change: %{public}@",
           log: log, type: .info, String(describing: state))

    switch state {
    case let .paused(entry, asset, error):
      DispatchQueue.main.async {
        defer {
          let s = SimplePlaybackState(entry: entry, isPlaying: false, assetState: asset)
          
          self.update(state: s)
        }

        // Guarding error existence is counter-intuitive, don’t you think?

        guard
          let er = error,
          let c = PlayerMessage.makeMessage(entry: entry, error: er) else {
          return
        }

        let alert = UIAlertController(
          title: c.0, message: c.1, preferredStyle: .alert
        )

        let ok = UIAlertAction(title: "OK", style: .default) { _ in
          alert.dismiss(animated: true)
        }

        alert.addAction(ok)

        // Now Playing or ourselves should be presenting the alert.

        let p = self.isPresentingNowPlaying ? self.presentedViewController : self

        p?.present(alert, animated: true, completion: nil)
      }

    case let .listening(entry, asset):
      DispatchQueue.main.async {
        let s = SimplePlaybackState(entry: entry, isPlaying: true, assetState: asset)

        self.update(state: s)
        
        self.hideVideoPlayer(animated: true) {
          self.showMiniPlayer(animated: true)
        }
      }

    case .preparing(let entry, let shouldPlay):
      DispatchQueue.main.async {
        let s = SimplePlaybackState(entry: entry, isPlaying: shouldPlay, assetState: nil)

        self.update(state: s)

        guard !self.isPlayerPresented, !self.isPresentingVideo else {
          return
        }

        self.showMiniPlayer(animated: true)
      }

    case .viewing(let entry, let player):
      DispatchQueue.main.async {
        let s = SimplePlaybackState(entry: entry, isPlaying: true, assetState: nil)

        self.update(state: s)

        if !self.isPresentingNowPlaying, !self.isPresentingStore {
          self.showVideo(player: player, animated: true)
        }
      }

    case .inactive(let error):
      if let er = error {
        os_log("session error: %{public}@", log: log, type: .error, er as CVarArg)
        fatalError(String(describing: er))
      }
    }
  }

  func nextItem() -> Entry? {
    Podcasts.userQueue.next()
  }

  func previousItem() -> Entry?  {
    Podcasts.userQueue.previous()
  }
  
  func installPlaybackHandlers() {
    Podcasts.playback.makeURL = makeURL
    Podcasts.playback.onChange = playbackDidChange
    Podcasts.playback.nextItem = nextItem
    Podcasts.playback.previousItem = previousItem
  }
  
  func uninstallPlaybackHandlers() {
    Podcasts.playback.makeURL = nil
    Podcasts.playback.onChange = nil
    Podcasts.playback.nextItem = nil
    Podcasts.playback.previousItem = nil
  }
}

// MARK: - PlayerDelegate

extension RootViewController: PlayerDelegate {

  func forward() {
    Podcasts.playback.forward()
  }
  
  func backward() {
    Podcasts.playback.backward()
  }
  
  func resumePlayback(entry: Entry?) {
    Podcasts.playback.resume(entry, from: nil)
  }
  
  func pausePlayback() {
    Podcasts.playback.pause(nil, at: nil)
  }
}
