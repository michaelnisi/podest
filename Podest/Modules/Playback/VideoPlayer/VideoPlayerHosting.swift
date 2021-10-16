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

import os.log
import AVKit

private let log = OSLog(subsystem: "ink.codes.podest", category: "VideoPlayer")

extension RootViewController: AVPlayerViewControllerDelegate {
  override var prefersStatusBarHidden: Bool {
    !traitCollection.containsTraits(in: UITraitCollection(horizontalSizeClass: .compact))
  }
  
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
      vc.allowsPictureInPicturePlayback = true
      vc.player = player
      vc.delegate = self

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

// MARK: - Picture in Picture Playback

extension RootViewController {
  func playerViewController(
    _ playerViewController: AVPlayerViewController,
    restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
  ) {
    guard playerViewController.player != nil else {
      return completionHandler(false)
    }
    
    present(playerViewController, animated: true) {
      completionHandler(false)
    }
  }
  
  func playerViewControllerDidStartPictureInPicture(_ playerViewController: AVPlayerViewController) {
    pictureInPicture = playerViewController
  }
}
