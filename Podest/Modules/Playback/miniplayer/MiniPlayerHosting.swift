//
//  MiniPlayerHosting.swift
//  Podest
//
//  Created by Michael Nisi on 16.06.21.
//  Copyright © 2021 Michael Nisi. All rights reserved.
//

import UIKit
import os.log

private let log = OSLog(subsystem: "ink.codes.podest", category: "MiniPlayer")

// MARK: - Placing the Mini-Player

extension RootViewController {

  var isMiniPlayerHidden: Bool {
    minivc.viewIfLoaded?.isHidden ?? true
  }

  private var miniLayout: NSLayoutConstraint {
    return view.constraints.first {
      guard $0.isActive else {
        return false
      }

      return $0.identifier == "Mini-Player-Layout-Top" ||
        $0.identifier == "Mini-Player-Layout-Leading"
      }!
  }

  var miniPlayerEdgeInsets: UIEdgeInsets {
    guard
      !isMiniPlayerHidden,
      miniLayout.identifier == "Mini-Player-Layout-Top",
      miniLayout.constant != 0 else {
      return .zero
    }

    let bottom = minivc.view.frame.height - view.safeAreaInsets.bottom

    return UIEdgeInsets(top: 0, left: 0, bottom: bottom, right: 0)
  }

  func hideMiniPlayer(animated: Bool, completion: (() -> Void)? = nil) {
    os_log("hiding mini-player", log: log, type: .info)

    func done() {
      completion?()
    }

    guard animated else {
      miniPlayerTop.constant = 0
      miniPlayerBottom.constant = miniPlayerConstant
      miniPlayerLeading.constant = 0
      minivc.view.isHidden = true

      view.layoutIfNeeded()

      return done()
    }

    if miniPlayerTop.isActive {
      miniPlayerTop.constant = 0
      miniPlayerBottom.constant = miniPlayerConstant
      
      let anim = UIViewPropertyAnimator(duration: 0.3, curve: .linear) {
        self.view.layoutIfNeeded()
      }
      
      anim.addCompletion { position in
        self.miniPlayerLeading.constant = 0
        
        self.view.layoutIfNeeded()
        
        self.minivc.view.isHidden = true
        
        done()
      }
      
      anim.startAnimation()
    } else {
      miniPlayerLeading.constant = 0
      
      let anim = UIViewPropertyAnimator(duration: 0.3, curve: .linear) {
        self.view.layoutIfNeeded()
      }
      
      anim.addCompletion { position in
        self.miniPlayerTop.constant = 0
        self.miniPlayerBottom.constant = self.miniPlayerConstant
        
        self.view.layoutIfNeeded()
        
        self.minivc.view.isHidden = true
        
        done()
      }
      
      anim.startAnimation()
    }
  }

  func showMiniPlayer(animated: Bool, completion: (() -> Void)? = nil) {
    os_log("showing mini-player", log: log, type: .info)
    dispatchPrecondition(condition: .onQueue(.main))

    minivc.view.isHidden = false

    guard animated, !isPresentingVideo else {
      os_log("applying constant: %f", log: log, type: .info, miniPlayerConstant)

      miniPlayerLeading.constant = miniPlayerConstant - view.safeAreaInsets.right
      miniPlayerTop.constant = miniPlayerConstant
      miniPlayerBottom.constant = 0

      view.layoutIfNeeded()
      completion?()

      return
    }

    if miniPlayerTop.isActive {
      os_log("animating portrait", log: log, type: .info)

      miniPlayerLeading.constant = miniPlayerConstant
      miniPlayerTop.constant = miniPlayerConstant
      miniPlayerBottom.constant = 0
    } else {
      os_log("animating landscape", log: log, type: .info)

      miniPlayerTop.constant = miniPlayerConstant
      miniPlayerBottom.constant = 0
      miniPlayerLeading.constant = miniPlayerConstant - view.safeAreaInsets.right
    }

    let anim = UIViewPropertyAnimator(duration: 0.3, curve: .easeOut) {
      self.view.layoutIfNeeded()
    }

    anim.addCompletion { position in
      completion?()
    }

    anim.startAnimation()
  }
}
