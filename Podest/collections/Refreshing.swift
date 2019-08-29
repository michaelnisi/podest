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
protocol Refreshing: class {

  /// Refreshes contents of the collection and updates refresh control.
  func reload()
}

/// Coordinates refreshing of collections for animation choreography.
///
/// For example, batch updates should not interfere with scrolling-to-top animations. Or, say, the collection
/// view is off-screen then reloading must be deferred. Coordination with `UIRefreshControl` is tricky.
protocol Choreographing {

  /// Defers incoming refreshing requests. Blocked requests accumulate in refreshing after clearance.
  func wait()

  /// Clears refreshing after `milliseconds`.
  func clear(after milliseconds: Int)

  /// Clears refreshing.
  func clear()

  /// Signals that refreshing of collection contents has started.
  func refresh()

  /// Signals that collection contents has been refreshed.
  func refreshed()

  var isRefreshing: Bool { get }

  var delegate: Refreshing? { get set }
}

// MARK: - Finite State Machine

class RefreshingFSM: Choreographing {

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

  var isRefreshing: Bool {
    if case .refreshing = state { return true }
    return false
  }

  weak var delegate: Refreshing?
}

// MARK: - Handling Events

extension RefreshingFSM {

  private func handle(event: Event) {
    os_log("handling event: %@,", log: log, type: .debug,
           String(describing: event))

    switch state {
    case .refreshing:
      switch event {
      case .go, .refresh:
        os_log("ignoring event: %@", log: log, String(describing: event))

        state = .refreshing

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

      case .refreshed, .go:
        os_log("ignoring event: %@", log: log, String(describing: event))

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
          DispatchQueue.main.async { [weak self] in
            self?.delegate?.reload()
          }
        }

      case .refreshed:
        state = .ready
      }
    }
  }
}

// MARK: - Choreographing

extension RefreshingFSM {

  func wait() {
    handle(event: .wait)
  }

  func clear(after ms: Int) {
    DispatchQueue.global(qos: .userInitiated)
      .asyncAfter(deadline: .now() + .milliseconds(ms)) { [weak self] in
      DispatchQueue.main.async {
        self?.handle(event: .go)
      }
    }
  }

  func clear() {
    clear(after: 300)
  }

  func refresh() {
    handle(event: .refresh)
  }

  func refreshed() {
    handle(event: .refreshed)
  }
}
