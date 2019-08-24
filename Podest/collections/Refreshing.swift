//
//  Refreshing.swift
//  Podest
//
//  Created by Michael Nisi on 24.08.19.
//  Copyright © 2019 Michael Nisi. All rights reserved.
//

import Foundation
import os.log

private let log = OSLog(subsystem: "ink.codes.podest", category: "Refreshing")

/// Defines a controller for issuing collection content refreshing.
///
/// Peek into `QueueUpdating.swift` for an implementation.
protocol Refreshing {
  func reload()
}

/// Coordinates refreshing of collections.
///
/// For example, batch updates should not interfere with scrolling-to-top animations. Or, say, the collection 
/// view is off-screen then reloading must be deferred. Coordination with `UIRefreshControl` is tricky.
class RefreshingFSM {
  
  enum State {
    
    /// Collection view is currently refreshing its contents.
    case refreshing
    
    /// Ready to go.
    case ready
    
    /// Waiting for a view (animation) to finish.
    case waiting(Bool)
  }
  
  enum Event {
    case go
    case wait
    case refresh
    case refreshed
  }
  
  var state: State = .ready {
    didSet {
      os_log("state changed: ( %@, %@ )", log: log, type: .debug, 
             String(describing: oldValue), 
             String(describing: state))
    }
  }
  
  var delegate: Refreshing?
}

extension RefreshingFSM {
  
  func handle(event: Event) {
    os_log("handling event: %@,", log: log, type: .debug, 
           String(describing: event))
    
    switch state {
    case .refreshing:
      switch event {
      case .refresh:
        state = .refreshing
      
      case .go:
        state = .ready
        
        delegate?.reload()
      
      case .wait:
        state = .waiting(true)
        
      case .refreshed:
        state = .ready
      }
      
    case .ready:
      switch event {
      case .wait:
        state = .waiting(false)
      
      case .refresh:
        state = .refreshing
        
      case .go, .refreshed:
        state = .ready
      }
    
    case .waiting(let staged):
      switch event {
      case .wait:
        state = .waiting(staged)
      
      case .refresh:
        state = .waiting(true)
        
      case .go:
        state = .ready
        
        if staged {
          delegate?.reload()
        }
        
      case .refreshed:
        state = .ready
      }
    }
  }
}
