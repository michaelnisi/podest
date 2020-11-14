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

class PlayerV3ViewController: UIHostingController<PlayerUIView>, EntryPlayer {

  override init?(coder aDecoder: NSCoder, rootView: PlayerUIView) {
    super.init(coder: aDecoder, rootView: rootView)
  }
    
  @objc required dynamic init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder, rootView: PlayerUIView())
  }
    
  // MARK: - UIViewController
  
  override func viewWillAppear(_ animated: Bool) {
    rootView.install(
      nextHandler: {
        Podest.playback.forward()
      },
      closeHandler: { [weak self] in
        self?.navigationDelegate?.hideNowPlaying(animated: true, completion: nil)
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
  
  // TODO: -
  
  var isPlaying = false
  var isForwardable = false
  var isBackwardable = false
}
