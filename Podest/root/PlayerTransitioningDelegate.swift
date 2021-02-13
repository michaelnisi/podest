//
//  PlayerTransitioningDelegate.swift
//  Podest
//
//  Created by Michael Nisi on 24.01.21.
//  Copyright © 2021 Michael Nisi. All rights reserved.
//

import UIKit

final class PlayerTransitioningDelegate: NSObject, UIViewControllerTransitioningDelegate {
  
  var interactiveDismiss = true
  
  init(from presented: UIViewController, to presenting: UIViewController) {
    super.init()
  }

  func animationController(
    forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
    return nil
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
    return nil
  }
}
