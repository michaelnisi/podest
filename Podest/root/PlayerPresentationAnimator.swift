//
//  PlayerPresentationAnimator.swift
//  Podest
//
//  Created by Michael Nisi on 29.11.18.
//  Copyright © 2018 Michael Nisi. All rights reserved.
//

import UIKit
import os.log

final class PlayerPresentationAnimator: PlayerAnimator {}

extension PlayerPresentationAnimator: UIViewControllerAnimatedTransitioning {

  func transitionDuration(
    using transitionContext: UIViewControllerContextTransitioning?
  ) -> TimeInterval {
    return duration
  }

  /// Adds a snapshot of the `player` view to `containerView`.
  static func addSnapshot(
    using player: PlayerViewController, to containerView: UIView) -> UIView? {
    player.heroImage.alpha = 0
    player.doneButton.alpha = 0

    defer {
      player.heroImage.alpha = 1
      player.doneButton.alpha = 1
    }

    return addSnapshot(using: player.view, to: containerView)
  }

  func animateTransition(
    using transitionContext: UIViewControllerContextTransitioning) {
    os_log("animating presentation transition", log: log, type: .debug)

    // Setting handy refs for our context.

    let tc = transitionContext
    let cv = transitionContext.containerView

    // Presenting in a fixed constellation only.

    guard
      let to = tc.viewController(forKey: .to) as? PlayerViewController,
      let from = tc.viewController(forKey: .from) as? RootViewController else {
      return transitionContext.completeTransition(false)
    }

    cv.addSubview(to.view)

    guard tc.isAnimated else {
      return transitionContext.completeTransition(true)
    }

    // Finding sprites.

    guard
      let fv = PlayerAnimator.addSnapshot(using: from.view, to: cv),
      let bg = PlayerPresentationAnimator.addSnapshot(using: to, to: cv),
      let hero = PlayerAnimator.addHero(using: tc),
      let header = PlayerAnimator.addSnapshot(using: to.doneButton, to: cv) else {
      return transitionContext.completeTransition(true)
    }

    // Hiding original views during animation.

    to.view.isHidden = true
    to.view.layoutIfNeeded()

    from.view.isHidden = true

    // Placing snapshots on their initial marks.

    let o = Orientation(traitCollection: to.traitCollection)

    let d = o == .horizontal ? cv.bounds.width : cv.bounds.height
    bg.transform = PlayerAnimator.makeOffset(orientation: o, distance: d)

    header.alpha = 0
    header.center = to.view.convert(to.doneButton.center, to: cv)
    header.transform = PlayerAnimator.makeOffset(orientation: o, distance: d)

    // Setting up and starting the animation, cleaning up in the completion
    // block.

    let anim = UIViewPropertyAnimator(duration: duration, curve: .easeInOut) {
      header.transform = .identity

      hero.center = to.container.convert(to.heroImage.center, to: cv)
      hero.bounds = to.heroImage.bounds

      bg.transform = .identity

      fv.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
    }

    // Shortening the visible path of the done button.

    anim.addAnimations({
      header.alpha = 1
    }, delayFactor: 0.1)

    anim.addCompletion { finalPosition in
      precondition(finalPosition == .end)

      for v in [header, bg, hero, fv] {
        v.removeFromSuperview()
      }

      to.animationEnded(hero)
      to.view.isHidden = false

      from.minivc.hero.isHidden = false
      from.view.isHidden = false

      transitionContext.completeTransition(true)
    }

    anim.startAnimation()
  }

  func animationEnded(_ transitionCompleted: Bool) {
    os_log("animation ended: %i", log: log, type: .debug, transitionCompleted)
  }

}
