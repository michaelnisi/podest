//
//  PlayerV1ViewController.swift
//  Podest
//
//  Created by Michael on 3/9/17.
//  Copyright © 2017 Michael Nisi. All rights reserved.
//

import UIKit
import FeedKit
import os.log

private let log = OSLog.disabled

final class PlayerV1ViewController: UIViewController, EntryPlayer {

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

  private var isAllowedToLoadImage = false

  private func loadImage(_ entry: Entry, heroSnapshot: UIView? =  nil, isDirect: Bool = false) {
    if heroSnapshot == nil {
      guard isAllowedToLoadImage else {
        return
      }
    }

    Podest.images.loadImage(
      representing: entry,
      into: heroImage,
      options: FKImageLoadingOptions(
        fallbackImage: UIImage(named: "Oval"),
        quality: .high,
        isDirect: isDirect
      )
    ) { [weak self] in
      heroSnapshot?.removeFromSuperview()
      self?.isAllowedToLoadImage = true
    }
  }

  /// A way to pass the hero snapshot from the player presentation animator,
  /// when the animation ended. That snapshot makes an appropriate placeholder,
  /// while we are loading the image.
  func animationEnded(_ hero: UIView) {
    guard let entry = self.entry else {
      return
    }

    view.addSubview(hero)

    loadImage(entry, heroSnapshot: hero, isDirect: true)
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

  private var needsUpdate = false

  private func update() {
    guard needsUpdate, viewIfLoaded != nil, let entry = self.entry else {
      return
    }
    
    // Before rendering forward and backward buttons, we need to make sure the
    // queue is up-to-date by skipping to our item.
    
    do {
      try Podest.userQueue.skip(to: entry)  
    } catch {
      // TODO: Trap here, this is a programming error
      os_log("queue error: %{public}@", log: log, type: .error, error as CVarArg)
    }
 
    configureView(entry)
    loadImage(entry)

    needsUpdate = false
  }

  var entry: Entry? {
    didSet {
      needsUpdate = entry != oldValue

      guard needsUpdate else {
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

  var swipeRight: UISwipeGestureRecognizer!
  var swipeDown: UISwipeGestureRecognizer!

  @objc func onSwipe(sender: UISwipeGestureRecognizer) {
    os_log("swipe received", log: log, type: .debug)

    switch sender.state {
    case .ended:
      navigationDelegate?.hideNowPlaying(animated: true, completion: nil)
      
    case .began, .changed, .cancelled, .failed, .possible:
      break
      
    @unknown default:
      fatalError("unknown case in switch: \(sender.state)")
    }
  }

  deinit {
    os_log("** deinit", log: log, type: .debug)
  }

  // MARK: - UIViewController

  private func addDismissingSwipe() -> UISwipeGestureRecognizer {
    let swipe = UISwipeGestureRecognizer(target: self, action: #selector(onSwipe))
    view.addGestureRecognizer(swipe)
    return swipe
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    swipeRight = addDismissingSwipe()
    swipeRight.direction = .right

    swipeDown = addDismissingSwipe()
    swipeDown.direction = .down

    titleButton.titleLabel?.numberOfLines = 2
    titleButton.titleLabel?.textAlignment = .center

    // Not rendering nicely in IB if applied there.
    subtitleLabel.numberOfLines = 2

    playSwitch.isExclusiveTouch = true
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    update()
  }

}

// MARK: - UIGestureRecognizerDelegate

extension PlayerV1ViewController: UIGestureRecognizerDelegate { 
  
  /// Returns `true` if we are vertically compact.
  var isLandscape: Bool {
    return traitCollection.containsTraits(
      in: UITraitCollection(verticalSizeClass: .compact))
  }
  
  func gestureRecognizer(
    _ gestureRecognizer: UIGestureRecognizer,
    shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
    switch gestureRecognizer {
    case is UISwipeGestureRecognizer:
      return !(otherGestureRecognizer is UIScreenEdgePanGestureRecognizer)
    default:
      return false
    }
  }
  
  func gestureRecognizer(
    _ gestureRecognizer: UIGestureRecognizer,
    shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
    return gestureRecognizer is UIScreenEdgePanGestureRecognizer
  }
}

// MARK: - HeroProviding

extension PlayerV1ViewController: HeroProviding {
  
  var hero: UIView? {
    return heroImage
  }
  
}


