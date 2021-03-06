//
//  MiniPlayerController.swift
//  Podest
//
//  Created by Michael on 3/20/17.
//  Copyright © 2017 Michael Nisi. All rights reserved.
//

import AVFoundation
import AVKit
import FeedKit
import Foundation
import UIKit
import os.log
import Playback
import Ola

private let log = OSLog(subsystem: "ink.codes.podest", category: "player")

/// The minimized AV player.
final class MiniPlayerController: UIViewController, Navigator, PlaybackControlDelegate {

  var isForwardable: Bool = false
  var isBackwardable: Bool = false

  private struct FetchEntryResult {
    let entry: Entry?
    let error: Error?
  }

  private func fetchEntry(at locator: EntryLocator) {
    let locators = [locator.including]
    var result: FetchEntryResult?
    let animated = !isRestoring

    Podest.browser.entries(locators, entriesBlock: {
      error, entries in
      result = FetchEntryResult(entry: entries.first, error: error)
    }) { [weak self] error in
      guard error == nil, result?.error == nil, let entry = result?.entry else {
        let er = result?.error ?? error ??
          FeedKitError.missingEntries(locators: locators)

        os_log("could not fetch entry: %{public}@",
               log: log, type: .error, er as CVarArg)

        // We are but a mini-player, we don’t know what to do.

        return DispatchQueue.main.async { [weak self] in
          if let me = self {
            me.navigationDelegate?.viewController(me, error: er)
          }
        }
      }

      DispatchQueue.main.async { [weak self] in
        self?.entry = entry

        self?.navigationDelegate?
          .showMiniPlayer(animated: animated, completion: nil)

        self?.isRestoring = false
      }
    }
  }

  var locator: EntryLocator? {
    didSet {
      guard let loc = locator, loc != oldValue, loc.guid != entry?.guid else {
        return
      }
      fetchEntry(at: loc)
    }
  }

  private var needsUpdate = false {
    didSet {
      guard needsUpdate else {
        return
      }
      
      DispatchQueue.main.async { [weak self] in
        self?.viewIfLoaded?.setNeedsLayout()
      }
    }
  }

  private var renderedGUID: EntryGUID?

  /// The current playback entry, playing or paused. If we intend to set this
  /// from different threads, this needs to be serialized. Setting this may also
  /// enqueue the entry.
  var entry: Entry? {
    didSet {
      needsUpdate = self.entry != oldValue || self.entry?.guid != renderedGUID

      guard needsUpdate, let entry = self.entry else {
        return
      }

      locator = EntryLocator(entry: entry)
      view.isHidden = false

      Podest.userQueue.enqueue(entries: [entry]) { enqueued, error in
        if let er = error {
          os_log("enqueue warning: %{public}@", 
                 log: log, type: .info, er as CVarArg)
        }
      }
    }
  }

  internal var isPlaying = false {
    didSet {
      // Doing this directly for simpler view updating.
      playSwitch.isOn = isPlaying
    }
  }

  // MARK: - UIStateRestoring

  override func encodeRestorableState(with coder: NSCoder) {
    super.encodeRestorableState(with: coder)

    guard locator != nil else {
      let keys = ["guid", "url", "since", "title"]
      for key in keys {
        coder.encode(nil, forKey: key)
      }
      return
    }

    locator?.encode(with: coder)
  }

  private var isRestoring = false

  override func decodeRestorableState(with coder: NSCoder) {
    isRestoring = true
    locator = EntryLocator(coder: coder)
    
    super.decodeRestorableState(with: coder)
  }
  
  // MARK: - ContextMenuInteraction
  
  private var miniPlayerContext: AnyObject?

  // MARK: - Navigator

  var navigationDelegate: ViewControllers?

  var swipe: UISwipeGestureRecognizer!

  // MARK: - Outlets and Actions

  @IBOutlet var titleLabel: UILabel!

  @IBOutlet var hero: UIImageView!

  @IBOutlet var playSwitch: PlaySwitch!

  /// A temporary touch down feedback view.
  var backdrop: UIView?

  @IBAction func onPlaySwitchValueChanged(_ sender: PlaySwitch) {
    guard let entry = self.entry else {
      return
    }

    if sender.isOn {
      navigationDelegate?.play(entry)
    } else {
      navigationDelegate?.pause()
    }
  }
  
  // MARK: - FX

  weak var fx: UIVisualEffectView!

  private func insertEffect() {
    guard fx == nil, let sibling = titleLabel else {
      os_log("** ignoring visual effect", log: log, type: .error)
      return
    }
    
    guard #available(iOS 13.0, *) else {
      let blur = UIBlurEffect(style: .light)
      let blurView = UIVisualEffectView(effect: blur)
      blurView.frame = view.frame
      blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

      let vibrancy = UIVibrancyEffect(blurEffect: blur)
      let vibrancyView = UIVisualEffectView(effect: vibrancy)
      vibrancyView.frame = view.frame

      blurView.contentView.addSubview(vibrancyView)
      view.insertSubview(blurView, belowSubview: sibling)

      self.fx = blurView

      return
    }

    let blur = UIBlurEffect(style: .systemChromeMaterial)
    let blurView = UIVisualEffectView(effect: blur)
    blurView.frame = view.frame
    blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

