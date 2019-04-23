//
//  QueueTableViewDelegate.swift
//  Podest
//
//  Created by Michael Nisi on 21.04.19.
//  Copyright © 2019 Michael Nisi. All rights reserved.
//

import Foundation
import UIKit

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
  
  // MARK: Handling Swipe Actions
  
  private func makeDequeueAction(
    forRowAt indexPath: IndexPath) -> UIContextualAction {
    let h = dataSource.makeDequeueHandler(forRowAt: indexPath, of: tableView)
    let a = UIContextualAction(style: .destructive, title: nil, handler: h)
    let img = UIImage(named: "Trash")
    
    a.image = img
    
    return a
  }
  
  override func tableView(
    _ tableView: UITableView,
    trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
    let actions = [makeDequeueAction(forRowAt: indexPath)]
    let conf = UISwipeActionsConfiguration(actions: actions)
    
    conf.performsFirstActionWithFullSwipe = true
    
    return conf
  }
  
  override func tableView(
    _ tableView: UITableView,
    didEndEditingRowAt indexPath: IndexPath?) {
    reload()
  }
  
}
