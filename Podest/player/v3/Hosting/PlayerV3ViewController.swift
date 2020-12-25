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
import Epic

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
    super.init(coder: aDecoder, rootView: PlayerV3ViewController.emptyView)
  }
    
  // MARK: - UIViewController
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    modalPresentationStyle = .fullScreen
  }
  
  private var isTransitionAnimating = false {
    didSet {
      setRootView(displaying: rootView.image)
    }
  }
  
  override func viewWillTransition(
    to size: CGSize,
    with coordinator: UIViewControllerTransitionCoordinator
  ) {
    super.viewWillTransition(to: size, with: coordinator)
    
    isTransitionAnimating = true
    
    coordinator.animate { [weak self] _ in
      self?.isTransitionAnimating = false
    }
  }

  // MARK: - EntryPlayer
  
  var navigationDelegate: ViewControllers?
  
  var entry: Entry? {
    didSet {
      guard entry != oldValue, let entry = entry else {
        return
      }
      
      loadImage(entry)
    }
  }
  
  private func setRootView(displaying image: UIImage?) {
    guard let view = makeView(image: image) else {
      return
    }
    
    rootView = view
  }
  
  private func loadImage(_ imaginable: Imaginable) {
    let size = CGSize(width: 600, height: 600)
    
    ImageRepository.shared
      .loadImage(representing: imaginable, at: size) { [weak self] image in
        self?.setRootView(displaying: image)
      }
  }

  var isPlaying: Bool = false {
    didSet {
      guard isPlaying != oldValue else {
        return
      }
      
      setRootView(displaying: rootView.image)
    }
  }
  
  var isForwardable = false
  var isBackwardable = false
}

// MARK: - PlayerHosting

extension PlayerV3ViewController: PlayerHosting {
  
  func play() {
    delegate?.resumePlayback(entry: entry)
  }
  
  func forward() {
    delegate?.forward()
  }
  
  func backgward() {
    delegate?.backward()
  }
  
  func close() {
    navigationDelegate?.hideNowPlaying(animated: true, completion: nil)
  }
  
  func pause() {
    delegate?.pausePlayback()
  }
}

// MARK: - Factory

extension PlayerV3ViewController {
  
  private func makeViewModel(entry: Entry, image: UIImage) -> PlayerView.Model {
    PlayerView.Model(
      title: entry.title,
      subtitle: entry.feedTitle ?? "Some Podcast",
      image: image,
      isPlaying: isPlaying,
      isTransitionAnimating: isTransitionAnimating
    )
  }
  
  private func makeView(image: UIImage?) -> PlayerView? {
    guard let entry = entry, let image = image else {
      return nil
    }
    
    let model = makeViewModel(entry: entry, image: image)

    return PlayerView(model: model, delegate: self)
  }
  
  private static var emptyViewModel: PlayerView.Model {
    PlayerView.Model(
      title: "",
      subtitle: "",
      image: UIImage(named: "Oval")!,
      isPlaying: false,
      isTransitionAnimating: false
    )
  }
  
  private static var emptyView: PlayerView {
    PlayerView(model: emptyViewModel)
  }
}
