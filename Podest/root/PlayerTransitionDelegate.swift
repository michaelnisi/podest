//
//  PlayerTransitionDelegate.swift
//  Podest
//
//  Created by Michael Nisi on 13.03.18.
//  Copyright © 2018 Michael Nisi. All rights reserved.
//

import UIKit
import os.log

// MARK: - PlayerPresentationController

/// Manages the presentation of the player view controller.
///
/// Does nothing at the moment, all animating in the two player animators.
///
/// - PlayerDismissalAnimator
/// - PlayerPresentationAnimator
class PlayerPresentationController: UIPresentationController {}

// MARK: - PlayerAnimator

/// A base class, providing common functions, for the animators in the player
/// presentation.
class PlayerAnimator: NSObject {

  let duration: TimeInterval
  let log: OSLog

  init(duration: TimeInterval = 0.3, log: OSLog = .disabled) {
    self.duration = duration
    self.log = log
  }

  /// Returns the hero it finds in `viewController`.
  static func findHero(viewController: UIViewController) -> UIView? {
    switch viewController {
    case let vc as PlayerViewController:
      return vc.heroImage
    case let vc as RootViewController:
      guard !vc.isMiniPlayerHidden else {
        return nil
      }
      return vc.minivc.hero
    default:
      return nil
    }
  }

  /// Adds a snaphot of the hero in the from view controller to the container.
  static func addHero(
    using transitionContext: UIViewControllerContextTransitioning) -> UIView? {
    guard
      let vc = transitionContext.viewController(forKey: .from),
      let source = findHero(viewController: vc) else {
      return nil
    }

    let cv = transitionContext.containerView

    // Would prefer using view, but lost patience converting coordinates.
    // let view = transitionContext.view(forKey: .from)!

    let center = source.superview!.convert(source.center, to: cv)
    let width = source.bounds.width

    let target = source.snapshotView(afterScreenUpdates: false)!

    target.bounds = CGRect(x: 0, y: 0, width: width, height: width)
    target.center = center

    cv.addSubview(target)

    return target
  }

  /// Returns snapshot of `view` added to `containerView`.
  static func addSnapshot(
    using view: UIView,
    to containerView: UIView,
    afterScreenUpdates: Bool = true
  ) -> UIView? {
    guard let snapshot = view.snapshotView(
      afterScreenUpdates: afterScreenUpdates) else {
      return nil
    }

    containerView.addSubview(snapshot)

    return snapshot
  }

  enum Orientation {
    case vertical, horizontal

    init(traitCollection: UITraitCollection) {
      let isVerticallyCompact = traitCollection.containsTraits(
        in: UITraitCollection(verticalSizeClass: .compact))
      self = isVerticallyCompact ? .horizontal : .vertical
    }
  }

  static func makeOffset(
    orientation: PlayerAnimator.Orientation, distance: CGFloat
  ) -> CGAffineTransform {
    return orientation == .horizontal ?
      CGAffineTransform(translationX: distance, y: 0) :
      CGAffineTransform(translationX: 0, y: distance)
  }

}

// MARK: - PlayerTransitionDelegate

final class PlayerTransitionDelegate: NSObject {}

extension PlayerTransitionDelegate: UIViewControllerTransitioningDelegate {
  
  func presentationController(
    forPresented presented: UIViewController,
    presenting: UIViewController?,
    source: UIViewController
  ) -> UIPresentationController? {
    switch presented {
    case is PlayerViewController:
      return PlayerPresentationController(
        presentedViewController: presented, presenting: presenting)
    default:
      return nil
    }
  }
  
  func animationController(
    forPresented presented: UIViewController,
    presenting: UIViewController,
    source: UIViewController
  ) -> UIViewControllerAnimatedTransitioning? {
    return PlayerPresentationAnimator()
  }
  
  func animationController(
    forDismissed dismissed: UIViewController
  ) -> UIViewControllerAnimatedTransitioning? {
    return PlayerDismissalAnimator()
  }
  
}