    let vibrancy = UIVibrancyEffect(blurEffect: blur, style: .label)
    let vibrancyView = UIVisualEffectView(effect: vibrancy)
    vibrancyView.frame = view.frame
    vibrancyView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

    blurView.contentView.addSubview(vibrancyView)
    view.insertSubview(blurView, belowSubview: sibling)

    self.fx = blurView
  }
  
  private func removeEffect() {
    fx.removeFromSuperview()
  }

  // MARK: - UIViewController
  
  @available(iOS 13.0, *)
  private func installMiniPlayerContextMenu() {
    (miniPlayerContext as? MiniPlayerContextMenuInteraction)?.invalidate()
    
    let context = MiniPlayerContextMenuInteraction(viewController: self)
    
    self.miniPlayerContext = context.install()
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    view.isHidden = true

    view.sendSubviewToBack(titleLabel)
    insertEffect()

    playSwitch.isExclusiveTouch = true

    let touchDown = UILongPressGestureRecognizer(
      target: self, action: #selector(onTouchDown))
    touchDown.minimumPressDuration = 0
    touchDown.cancelsTouchesInView = false
    view.addGestureRecognizer(touchDown)
    
    // TODO: Tap UITapGestureRecognizer

    swipe = UISwipeGestureRecognizer(target: self, action: #selector(onSwipe))
    swipe.delegate = self
    view.addGestureRecognizer(swipe)

    let edgePan = UIScreenEdgePanGestureRecognizer(
      target: self, action: #selector(onEdgePan))
    edgePan.edges = .bottom
    edgePan.delegate = self
    view.addGestureRecognizer(edgePan)
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    configureSwipe()

    needsUpdate = true
  }

  private func loadImage(representing entry: Entry) {
    let opts = FKImageLoadingOptions(
      fallbackImage: UIImage(named: "Oval"),
      quality: .high,
      isDirect: true
    )

    Podest.images.loadImage(representing: entry, into: hero, options: opts)
  }

  override func viewWillLayoutSubviews() {
    defer {
      super.viewWillLayoutSubviews()
    }

    configureSwipe()

    guard needsUpdate, let entry = self.entry else {
      return
    }

    titleLabel.text = entry.title
    playSwitch.isOn = isPlaying
    renderedGUID = entry.guid

    loadImage(representing: entry)
    
    if #available(iOS 13.0, *) {
      installMiniPlayerContextMenu()
    }

    needsUpdate = false
  }
}

// MARK: - UIGestureRecognizerDelegate

extension MiniPlayerController: UIGestureRecognizerDelegate {

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

// MARK: - UITapGestureRecognizer

extension MiniPlayerController {

  private func makeMatte() -> UIView {
    let v = UIView(frame: fx.contentView.frame)

    if #available(iOS 13.0, *) {
      v.backgroundColor = .systemFill
    } else {
      v.backgroundColor = .lightGray
    }

    return v
  }

  private func showMatte() {
    let matte = makeMatte()

    fx.contentView.addSubview(matte)

    self.backdrop = matte
  }

  private func hideMatte() {
    backdrop?.removeFromSuperview()
  }

  @objc func onTouchDown(sender: UILongPressGestureRecognizer) {
    func isPlaySwitchHit() -> Bool {
      let p = sender.location(in: view)
      return view!.hitTest(p, with: nil) == playSwitch
    }

    switch sender.state {
    case .began:
      break

    case .cancelled, .failed:
      hideMatte()

    case .ended:
      hideMatte()

      guard let entry = self.entry,
        !isPlaySwitchHit(),
        !playSwitch.isTracking,
        !playSwitch.isCancelled else {
        playSwitch.isCancelled = false
        return
      }

      let p = sender.location(in: view)
      let insets = UIEdgeInsets(top: 5, left: 5, bottom: 10, right: 10)
      let hitArea = view.frame.inset(by: insets)

      guard hitArea.contains(p) else {
        return
      }

      navigationDelegate?.showNowPlaying(entry: entry, animated: true, completion: nil)

    case .possible, .changed:
      break

    @unknown default:
      fatalError("unknown case in switch: \(sender.state)")
    }
  }
}

// MARK: - UISwipeGestureRecognizer

extension MiniPlayerController {

  @objc func onSwipe(sender: UISwipeGestureRecognizer) {
    os_log("swipe received", log: log, type: .info)

    guard let entry = self.entry, !playSwitch.isTracking else {
      return
    }

    switch sender.state {
    case .ended:
      navigationDelegate?.showNowPlaying(entry: entry, animated: true, completion: nil)

    case .began, .changed, .cancelled, .failed, .possible:
      break

    @unknown default:
      fatalError("unknown case in switch: \(sender.state)")
    }
  }

  /// Configures swipe for device orientation.
  private func configureSwipe() {
    swipe.direction = isLandscape ? .left : .up
  }
}

// MARK: - UIScreenEdgePanGestureRecognizer

extension MiniPlayerController {

  @objc func onEdgePan(sender: UIScreenEdgePanGestureRecognizer) {
    os_log("edge pan received", log: log, type: .info)
  }
}
