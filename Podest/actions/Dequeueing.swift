//
//  Dequeueing.swift
//  Podest
//
//  Created by Michael Nisi on 22.03.20.
//  Copyright © 2020 Michael Nisi. All rights reserved.
//

import UIKit
import FeedKit
import os.log

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
      Podest.userQueue.dequeue(entry: entry) { dequeued, error in
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
    Podest.userQueue.enqueue(
      entries: [entry], belonging: .user, enqueueCompletionBlock: nil)
  }
  
  func isEnqueued(entry: Entry) -> Bool {
    return Podest.userQueue.contains(entry: entry)
  }
}
