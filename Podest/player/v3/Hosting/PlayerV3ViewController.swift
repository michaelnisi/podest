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
import Playback

protocol PlayerDelegate {
  func forward()
  func backward()
  func resumePlayback(entry: Entry?)
  func pausePlayback()
}

class PlayerV3ViewController: UIHostingController<PlayerView>, EntryPlayer, ObservableObject {

  var delegate: PlayerDelegate?
  
  var nowPlaying: NowPlaying {
    rootView.model
  }

  override init?(coder aDecoder: NSCoder, rootView: PlayerView) {
    super.init(coder: aDecoder, rootView: rootView)
  }
    
  @objc required dynamic init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder, rootView: PlayerView())
  }
    
  // MARK: - UIViewController
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    modalPresentationStyle = .fullScreen
  }

  override func viewWillAppear(_ animated: Bool) {
    rootView.install(
      playHandler: { [weak self] in
        self?.delegate?.resumePlayback(entry: self?.entry)
      },
      forwardHandler: { [weak self] in
        self?.delegate?.forward()
      },
      backwardHandler: { [weak self] in
        self?.delegate?.backward()
      },
      closeHandler: { [weak self] in
        self?.navigationDelegate?.hideNowPlaying(animated: true, completion: nil)
      },
      pauseHandler: { [weak self] in
        self?.delegate?.pausePlayback()
      }
    )
  }
  
  // MARK: - EntryPlayer
  
  var navigationDelegate: ViewControllers?
  
  var entry: Entry? {
    didSet {
      guard entry != oldValue, let entry = entry else {
        return
      }
      
      nowPlaying.title = entry.title
      nowPlaying.subtitle = entry.feedTitle ?? ""
      loadImage(entry)
    }
  }
  
  private func loadImage(_ imaginable: Imaginable) {
    let size = CGSize(width: 600, height: 600)
    
    ImageRepository.shared
      .loadImage(representing: imaginable, at: size) { [weak self] image in
        self?.nowPlaying.image = image!
      }
  }

  var isPlaying: Bool = false {
    didSet {
      guard isPlaying != oldValue else {
        return
      }
      
      rootView.info.isPlaying = isPlaying
    }
  }
  
  var isForwardable = false
  var isBackwardable = false
}
