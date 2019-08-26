//
//  QueueUpdating.swift
//  Podest
//
//  Created by Michael Nisi on 21.04.19.
//  Copyright © 2019 Michael Nisi. All rights reserved.
//

import Foundation
import UIKit

extension QueueViewController: Refreshing {
  
  /// Refresh the contents of the table view.
  ///
  /// - Parameters:
  ///   - animated: A flag to disable animations.
  ///   - completionBlock: Submitted to the main queue when the table view has
  /// has been reloaded.
  ///
  /// NOP if the table view is in editing mode or if the view has not yet been 
  /// added to a window.
  func reload(
    _ animated: Bool = true, 
    completionBlock: ((Error?) -> Void)? = nil
  ) {
    dispatchPrecondition(condition: .onQueue(.main))
    
    fsm.refresh()
    
    guard 
      tableView.window != nil, 
      !tableView.isEditing, 
      case .refreshing = fsm.state else {
      completionBlock?(nil)
      return
    }
      
    tableView?.refreshControl?.beginRefreshing()

    dataSource.reload { [weak self] changes, error in
      guard 
        let tv = self?.tableView, 
        self?.tableView.window != nil, 
        !changes.isEmpty, 
        case .refreshing = self?.fsm.state else {
        self?.tableView.refreshControl?.endRefreshing()
        completionBlock?(error)
          
        return
      }
      
      func done() {
        self?.updateSelection(animated)
        self?.tableView.refreshControl?.endRefreshing()
        self?.fsm.refreshed()
        completionBlock?(error)
      }
      
      guard animated else {
        return UIView.performWithoutAnimation {
          self?.dataSource.commit(changes, performingWith: .table(tv)) { _ in
            done()
          }
        }
      }
      
      self?.dataSource.commit(changes, performingWith: .table(tv)) { _ in
        done()
      }
    }
  }
  
  func reload() {
    reload(true, completionBlock: nil)
  }
  
  /// Updates the queue, fetching new episodes, accessing the remote service.
  ///
  /// - Parameters:
  ///   - error: An upstream error to consider while updating.
  ///   - completionHandler: Submitted to the main queue when the collection
  /// has been updated.
  ///
  /// The frequency of subsequent updates is limited.
  func update(
    considering error: Error? = nil,
    completionHandler: ((Bool, Error?) -> Void)? = nil
  ) {
    dispatchPrecondition(condition: .onQueue(.main))
    
    let isInitial = dataSource.isEmpty || dataSource.isMessage
    
    guard isInitial || dataSource.isReady else {
      completionHandler?(false, nil)
      return
    }
    
    let animated = !isInitial
            
    // Reloading first for initially putting something on the screen. Assuming,
    // reloads are cheap without actual changes.
    
    reload(animated) { [weak self] initialReloadError in
      self?.dataSource.update(considering: error) { newData, updateError in
        self?.reload(animated) { error in
          completionHandler?(newData, updateError ?? error)
        }
      }
    }
  }
}
