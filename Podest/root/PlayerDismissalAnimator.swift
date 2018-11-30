//
//  PlayerDismissalAnimator.swift
//  Podest
//
//  Created by Michael Nisi on 29.11.18.
//  Copyright © 2018 Michael Nisi. All rights reserved.
//

import UIKit
import os.log

final class PlayerDismissalAnimator: PlayerAnimator {}

extension PlayerDismissalAnimator: UIViewControllerAnimatedTransitioning {

  func transitionDuration(
    using transitionContext: UIViewControllerContextTransitioning?
  ) -> TimeInterval {
    return duration
  }

  /// Returns an animator that hides the episode stack view, containing titles
  /// and controls, of the player view controller, visible at the beginning of
  /// the transition.
  private static func makeEpisodeAnimator(
    transitionContext: UIViewControllerContextTransitioning,
    duration: TimeInterval
  ) -> UIViewPropertyAnimator? {
    guard transitionContext.isAnimated,
      let from = transitionContext.viewController(
        forKey: .from) as? PlayerViewController,
      let episode = from.episode else {
      return nil
    }

    return UIViewPropertyAnimator(duration: duration / 3, curve: .easeIn) {
      episode.alpha = 0
    }
  }

  func animateTransition(
    using transitionContext: UIViewControllerContextTransitioning) {
    os_log("animating dismissal transition", log: log, type: .debug)

    let tc = transitionContext

    guard tc.isAnimated,
      let from = tc.viewController(forKey: .from)as? PlayerViewController,
      let to = tc.viewController(forKey: .to)as? RootViewController,
      let hero = PlayerAnimator.addHero(using: tc),
      let mini = to.minivc.view else {
      return
    }

    let cv = transitionContext.containerView

    // Hiding titles and controls

    let hidingEpisode = PlayerDismissalAnimator.makeEpisodeAnimator(
      transitionContext: tc, duration: duration)
    hidingEpisode?.startAnimation()

    // Setting up the main animation

    let (isVerticallyCompact, t) = PlayerAnimator.makeCFAffineTransform(
      view: cv, traitCollection: from.traitCollection)

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
    }, delayFactor: 2 / 3)

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
