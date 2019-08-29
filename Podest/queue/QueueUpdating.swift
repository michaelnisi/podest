//
//  QueueUpdating.swift
//  Podest
//
//  Created by Michael Nisi on 21.04.19.
//  Copyright © 2019 Michael Nisi. All rights reserved.
//

import Foundation
import UIKit
import os.log

extension QueueViewController: Refreshing {
  
  /// Refreshes table view contents and keeping refresh control posted.
  ///
  /// - Parameters:
  ///   - animated: A flag to disable animations.
  ///   - completionBlock: Submitted to the main queue when the table view has been reloaded.
  ///
  /// NOP if the view has not yet been added to a window or if performing batch updates would not be 
  /// choreographically feasible at this moment.
  func reload(
    _ animated: Bool = true, 
    completionBlock: ((Error?) -> Void)? = nil
  ) {
    os_log(#function, log: log, type: .debug)
    dispatchPrecondition(condition: .onQueue(.main))
    
    choreographer.refresh()
    
    guard tableView.window != nil, choreographer.isRefreshing else {
      return DispatchQueue.main.async { [weak self] in
        self?.refreshControl?.endRefreshing()
        completionBlock?(nil)
      }
    }
    
    refreshControl?.beginRefreshing()
 
    dataSource.reload { [weak self] changes, error in
      guard 
        let tv = self?.tableView, 
        self?.tableView.window != nil, 
        self?.choreographer.isRefreshing ?? false else {
        self?.refreshControl?.endRefreshing()
        completionBlock?(error)
        return
      }
      
      func done() {
        self?.updateSelection(animated)
        self?.choreographer.refreshed()
        self?.refreshControl?.endRefreshing()
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
  
  /// Updates the queue, fetching new episodes from the remote service, before refreshing table view 
  /// contents.
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
    os_log(#function, log: log, type: .debug)
    dispatchPrecondition(condition: .onQueue(.main))
    
    guard dataSource.isReady else {
      completionHandler?(false, nil)
      return
    }
        
    dataSource.update(considering: error) { [weak self] newData, updateError in
      self?.reload { refreshError in 
        completionHandler?(newData, refreshError ?? updateError ?? error)
      }
    }
  }
}
