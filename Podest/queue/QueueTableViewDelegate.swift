//
//  QueueTableViewDelegate.swift
//  Podest
//
//  Created by Michael Nisi on 21.04.19.
//  Copyright © 2019 Michael Nisi. All rights reserved.
//

import Foundation
import UIKit
import FeedKit

extension QueueViewController {

  override func tableView(
    _ tableView: UITableView,
    willSelectRowAt indexPath: IndexPath
  ) -> IndexPath? {
    guard case .entry? = dataSource.itemAt(indexPath: indexPath) else {
      return nil
    }
    
    return indexPath
  }
  
  override func tableView(
    _ tableView: UITableView,
    didSelectRowAt indexPath: IndexPath
    ) {
    guard let entry = dataSource.entry(at: indexPath) else {
      return
    }
    
    navigationDelegate?.show(entry: entry)
  }
  
  override func tableView(_ tableView: UITableView, didEndEditingRowAt indexPath: IndexPath?) {
    reload()
  }
}

// MARK: - Leading Swipe Actions

extension QueueViewController {
  
  private static var play: UIImage {
    if #available(iOS 13.0, *) {
      return UIImage(systemName: "play.fill")!
    } else {
      return UIImage(named: "Play")!
    }
  }
  
  private func makePlayAction(
    indexPath: IndexPath, entry: Entry) -> UIContextualAction {
    let a = UIContextualAction(style: .normal, title: nil) { 
      action, sourceView, completionHandler in
      let actionPerformed = Podest.playback.resume(entry: entry)
      
      completionHandler(actionPerformed)
    }
    a.image = QueueViewController.play
    a.backgroundColor = .systemGreen
    
    return a
  }
  
  override func tableView(
    _ tableView: UITableView, 
    leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath
  ) -> UISwipeActionsConfiguration? {
    guard let entry = dataSource.entry(at: indexPath), 
      !Podest.playback.isPlaying(guid: entry.guid) else {
      return nil
    }

    let actions = [makePlayAction(indexPath: indexPath, entry: entry)]
    let conf = UISwipeActionsConfiguration(actions: actions)
    conf.performsFirstActionWithFullSwipe = true
    
    return conf
  }
}

// MARK: - Trailing Swipe Actions

extension QueueViewController {
  
  private static var trash: UIImage {
     if #available(iOS 13.0, *) {
       return UIImage(systemName: "trash.fill")!
     } else {
       return UIImage(named: "Trash")!
     }
  }
   
   private func makeDequeueAction(indexPath: IndexPath) -> UIContextualAction {
     let h = dataSource.makeDequeueHandler(
      indexPath: indexPath, tableView: tableView)
     let a = UIContextualAction(style: .destructive, title: nil, handler: h)
     a.image = QueueViewController.trash
     
     return a
   }
   
   override func tableView(
     _ tableView: UITableView,
     trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
   ) -> UISwipeActionsConfiguration? {
     let actions = [makeDequeueAction(indexPath: indexPath)]
     let conf = UISwipeActionsConfiguration(actions: actions)
     conf.performsFirstActionWithFullSwipe = true
     
     return conf
   }
}
