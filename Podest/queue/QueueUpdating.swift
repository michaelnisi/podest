//
//  QueueUpdating.swift
//  Podest
//
//  Created by Michael Nisi on 21.04.19.
//  Copyright © 2019 Michael Nisi. All rights reserved.
//

import Foundation
import UIKit

extension QueueViewController {
  
  /// Reloads the table view.
  ///
  /// - Parameters:
  ///   - animated: A flag to disable animations.
  ///   - completionBlock: Submitted to the main queue when the table view has
  /// has been reloaded.
  ///
  /// NOP if the table view is in editing mode.
  func reload(_ animated: Bool = true, completionBlock: ((Error?) -> Void)? = nil) {
    guard !tableView.isEditing else {
      completionBlock?(nil)
      return
    }
    
    dataSource.reload { [weak self] changes, error in
      func done() {
        self?.updateSelection(animated)
        self?.navigationItem.hidesSearchBarWhenScrolling = !(self?.dataSource.isEmpty ?? true)
        completionBlock?(error)
      }
      
      guard let tv = self?.tableView else {
        return done()
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
    let isInitial = dataSource.isEmpty || dataSource.isMessage
    
    guard isInitial || dataSource.isReady else {
      completionHandler?(false, nil)
      return
    }
    
    let animated = !isInitial
    
    // Reloading first, attaining a state to update from.
    
    reload(animated) { [weak self] initialReloadError in
      self?.dataSource.update(considering: error) { newData, updateError in
        self?.reload(animated) { error in
          assert(error == nil, "error relevance unclear")
          completionHandler?(newData, updateError)
        }
      }
    }
  }

}
