//
//  MessageView.swift
//  Podest
//
//  Created by Michael on 3/12/17.
//  Copyright © 2017 Michael Nisi. All rights reserved.
//

import UIKit

/// Intended to show a message in the background of a table view.
class MessageView: UIView {

  static func make() -> MessageView {
    let nib = UINib(nibName: "MessageView", bundle: .main)

    guard let messageView = nib.instantiate(withOwner: nil)
      .first as? MessageView else {
      fatalError("Failed to initiate view")
    }

    return messageView
  }

  @IBOutlet var label: UILabel!
  
  var text: String? {
    didSet {
      attributedText = NSAttributedString(string: text ?? "Yikes!")
    }
  }
  
  var attributedText: NSAttributedString? {
    didSet {
      setNeedsDisplay()
    }
  }

  override func draw(_ rect: CGRect) {
    label.attributedText = attributedText
  }

  deinit {
    removeAnimators()
  }

  private var animators = [UIViewPropertyAnimator]()

  private func removeAnimators() {
    for animator in animators {
      animator.stopAnimation(true)
    }

    animators.removeAll()
  }

  private func startAnimator(_ animator: UIViewPropertyAnimator) {
    animators.append(animator)
    animator.startAnimation()
  }

  func show() {
    removeAnimators()

    let fade = UIViewPropertyAnimator(duration: 0.3, curve: .easeOut) {
      [weak self] in
     self?.alpha = 1
    }

    startAnimator(fade)
  }

  func hide(_ completionBlock: (() -> Void)?) {
    removeAnimators()

    let fade = UIViewPropertyAnimator(duration: 0.3, curve: .easeIn) {
      [weak self] in
      self?.alpha = 0
    }

    fade.addCompletion {_ in
      completionBlock?()
    }

    startAnimator(fade)
  }
}
