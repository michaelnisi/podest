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

/// A UIKit View Controller that manages the player user interface.
class PlayerV3ViewController: UIHostingController<PlayerView>, EntryPlayer, ObservableObject {

  var delegate: PlayerDelegate?
  var readyForPresentation: (() -> Void)?
  
  @ObservedObject private var model = PlayerV3ViewController.emptyModel
  
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
    rootView = PlayerView(
      model: model,
      airPlayButton: PlayerV3ViewController.airPlayButton,
      delegate: self
    )
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
    
    model.title = entry.title
    model.subtitle = entry.feedTitle ?? "Some Podcast"
    model.image = Image(uiImage: image)
    model.colors = makeColors(image: image)

    readyForPresentation?()
  }
  
  private func loadImage(_ imaginable: Imaginable) {
    let size = CGSize(width: 600, height: 600)
    
    ImageRepository.shared
      .loadImage(representing: imaginable, at: size) { [weak self] image in
        self?.update(with: image)
      }
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
}

// MARK: - PlayerHosting

extension PlayerV3ViewController: PlayerHosting {
  
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

extension PlayerV3ViewController {
  
  private func makeColors(image: UIImage) -> Colors {
    let base = image.averageColor
    
    return Colors(
      base: Color(base),
      dark: Color(base.darker(0.3)),
      light: Color(base.lighter(0.3))
    )
  }
  
  private static var emptyView: PlayerView {
    PlayerView(model: emptyModel, airPlayButton: airPlayButton)
  }
  
  private static var airPlayButton: AnyView {
    AnyView(AirPlayButton())
  }
  
  private static var emptyModel: PlayerView.Model {
    PlayerView.Model(
      title: "",
      subtitle: "",
      colors: Colors(base: .red, dark: .green, light: .blue),
      image: Image("Oval"),
      isPlaying: false,
      isForwardable: false,
      isBackwardable: false
    )
  }
}
