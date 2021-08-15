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

import UIKit

/// Animator for episode to episode transitions in landscape mode.
final class EpisodeAnimator: NSObject, UIViewControllerAnimatedTransitioning {
  func transitionDuration(
    using context: UIViewControllerContextTransitioning?) -> TimeInterval {
    return 0.2
  }
  
  func animateTransition(using context: UIViewControllerContextTransitioning) {
    guard
      let to = context.viewController(forKey: .to) as? EpisodeViewController,
      let from = context.viewController(forKey: .from) as? EpisodeViewController else {
      fatalError("unexpected context")
    }
    
    context.containerView.addSubview(to.view)
    
    from.content.isHidden = true
    to.content.alpha = 0
    
    UIView.animate(withDuration: 0.2, animations: {
      to.content.alpha = 1
    }) { finished in
      context.completeTransition(!context.transitionWasCancelled)
    }
  }
}
