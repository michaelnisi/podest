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

final class PlayerTransitioningDelegate: NSObject, UIViewControllerTransitioningDelegate {
  
  var interactiveDismiss = true
  
  init(from presented: UIViewController, to presenting: UIViewController) {
    super.init()
  }

  func animationController(
    forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
    nil
  }
  
  func presentationController(
    forPresented presented: UIViewController,
    presenting: UIViewController?,
    source: UIViewController
  ) -> UIPresentationController? {
    let controller = PlayerPresentationController(presentedViewController: presented, presenting: presenting)
    controller.presentedYOffset = UIScreen.main.bounds.height / 3
    
    return controller
  }
  
  func interactionControllerForDismissal(
    using animator: UIViewControllerAnimatedTransitioning
  ) -> UIViewControllerInteractiveTransitioning? {
    nil
  }
}
