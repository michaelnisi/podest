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
  
  override init?(coder aDecoder: NSCoder, rootView: PlayerView) {
    super.init(coder: aDecoder, rootView: rootView)
  }
    
  @objc required dynamic init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder, rootView: PlayerView())
  }
    
  // MARK: - UIViewController

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
      guard oldValue != entry else {
        return
      }
      
      configure(
        title: entry?.title ?? "",
        subtitle: entry?.feedTitle ?? ""
      )
    }
  }
  
  var imaginable: Imaginable?
  
  func configure(title: String, subtitle: String, imaginable: Imaginable? = nil) {
    self.imaginable = imaginable
    
    guard let imaginable = self.entry ?? self.imaginable else {
      return
    }
    
    let size = CGSize(width: 600, height: 600)
    
    ImageRepository.shared
      .loadImage(representing: imaginable, at: size) { image in
        self.rootView.configure(title: title, subtitle: subtitle, image: image!)
      }

  }

  var isPlaying: Bool = false {
    didSet {
      guard oldValue != isPlaying else {
        return
      }
      
      rootView.configure(isPlaying: isPlaying)
    }
  }
  
  var isForwardable = false
  var isBackwardable = false
}
