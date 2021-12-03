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

import Foundation
import BatchUpdates
import FeedKit
import os.log
import Podcasts

private let log = OSLog.disabled

// MARK: - Subscription

extension ListViewController {
  
  /// Updates the `isSubscribed` property using `urls` or the user library.
  func updateIsSubscribed(using urls: Set<FeedURL>? = nil) {
    if let subscribed = urls, let url = self.url {
      isSubscribed = subscribed.contains(url)
      return
    }

    if let feed = self.feed {
      isSubscribed = Podcasts.userLibrary.has(subscription: feed.url)
    } else {
      // At launch, during state restoration, the user library might not be
      // sufficiently synchronized yet, so we sync and wait before configuring
      // the navigation item.

      Podcasts.userLibrary.synchronize { [weak self] urls, _, error in
        if let er = error {
          switch er {
          case QueueingError.outOfSync(let queue, let guids):
            if queue == 0, guids != 0 {
              os_log("queue not populated", log: log, type: .info)
            } else {
              os_log("out of sync: ( queue: %i, guids: %i )",
                     log: log, type: .info, queue, guids)
            }
          default:
            fatalError("probably a database error: \(er)")
          }
        }

        DispatchQueue.main.async { [weak self] in
          guard let url = self?.url else {
            return
          }

          self?.isSubscribed = urls?.contains(url) ?? false
        }
      }
    }
  }
}

// MARK: - Fetching Feed and Entries

extension ListViewController {

  typealias Sections = [Array<ListDataSource.Item>]
  typealias Changes = [[Change<ListDataSource.Item>]]

  func makeUpdateOperation(
    updatesBlock: ((Sections, Changes, Error?) -> Void)? = nil
  ) -> ListOperation {
    guard let url = self.url else {
      fatalError("cannot refresh without URL")
    }

    let op = ListOperation(
      url: url, originalFeed: feed, withoutImage: !isCompact)

    op.feedBlock = { [weak self] feed, error in
      guard error == nil, let feed = feed else {
        return
      }
      
      DispatchQueue.main.async {
        self?.feed = feed
      }
    }

    op.updatesBlock = updatesBlock

    return op
  }

  /// Reloads this list, executing `completionBlock` when done.
  ///
  /// The crux: feed and entries are separate, the feed object might not be
  /// available yet or it might contain no summary—it must be fetched remotely.
  func update(completionBlock: (() -> Void)? = nil) {
    let op = makeUpdateOperation { [weak self] sections, changes, error in
      DispatchQueue.main.async {
        guard let tv = self?.tableView else {
          return
        }

        self?.isReady = false

        self?.dataSource.commit(changes, performingWith: .table(tv)) { _ in
          if let entry = self?.navigationDelegate?.entry {
            self?.selectRow(representing: entry, animated: true)
          }

          self?.isReady = true

          completionBlock?()
        }
      }
    }

    updating = dataSource.add(op)
  }
}
