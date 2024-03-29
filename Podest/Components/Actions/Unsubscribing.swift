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
import FeedKit
import os.log
import Podcasts

private let log = OSLog.disabled

protocol Unsubscribing: ActionSheetPresenting {
  func unsubscribe(title: String, url: String, barButtonItem: UIBarButtonItem)
  func unsubscribe(title: String, url: String, sourceView: UIView)
  func subscribe(feed: Feed)
  func has(url: String) -> Bool
}

extension Unsubscribing where Self: UIViewController {
  
  private static func makeUnsubscribeAction(url: FeedURL) -> UIAlertAction {
    let t = NSLocalizedString("Unsubscribe", comment: "Unsubscribe podcast")

    return UIAlertAction(title: t, style: .destructive) { action in
      Podcasts.userLibrary.unsubscribe(url) { error in
        if let er = error {
          os_log("unsubscribing failed: %@", log: log, er as CVarArg)
        }
      }
    }
  }

  private static func makeUnsubscribeActions(url: FeedURL) -> [UIAlertAction] {
    var actions =  [UIAlertAction]()

    let unsubscribe = makeUnsubscribeAction(url: url)
    let cancel = makeCancelAction()

    actions.append(unsubscribe)
    actions.append(cancel)

    return actions
  }

  private static func makeRemoveController(title: String, url: String) -> UIAlertController {
    let alert = UIAlertController(
      title: title, message: nil, preferredStyle: .actionSheet
    )

    let actions = makeUnsubscribeActions(url: url)

    for action in actions {
      alert.addAction(action)
    }

    return alert
  }

  func unsubscribe(title: String, url: String, barButtonItem: UIBarButtonItem) {
    let alert = Self.makeRemoveController(title: title, url: url)

    if let presenter = alert.popoverPresentationController {
      presenter.barButtonItem = barButtonItem
    }

    self.present(alert, animated: true, completion: nil)
  }
  
  func unsubscribe(title: String, url: String, sourceView: UIView) {
    let alert = Self.makeRemoveController(title: title, url: url)

    if let presenter = alert.popoverPresentationController {
      presenter.sourceView = sourceView
    }

    self.present(alert, animated: true, completion: nil)
  }
  
  func has(url: FeedURL) -> Bool {
    Podcasts.userLibrary.has(subscription: url)
  }
  
  func subscribe(feed: Feed) {
    Podcasts.userLibrary.subscribe(feed, completionHandler: nil)
  }
}
