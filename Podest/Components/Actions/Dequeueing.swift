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

protocol Dequeueing: ActionSheetPresenting {
  func enqueue(entry: Entry)
  func dequeue(entry: Entry, sourceView: UIView)
  func isEnqueued(entry: Entry) -> Bool
}

extension Dequeueing where Self: UIViewController {
  
  private static func makeDequeueAction(entry: Entry) -> UIAlertAction {
    let t = NSLocalizedString("Delete", comment: "Delete episode from queue")
    
    return UIAlertAction(title: t, style: .destructive) { action in
      Podcasts.userQueue.dequeue(entry: entry) { dequeued, error in
        if let er = error {
          os_log("dequeueing failed: %@", log: log, er as CVarArg)
        }
      }
    }
  }
  
  private static func makeDequeueActions(entry: Entry) -> [UIAlertAction] {
    return [makeDequeueAction(entry: entry), makeCancelAction()]
  }
  
  private static func makeDequeueController(entry: Entry) -> UIAlertController {
    let alert = UIAlertController(
      title: entry.title, message: nil, preferredStyle: .actionSheet
    )
    
    let actions = makeDequeueActions(entry: entry)
    
    for action in actions {
      alert.addAction(action)
    }
    
    return alert
  }
  
  func dequeue(entry: Entry, sourceView: UIView) {
    let alert = Self.makeDequeueController(entry: entry)
      
    if let presenter = alert.popoverPresentationController {
      presenter.sourceView = sourceView
    }
    
    present(alert, animated: true, completion: nil)
  }
  
  func enqueue(entry: Entry) {
    Podcasts.userQueue.enqueue(
      entries: [entry], belonging: .user, enqueueCompletionBlock: nil)
  }
  
  func isEnqueued(entry: Entry) -> Bool {
    return Podcasts.userQueue.contains(entry: entry)
  }
}
