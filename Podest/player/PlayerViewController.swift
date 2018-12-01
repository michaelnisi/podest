//
//  PlayerViewController.swift
//  Podest
//
//  Created by Michael on 3/9/17.
//  Copyright © 2017 Michael Nisi. All rights reserved.
//

import UIKit
import FeedKit
import os.log

private let log = OSLog.disabled

class PlayerViewController: UIViewController,
Navigator, PlaybackControlDelegate {

  // MARK: Outlets

  @IBOutlet weak var doneButton: UIButton!
  @IBOutlet weak var heroImage: UIImageView!
  @IBOutlet weak var titleButton: UIButton!
  @IBOutlet weak var subtitleLabel: UILabel!
  @IBOutlet weak var playSwitch: PlaySwitch!
  @IBOutlet weak var backwardButton: UIButton!
  @IBOutlet weak var forwardButton: UIButton!
  @IBOutlet weak var episode: UIStackView!
  @IBOutlet weak var container: UIStackView!
  
  // MARK: - Actions

  @IBAction func doneTouchUpInside(_ sender: Any) {
    navigationDelegate?.hideNowPlaying(animated: true, completion: nil)
  }

  @IBAction func playSwitchValueChanged(_ sender: PlaySwitch) {
    guard let entry = self.entry else {
      return
    }

    guard sender.isOn else {
      navigationDelegate?.pause()
      return
    }

    navigationDelegate?.play(entry)
  }

  @IBAction func backwardTouchUpInside(_ sender: Any) {
    Podest.playback.backward()
  }

  @IBAction func forwardTouchUpInside(_ sender: Any) {
    Podest.playback.forward()
  }

  @IBAction func titleTouchUpInside(_ sender: Any) {
    navigationDelegate?.show(entry: entry!)
  }

  // MARK: - Configuration

  private func loadImage(_ entry: Entry) {
    Podest.images.loadImage(
      representing: entry,
      into: heroImage,
      options: FKImageLoadingOptions(
        fallbackImage: UIImage.init(named: "Oval"),
        quality: .high,
        isDirect: false
      )
    ) { [weak self] in
      self?.heroSnapshot?.removeFromSuperview()
    }
  }

  private var heroSnapshot: UIView?

  /// A way to pass the hero snapshot from the player presentation animator,
  /// when the animation ended. That snapshot makes an appropriate placeholder,
  /// while we are loading the image.
  func animationEnded(_ hero: UIView) {
    guard let entry = self.entry else {
      return
    }

    view.addSubview(hero)
    heroSnapshot = hero

    loadImage(entry)
  }

  private func configureView(_ entry: Entry) {
    UIView.performWithoutAnimation {
      titleButton.setTitle(entry.title, for: .normal)
    }

    subtitleLabel.text = entry.feedTitle

    playSwitch.isOn = isPlaying
    forwardButton.isEnabled = Podest.userQueue.isForwardable
    backwardButton.isEnabled = Podest.userQueue.isBackwardable
  }

  private func update() {
    guard viewIfLoaded != nil, let entry = self.entry else {
      return
    }
    
    configureView(entry)
    loadImage(entry)
  }

  var entry: Entry? {
    didSet {
      guard entry != oldValue else {
        return
      }

      update()
      entryChangedBlock?(entry)
    }
  }

  /// The block to execute for entry changes.
  var entryChangedBlock: ((Entry?) -> Void)?

  var isPlaying: Bool = false {
    didSet {
      playSwitch?.isOn = isPlaying
    }
  }
  
  var isBackwardable: Bool = true {
    didSet {
      backwardButton?.isEnabled = isBackwardable
    }
  }
  
  var isForwardable: Bool = true {
    didSet {
      forwardButton?.isEnabled = isForwardable
    }
  }

  // MARK: - Navigator

  var navigationDelegate: ViewControllers?

  // MARK: - Swiping

  var swipe: UISwipeGestureRecognizer!

  @objc func onSwipe(sender: UISwipeGestureRecognizer) {
    os_log("swipe received", log: log, type: .debug)

    switch sender.state {
    case .ended:
      navigationDelegate?.hideNowPlaying(animated: true, completion: nil)
    case .began, .changed, .cancelled, .failed, .possible:
      break
    }
  }

  private var isLandscape: Bool {
    return traitCollection.containsTraits(
      in: UITraitCollection(verticalSizeClass: .compact))
  }

  private func configureSwipe() {
    swipe.direction = isLandscape ? .right : .down
  }

  // MARK: - UIViewController

  override func viewDidLoad() {
    super.viewDidLoad()

    titleButton.titleLabel?.numberOfLines = 2
    titleButton.titleLabel?.textAlignment = .center

    // Not rendering nicely in IB if applied there.
    subtitleLabel.numberOfLines = 2

    playSwitch.isExclusiveTouch = true

    swipe = UISwipeGestureRecognizer(target: self, action: #selector(onSwipe))
    view.addGestureRecognizer(swipe)
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    update()
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    update()
  }

  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    configureSwipe()
  }

  // MARK: - UIStateRestoring

  override func encodeRestorableState(with coder: NSCoder) {
    super.encodeRestorableState(with: coder)
  }

  override func decodeRestorableState(with coder: NSCoder) {
    super.decodeRestorableState(with: coder)
  }

}


