//
//  PlayerTransitionDelegate.swift
//  Podest
//
//  Created by Michael Nisi on 13.03.18.
//  Copyright © 2018 Michael Nisi. All rights reserved.
//

import Foundation
import UIKit
import os.log

private let log = OSLog.disabled

/// Duration of both, presentation and dismissal, animations.
private let duration = TimeInterval(0.3)

// MARK: - PlayerPresentationController

/// The player presentation controller is setup, but not in use yet.
class PlayerPresentationController: UIPresentationController {}

class PlayerAnimator: NSObject {

  fileprivate static func findHero(viewController: UIViewController) -> UIView? {
    switch viewController {
    case let vc as PlayerViewController:
      return vc.heroImage
    case let vc as MiniPlayerController:
      return vc.hero
    default:
      return nil
    }
  }

  fileprivate static func addHero(
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

}

// MARK: - PlayerDismissalAnimator

final class PlayerDismissalAnimator: PlayerAnimator {}

extension PlayerDismissalAnimator: UIViewControllerAnimatedTransitioning {
  
  func transitionDuration(
    using transitionContext: UIViewControllerContextTransitioning?
  ) -> TimeInterval {
    return duration
  }

  func hideEpisode(using tc: UIViewControllerContextTransitioning) {
    guard tc.isAnimated,
      let from = tc.viewController(forKey: .from)as? PlayerViewController,
      let episode = from.episode else {
      return
    }

    let anim = UIViewPropertyAnimator(duration: duration * 0.3, curve: .easeInOut) {
      episode.alpha = 0
    }

    anim.startAnimation()
  }

  func animateTransition(
    using transitionContext: UIViewControllerContextTransitioning) {
    os_log("animating dismissal transition", log: log, type: .debug)

    let tc = transitionContext

    guard tc.isAnimated,
      let from = tc.viewController(forKey: .from)as? PlayerViewController,
      let to = tc.viewController(forKey: .to)as? RootViewController,
      let hero = PlayerDismissalAnimator.addHero(using: tc),
      let mini = to.minivc.view else {
      return
    }

    let cv = transitionContext.containerView

    hideEpisode(using: transitionContext)

    let isVerticallyCompact = from.traitCollection.containsTraits(
      in: UITraitCollection(verticalSizeClass: .compact))
    
    let t = isVerticallyCompact ?
      CGAffineTransform(translationX: cv.bounds.width, y: 0) :
      CGAffineTransform(translationX: 0, y: cv.bounds.height)

    let heroCenter = to.minivc.view.convert(to.minivc.hero.center, to: cv)
    let heroBounds = to.minivc.hero.bounds

    let anim = UIViewPropertyAnimator(duration: duration, curve: .easeInOut) {
      transitionContext.view(forKey: .from)?.transform = t

      hero.center = heroCenter
      hero.bounds = heroBounds

      from.doneButton.alpha = 0
    }

    from.heroImage.alpha = 0

    let center = mini.center

    // A slight offset for blending into the motion.
    let offsetCenter = !isVerticallyCompact ?
      CGPoint(x: center.x, y: center.y - 64) :
      CGPoint(x: center.x - 64, y: center.y)

    mini.center = offsetCenter
    mini.alpha = 0

    anim.addAnimations({
      mini.alpha = 1
      mini.center = center
    }, delayFactor: 0.66)

    anim.addCompletion { finalPosition in
      hero.removeFromSuperview()
      transitionContext.completeTransition(true)
    }

    anim.startAnimation()
  }

  func animationEnded(_ transitionCompleted: Bool) {
    os_log("animation ended: %i", log: log, type: .debug, transitionCompleted)
  }
  
}

// MARK: - PlayerPresentationAnimator

final class PlayerPresentationAnimator: PlayerAnimator {
  private weak var miniPlayerView: UIView?
}

extension PlayerPresentationAnimator: UIViewControllerAnimatedTransitioning {
  
  func transitionDuration(
    using transitionContext: UIViewControllerContextTransitioning?
    ) -> TimeInterval {
    return duration
  }

  /// Slightly animates the mini-player of the *from* view controller.
  private func animateMiniPlayer(
    using transitionContext: UIViewControllerContextTransitioning) {
    guard transitionContext.isAnimated,
      let from = transitionContext.viewController(forKey: .from) as? RootViewController,
      let snapshot = miniPlayerView?.snapshotView(afterScreenUpdates: false),
      let superview = miniPlayerView?.superview else {
      return
    }

    let cv = transitionContext.containerView

    let center = superview.convert(from.minivc.view.center, to: cv)
    let isVerticallyCompact = from.traitCollection.containsTraits(
      in: UITraitCollection(verticalSizeClass: .compact))

    cv.addSubview(snapshot)
    snapshot.center = center

    let offsetCenter = !isVerticallyCompact ?
      CGPoint(x: center.x, y: center.y - 64) :
      CGPoint(x: center.x - 64, y: center.y)

    miniPlayerView?.alpha = 0

    let anim = UIViewPropertyAnimator(duration: duration * 0.3, curve: .easeInOut) {
      snapshot.center = offsetCenter
      snapshot.alpha = 0
    }

    anim.addCompletion { _ in
      snapshot.removeFromSuperview()
    }

    anim.startAnimation()
  }

  func animateTransition(
    using transitionContext: UIViewControllerContextTransitioning) {
    os_log("animating presentation transition", log: log, type: .debug)

    let tc = transitionContext

    guard tc.isAnimated,
      let to = tc.viewController(forKey: .to) as? PlayerViewController,
      let from = tc.viewController(forKey: .from) as? RootViewController else {
      return
    }

    let cv = transitionContext.containerView

    cv.addSubview(to.view)

    let isVerticallyCompact = to.traitCollection.containsTraits(
      in: UITraitCollection(verticalSizeClass: .compact))

    let t: CGAffineTransform = {
      if isVerticallyCompact {
        return CGAffineTransform(translationX: cv.bounds.width, y: 0)
      } else {
        return CGAffineTransform(translationX: 0, y: cv.bounds.height)
      }
    }()

    to.view.transform = t
    to.doneButton.alpha = 0

    let anim = UIViewPropertyAnimator(duration: duration, curve: .easeInOut) {
      to.view.transform = CGAffineTransform.identity
      to.doneButton.alpha = 1
    }

    miniPlayerView = from.minivc.view
    animateMiniPlayer(using: transitionContext)

    anim.addCompletion { [weak self] finalPosition in
      self?.miniPlayerView?.alpha = 1
      self?.miniPlayerView = nil
      transitionContext.completeTransition(true)
    }

    anim.startAnimation()
  }

  func animationEnded(_ transitionCompleted: Bool) {
    os_log("animation ended: %i", log: log, type: .debug, transitionCompleted)
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
