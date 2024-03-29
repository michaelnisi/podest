//===----------------------------------------------------------------------===//
//
// This source file is part of the Podest open source project
//
// Copyright (c) 2021 Michael Nisi and collaborators
// Licensed under MIT License
//
// See https://github.com/michaelnisi/podest/blob/main/LICENSE for license information
//
//===----------------------------------------------------------------------===//

import AVFoundation
import AVKit
import UIKit
import os.log
import Ola
import Epic
import FeedKit

private let log = OSLog(subsystem: "ink.codes.podest", category: "player")

/// The minimized AV player.
final class MiniPlayerViewController: UIViewController, Navigator {
  private (set) var entry: Entry?
  private var model: Epic.MiniPlayer?
  private var miniPlayerContext: AnyObject?
  private var needsUpdate = false
  var navigationDelegate: ViewControllers?
  var swipe: UISwipeGestureRecognizer!
  @IBOutlet var titleLabel: UILabel!
  @IBOutlet var hero: UIImageView!
  @IBOutlet var playSwitch: PlaySwitch!
  /// A temporary touch down feedback view.
  var backdrop: UIView?
  weak var fx: UIVisualEffectView!
}

extension MiniPlayerViewController {
  @IBAction func onPlaySwitchValueChanged(_ sender: PlaySwitch) {
    sender.isOn ? model?.play() : model?.pause()
  }
  
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
    swipe.direction = .up
    view.addGestureRecognizer(swipe)

    let edgePan = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(onEdgePan))
    edgePan.edges = .bottom
    edgePan.delegate = self
    view.addGestureRecognizer(edgePan)
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    installMiniPlayerContextMenu()
  }
}

private extension MiniPlayerViewController {
  func insertEffect() {
    guard fx == nil, let sibling = titleLabel else {
      os_log("ignoring visual effect", log: log, type: .error)
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
  
  func removeEffect() {
    fx.removeFromSuperview()
  }
}

extension MiniPlayerViewController {
  func configure(with model: Epic.MiniPlayer, entry: Entry) {
    self.model = model
    self.entry = entry
    
    titleLabel.text = model.item.title
    hero.image = model.item.image
    playSwitch.isOn = model.playback == .playing 
  }
}

// MARK: - UIGestureRecognizerDelegate

extension MiniPlayerViewController: UIGestureRecognizerDelegate {
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

private extension MiniPlayerViewController {
  func makeMatte() -> UIView {
    let v = UIView(frame: fx.contentView.frame)

    v.backgroundColor = .systemFill

    return v
  }

  func showMatte() {
    let matte = makeMatte()

    fx.contentView.addSubview(matte)

    self.backdrop = matte
  }

  func hideMatte() {
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

      guard !isPlaySwitchHit(),
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
      
      showPlayer()

    case .possible, .changed:
      break

    @unknown default:
      fatalError("unknown case in switch: \(sender.state)")
    }
  }
}

// MARK: - UISwipeGestureRecognizer

private extension MiniPlayerViewController {
  @objc func onSwipe(sender: UISwipeGestureRecognizer) {
    os_log("swipe received", log: log, type: .info)

    guard !playSwitch.isTracking else {
      return
    }

    switch sender.state {
    case .ended:
      showPlayer()
    
    case .began, .changed, .cancelled, .failed, .possible:
      break

    @unknown default:
      fatalError("unknown case in switch: \(sender.state)")
    }
  }
}

// MARK: - UIScreenEdgePanGestureRecognizer

extension MiniPlayerViewController {
  @objc func onEdgePan(sender: UIScreenEdgePanGestureRecognizer) {
    os_log("edge pan received", log: log, type: .info)
  }
}

// MARK: - Epic

extension MiniPlayerViewController {
  func showPlayer() {
    model?.showPlayer()
  }
}
