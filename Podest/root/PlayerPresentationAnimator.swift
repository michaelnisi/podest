//
//  PlayerPresentationAnimator.swift
//  Podest
//
//  Created by Michael Nisi on 29.11.18.
//  Copyright © 2018 Michael Nisi. All rights reserved.
//

import UIKit
import os.log

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
      let from = transitionContext.viewController(
        forKey: .from) as? RootViewController,
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

    let anim = UIViewPropertyAnimator(
      duration: duration * 2 / 3, curve: .easeInOut) {
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
//      let hero = PlayerAnimator.addHero(using: tc) else {
      return
    }
    
    let cv = transitionContext.containerView

    cv.addSubview(to.view)

    let (_, t) = PlayerAnimator.makeCFAffineTransform(
      view: cv, traitCollection: to.traitCollection)

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
