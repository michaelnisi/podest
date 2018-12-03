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

  /// Returns snapshot of `view` added to `containerView`.
  private static
  func addSnapshot(_ view: UIView, _ containerView: UIView) -> UIView? {
    guard let snapshot = view.snapshotView(afterScreenUpdates: true) else {
      return nil
    }

    containerView.addSubview(snapshot)

    return snapshot
  }

  /// Adds a snapshot of the player to the container.
  private static func makeBackground(
    _ containerView: UIView,
    _ player: PlayerViewController
  ) -> UIView? {
    player.heroImage.alpha = 0
    player.doneButton.alpha = 0

    defer {
      player.heroImage.alpha = 1
      player.doneButton.alpha = 1
    }

    return addSnapshot(player.view, containerView)
  }

  func animateTransition(
    using transitionContext: UIViewControllerContextTransitioning) {
    os_log("animating presentation transition", log: log, type: .debug)

    // Setting handy refs for our context.

    let tc = transitionContext
    let cv = transitionContext.containerView

    // Adding snapshots for animation.

    guard tc.isAnimated,
      let to = tc.viewController(forKey: .to) as? PlayerViewController,
      let bg = PlayerPresentationAnimator.makeBackground(cv, to),
      let header = PlayerPresentationAnimator.addSnapshot(to.doneButton, cv),
      let hero = PlayerAnimator.addHero(using: tc) else {
      return
    }

    to.view.layoutIfNeeded()

    // Adding the main view and hiding it while animating.

    cv.addSubview(to.view)
    to.view.isHidden = true

    // Placing snapshots/sprites on their initial marks.

    let o = Orientation(traitCollection: to.traitCollection)

    let d = o == .horizontal ? cv.bounds.width : cv.bounds.height
    bg.transform = PlayerAnimator.makeOffset(orientation: o, distance: d)

    header.alpha = 0
    header.center = to.view.convert(to.doneButton.center, to: cv)
    header.transform = PlayerAnimator.makeOffset(orientation: o, distance: 256)

    // Setting up and starting the animation, cleaning up in the completion
    // block.

    let anim = UIViewPropertyAnimator(duration: duration, curve: .easeInOut) {
      header.alpha = 1
      header.transform = CGAffineTransform.identity

      hero.center = to.container.convert(to.heroImage.center, to: cv)
      hero.bounds = to.heroImage.bounds

      bg.transform = CGAffineTransform.identity
    }

    anim.addCompletion { finalPosition in
      for v in [header, bg, hero] { v.removeFromSuperview() }

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
