//
//  PlayerV3ViewController.swift
//  Podest
//
//  Created by Michael Nisi on 05.09.20.
//  Copyright © 2020 Michael Nisi. All rights reserved.
//

import UIKit
import SwiftUI
import FeedKit

class PlayerV3ViewController: UIHostingController<PlayerView>, EntryPlayer {

  override init?(coder aDecoder: NSCoder, rootView: PlayerView) {
    super.init(coder: aDecoder, rootView: rootView)
  }
    
  @objc required dynamic init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder, rootView: PlayerView())
  }
    
  // MARK: - UIViewController
  
  override func viewWillAppear(_ animated: Bool) {
    rootView.install(
      playHandler: { entry in
        Podest.playback.resume(entry: entry)
      },
      forwardHandler: {
        Podest.playback.forward()
      },
      backwardHandler: {
        Podest.playback.backward()
      },
      closeHandler: { [weak self] in
        self?.navigationDelegate?.hideNowPlaying(animated: true, completion: nil)
      },
      pauseHandler: {
        Podest.playback.pause(entry: nil)
      }
    )
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    rootView.uninstall()
  }
  
  // MARK: - EntryPlayer
  
  var navigationDelegate: ViewControllers?
  
  var entry: Entry? {
    didSet {
      rootView.configure(with: entry)
    }
  }

  var isPlaying: Bool {
    get { rootView.isPlaying }
    set { rootView.isPlaying = newValue }
  }
  
  var isForwardable = false
  var isBackwardable = false
}
