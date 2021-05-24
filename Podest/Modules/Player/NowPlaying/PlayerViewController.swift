//
//  PlayerViewController.swift
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
import InsetPresentation
import Podcasts
import Combine

protocol PlayerDelegate {
  func forward()
  func backward()
  func resumePlayback(entry: Entry?)
  func pausePlayback()
}

/// A UIKit View Controller that manages the player user interface.
class PlayerViewController: UIHostingController<PlayerView>, EntryPlayer, ObservableObject, InsetPresentable {
  var transitionController: UIViewControllerTransitioningDelegate?

  var delegate: PlayerDelegate?
  var readyForPresentation: (() -> Void)?
  private var subscriptions = Set<AnyCancellable>()
  
  private var model = Epic.Player()
  
  init() {
    super.init(rootView: PlayerView(
      model: model,
      airPlayButton: PlayerViewController.airPlayButton
    ))
    
    rootView.delegate = self
  }
  
  @objc required dynamic init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
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
  
  private func update(with image: UIImage?) {
    guard let entry = entry, let image = image else {
      return
    }

    model.item = Player.Item(
      title: entry.title,
      subtitle: entry.feedTitle ?? "Some Podcast",
      colors: Colors(image: image),
      image: Image(uiImage: image)
    )
    
    readyForPresentation?()
  }
  
  private func loadImage(_ imaginable: Imaginable) {
    let size = CGSize(width: 600, height: 600)
    
    ImageRepository.shared
      .loadImage(representing: imaginable, at: size)
      .replaceError(with: UIImage())
      .sink { [unowned self] image in
        self.update(with: image)
      }
      .store(in: &subscriptions)
  }

  var isPlaying: Bool = false {
    didSet { model.isPlaying = isPlaying }
  }
  
  var isBackwardable: Bool = true {
    didSet { model.isBackwardable = isBackwardable }
  }
  
  var isForwardable: Bool = true {
    didSet { model.isForwardable = isForwardable }
  }
  
  var asset: AssetState? {
    didSet {
      guard let asset = asset else {
        model.trackTime = 0
        return
      }
      
      model.trackTime = asset.time * 100 / asset.duration
    }
  }
}

// MARK: - PlayerHosting

extension PlayerViewController: PlayerHosting {
  
  func play() {
    delegate?.resumePlayback(entry: entry)
  }
  
  func forward() {
    delegate?.forward()
  }
  
  func backward() {
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

extension PlayerViewController {
  private static var emptyView: PlayerView {
    PlayerView(model: Epic.Player(), airPlayButton: airPlayButton)
  }
  
  private static var airPlayButton: AnyView {
    AnyView(AirPlayButton())
  }
}
