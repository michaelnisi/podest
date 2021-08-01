//
//  VideoPlayerHosting.swift
//  Podest
//
//  Created by Michael Nisi on 16.06.21.
//  Copyright © 2021 Michael Nisi. All rights reserved.
//

import os.log
import AVKit

private let log = OSLog(subsystem: "ink.codes.podest", category: "VideoPlayer")

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
    isPresentingVideo || isPresentingNowPlaying
  }
}

extension AVPlayerViewController {
  override open var prefersStatusBarHidden: Bool {
    !traitCollection.containsTraits(in: UITraitCollection(horizontalSizeClass: .compact))
  }
}
