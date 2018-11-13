//
//  ListBackgroundView.swift
//  Podest
//
//  Created by Michael on 3/12/17.
//  Copyright © 2017 Michael Nisi. All rights reserved.
//

import UIKit

/// Intended to show a message in the background of a table view.
class ListBackgroundView: UIView {
  
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

// MARK: - Displaying Messages in Table View Backgrounds

extension UITableViewController {
  
  func showMessage(_ msg: NSAttributedString) {
    let nib = UINib(nibName: "ListBackgroundView", bundle: Bundle.main)
    let view = nib.instantiate(withOwner: nil).first as? ListBackgroundView

    view?.attributedText = msg
    view?.alpha = 0
    
    tableView.tableHeaderView?.isHidden = true
    tableView.tableFooterView?.isHidden = true
    tableView.backgroundView = view
    tableView.separatorStyle = .none
    
    tableView.reloadData()

    view?.show()
  }
  
  var isShowingMessage: Bool {
    guard let message = tableView.backgroundView as? ListBackgroundView else {
      return false
    }

    return message.alpha == 1
  }
  
  /// Prepares table view to hide the currently showing message the next time
  /// it reloads data.
  func hideMessage() {
    guard let message = tableView.backgroundView as? ListBackgroundView else {
      return
    }

    message.hide { [weak self] in
      self?.tableView.tableHeaderView?.isHidden = false
      self?.tableView.tableFooterView?.isHidden = false
      self?.tableView.backgroundView = nil
      self?.tableView.separatorStyle = .singleLine
    }
  }
  
}

