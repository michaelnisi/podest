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

  /// Adds a snapshot of the player to the container, hiding the image, for
  /// we are about to animate into position.
  private static func makeBackground(
    containerView: UIView,
    player: PlayerViewController
  ) -> UIView? {
    player.heroImage.alpha = 0

    guard let snapshot = player.view.snapshotView(
      afterScreenUpdates: true) else {
      return nil
    }

    player.heroImage.alpha = 1
    containerView.addSubview(snapshot)

    return snapshot
  }

  func animateTransition(
    using transitionContext: UIViewControllerContextTransitioning) {
    os_log("animating presentation transition", log: log, type: .debug)

    // Stage

    let tc = transitionContext
    let cv = transitionContext.containerView

    // Getting at our main characters

    guard tc.isAnimated,
      let to = tc.viewController(forKey: .to) as? PlayerViewController,
      let bg = PlayerPresentationAnimator.makeBackground(
        containerView: cv, player: to),
      let hero = PlayerAnimator.addHero(using: tc) else {
      return
    }

    // Present

    cv.addSubview(to.view)

    // On your marks

    to.view.isHidden = true
    to.view.layoutIfNeeded()

    let (_, t) = PlayerAnimator.makeCFAffineTransform(
      view: cv, traitCollection: to.traitCollection)

    bg.transform = t

    // Animate

    let heroCenter = to.container.convert(to.heroImage.center, to: cv)
    let heroBounds = to.heroImage.bounds

    let anim = UIViewPropertyAnimator(duration: duration, curve: .easeInOut) {
      bg.transform = CGAffineTransform.identity

      hero.center = heroCenter
      hero.bounds = heroBounds
    }

    anim.addCompletion { finalPosition in
      bg.removeFromSuperview()
      hero.removeFromSuperview()

      to.animationEnded(hero)
      to.view.isHidden = false

      transitionContext.completeTransition(true)
    }

    anim.startAnimation()
  }

  func animationEnded(_ transitionCompleted: Bool) {
    os_log("animation ended: %i", log: log, type: .debug, transitionCompleted)
  }

}
