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
      rootView = rootView.copy(isTransitionAnimating: isTransitionAnimating)
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
  
  private func setRootView(displaying image: Image, colors: PlayerView.Colors) {
    guard let view = makeView(image: image, colors: colors) else {
      return
    }
    
    rootView = view
  }
  
  private func handleImage(_ image: UIImage?) {
    guard let image = image else {
      return
    }
   
    setRootView(displaying: Image(uiImage: image), colors: makeColors(image: image))
  }
  
  private func loadImage(_ imaginable: Imaginable) {
    let size = CGSize(width: 600, height: 600)
    
    ImageRepository.shared
      .loadImage(representing: imaginable, at: size) { [weak self] image in
        self?.handleImage(image)
      }
  }

  var isPlaying: Bool = false {
    didSet {
      guard isPlaying != rootView.isPlaying else {
        return
      }
      
      rootView = rootView.copy(isPlaying: isPlaying)
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
  
  private func makePlayerItem(entry: Entry, image: Image, colors: PlayerView.Colors) -> PlayerItem {
    PlayerItem(
      title: entry.title,
      subtitle: entry.feedTitle ?? "Some Podcast",
      isPlaying: isPlaying
    )
  }
  
  private func makeView(image: Image, colors: PlayerView.Colors) -> PlayerView? {
    guard let entry = entry else {
      return nil
    }
    
    let item = makePlayerItem(entry: entry, image: image, colors: colors)
  
    return PlayerView(
      item: item,
      isTransitionAnimating: isTransitionAnimating,
      colors: colors,
      image: image,
      airPlayButton: AnyView(AirPlayButton()),
      delegate: self
    )
  }
  
  private func makeColors(image: UIImage) -> PlayerView.Colors {
    let base = image.averageColor
    
    return PlayerView.Colors(
      base: Color(base),
      dark: Color(base.darker(0.3)),
      light: Color(base.lighter(0.3))
    )
  }
  
  private static var emptyColors: PlayerView.Colors {
    PlayerView.Colors(base: .red, dark: .green, light: .blue)
  }
  
  private static var emptyPlayerItem: PlayerItem {
    PlayerItem(
      title: "",
      subtitle: "",
      isPlaying: false
    )
  }
  
  private static var emptyView: PlayerView {
    PlayerView(
      item: emptyPlayerItem,
      isTransitionAnimating: false,
      colors: emptyColors,
      image: Image("Oval"),
      airPlayButton: AnyView(AirPlayButton())
    )
  }
}
