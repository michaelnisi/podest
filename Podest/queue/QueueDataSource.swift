//
//  QueueDataSource.swift
//  Podest
//
//  Created by Michael on 9/11/17.
//  Copyright © 2017 Michael Nisi. All rights reserved.
//

import UIKit
import FeedKit
import os.log

private let log = OSLog(subsystem: "ink.codes.podest", category: "queue")

/// `QueueDataSource` provides enqueued entries and subscribed feeds.
enum QueuedData: Equatable {
  case entry(Entry)
  case feed(Feed)
  
  static func ==(lhs: QueuedData, rhs: QueuedData) -> Bool {
    switch (lhs, rhs) {
    case (.entry(let a), .entry(let b)):
      return a == b
    case (.feed(let a), .feed(let b)):
      return a == b
    case (.entry, _), (.feed, _):
      return false
    }
  }
}

/// Identifies sections.
enum QueuedSectionID: Int {
  case entry, feed
}

/// Provides access to queue and subscription data.
final class QueueDataSource: NSObject, SectionedDataSource {
  
  typealias Item = QueuedData
  
  /// An internal serial queue for synchronized access.
  private var sQueue = DispatchQueue(
    label: "ink.codes.podest.QueueDataSource-\(UUID().uuidString).sQueue")
  
  private var worker = DispatchQueue(
    label: "ink.codes.podest.QueueDataSource-\(UUID().uuidString).worker")
  
  private var _sections = [Section<QueuedData>]()
  
  var sections: [Section<QueuedData>] {
    get {
      return sQueue.sync {
        return _sections
      }
    }
    set {
      sQueue.sync {
        _sections = newValue
      }
    }
  }
  
  private var observers = [NSObjectProtocol]()
  
  /// Adds all observers.
  func activate() {
    dispatchPrecondition(condition: .onQueue(DispatchQueue.main))
    
    assert(observers.isEmpty)

    observers.append(NotificationCenter.default.addObserver(
      forName: .FKQueueDidChange,
      object: Podest.userQueue,
      queue: .main
    ) { [weak self] notification in
      dispatchPrecondition(condition: .onQueue(DispatchQueue.main))
      self?.reload()
    })
  }
  
  private var invalidated = false
  
  /// Removes all observers.
  func invalidate() {
    dispatchPrecondition(condition: .onQueue(DispatchQueue.main))
    
    for observer in observers {
      NotificationCenter.default.removeObserver(observer)
    }
    observers.removeAll()
    
    updateCompletionBlock = nil
    reloading?.cancel()
    
    invalidated = true
  }
  
  private let userQueue: Queueing
  private let images: Images
  
  init(userQueue: Queueing, images: Images) {
    self.userQueue = userQueue
    self.images = images
    
    super.init()
  }
  
  deinit {
    precondition(invalidated)
  }
  
  /// Submitted when queue has been updated. Consumers must apply `completion`
  /// block when they are done, we are making time for snapshots with this.
  var updateCompletionBlock: ((Updates, Error?, _ completion: (() -> Void)?) -> Void)?

  private static func makeSections(items: [QueuedData]) -> [Section<QueuedData>] {
    var entries = Section<QueuedData>(
      id: QueuedSectionID.entry.rawValue, title: "Episodes")
    var feeds = Section<QueuedData>(
      id: QueuedSectionID.feed.rawValue, title: "Podcasts")
    
    for item in items {
      switch item {
      case .entry:
        entries.append(item: item)
      case .feed:
        feeds.append(item: item)
      }
    }
    
    return [entries, feeds].filter {
      !$0.items.isEmpty
    }
  }
  
  private func merge(items: [QueuedData]) -> Updates {
    assert(!Thread.isMainThread)

    let sections = QueueDataSource.makeSections(items: items)
    let updates = self.update(merging: sections)
    
    self.sections = sections

    return updates
  }

  private weak var reloading: Operation?

  /// Reloads the queue locally, without updating, but fetching missing items
  /// remotely.
  func reload(completionBlock: ((Error?) -> Void)? = nil) {
    if completionBlock == nil {
      guard reloading == nil else {
        os_log("ignoring redundant queue reloading request", log: log)
        return
      }
    }
    
    var acc = [QueuedData]()

    os_log("locally reloading queue", log: log, type: .debug)

    reloading = userQueue.populate(entriesBlock: { entries, error in
      os_log("accumulating reloaded entries", log: log, type: .debug)

      dispatchPrecondition(condition: .notOnQueue(.main))

      if let er = error {
        switch er {
        case FeedKitError.missingEntries(let locators):
          os_log("missing entries: %{public}@", log: log, locators)
        default:
          fatalError("unhandled error: \(String(describing: error))")
        }
      }

      for entry in entries {
        acc.append(.entry(entry))
      }
    }) { error in
      os_log("queue reloading complete", log: log, type: .debug)

      dispatchPrecondition(condition: .notOnQueue(.main))

      let relevantError: Error? = {
        guard let er = error as? FeedKitError else {
          return error
        }
        switch er {
        case .cancelledByUser:
          os_log("reloading cancelled by user", log: log, type: .debug)
          return nil
        default:
          return er
        }
      }()

      let updates = self.merge(items: acc)

      self.updateCompletionBlock?(updates, relevantError) {
        DispatchQueue.global().async {
          completionBlock?(relevantError)
        }
      }
    }
  }
  
  func shouldUpdate(outside deadline: TimeInterval = 3600) -> Bool {
    let k = UserDefaults.lastUpdateTimeKey
    let ts = UserDefaults.standard.double(forKey: k)
    let now = Date().timeIntervalSince1970
    let yes = now - ts > deadline
    
    if yes {
      UserDefaults.standard.set(now, forKey: k)
    }
    
    return yes
  }

  private var lastTimeFilesHaveBeenRemoved: TimeInterval = 0

  /// Returns a block to check if downloaded files should be removed now, where
  /// block creation time is used for comparison.
  ///
  /// We do not want to do this IO too often, thus it’s limited to once per day
  /// per uptime, when no new data has been received from the triggering update
  /// and we are in the background.
  private func makeShouldRemoveBlock() -> (Bool) -> Bool {
    let now = Date().timeIntervalSince1970
    let stale = now - lastTimeFilesHaveBeenRemoved > 86400
    
    return { newData in
      guard stale,
        !newData,
        UIApplication.shared.applicationState == .background else {
        return false
      }

      self.lastTimeFilesHaveBeenRemoved = now

      return true
    }
  }
  
  /// Reloads and, minding a timely grace `window`, updates the queue.
  /// **Always** asks the system to download media files in the background and
  /// sometimes to remove unnecessary files.
  ///
  /// Since we are downloading to the cache directory, removing stale files
  /// should be performed from time to time, but isn’t essential.
  func update(
    minding window: TimeInterval = 3600,
    completionHandler: ((Bool, Error?) -> Void)? = nil)
  {
    os_log("updating queue", log: log, type: .debug)

    let shouldUpdate = self.shouldUpdate(outside: window)
    let shouldRemove = self.makeShouldRemoveBlock()
    
    func next() {
      // Reloading first providing a starting point to update from.
      reload { error in
        // In this block, errors are mostly just logged, not actually handled.
        if let er = error {
          os_log("tolerating queue reloading error: %{public}@",
                 log: log, String(describing: er))
        }
        
        // Executes completion block after preloading queue, sometimes removing
        // stale files.
        func preload(forwarding newData: Bool, updateError: Error?) -> Void {
          let rm = shouldRemove(newData)

          Podest.files.preloadQueue(removingFiles: rm) { error in
            if let er = error {
              os_log("queue preloading error: %{public}@",
                     log: log, type: .debug, er as CVarArg)
            }
            DispatchQueue.main.async {
              completionHandler?(newData, updateError)
            }
          }
        }
        
        guard shouldUpdate else {
          os_log("ignoring excessive queue update request",
                 log: log, type: .debug)
          return preload(forwarding: false, updateError: nil)
        }

        Podest.userLibrary.update { newData, error in
          if let er = error {
            os_log("queue updating error: %{public}@",
                   log: log, type: .debug, er as CVarArg)
          }
          if newData {
            os_log("queue updating complete with new data",
                   log: log, type: .debug)
          } else {
            os_log("queue updating complete without data",
                   log: log, type: .debug)
          }
          
          preload(forwarding: newData, updateError: error)
        }
      }
    }
    
    // For simulators not receiving remote notifications, during
    // pull-to-refresh, we pull iCloud manually, making testing while
    // working on sync less erratic.
    
    #if arch(i386) || arch(x86_64)
    guard window <= 60 else {
      return next()
    }

    os_log("** pulling iCloud in simulator", log: log, type: .debug)

    Podest.iCloud.pull { newData, error in
      if let er = error {
        os_log("pulling iCloud failed: %{public}@",
               log: log, er as CVarArg)
      }
      next()
    }
    #else
    next()
    #endif
  }
  
  // MARK: UITableViewDataSourcePrefetching
  
  var _requests: [ImageRequest]?
  
  /// The in-flight image prefetching requests. This property is serialized.
  private var requests: [ImageRequest]? {
    get {
      return sQueue.sync {
        return _requests
      }
    }
    set {
      sQueue.sync {
        _requests = newValue
      }
    }
  }
}

// MARK: - Configuring a Table View

extension QueueDataSource: UITableViewDataSource {
  
  func numberOfSections(in tableView: UITableView) -> Int {
    return sections.count
  }
  
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int
  ) -> Int {
    return sections[section].count
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath
  ) -> UITableViewCell {
    guard let item = itemAt(indexPath: indexPath) else {
      fatalError("no item at index path: \(indexPath)")
    }
    
    switch item {
    case .entry(let entry):
      let cell = tableView.dequeueReusableCell(
        withIdentifier: Cells.image.id, for: indexPath) as! FKImageCell
      return cell.configure(with: entry)
    case .feed:
      // We might reuse the feed cell from search here.
      fatalError("niy")
    }
    
  }
  
}

// MARK: - EntryDataSource

extension QueueDataSource: EntryIndexPathMapping {
  
  func entry(at indexPath: IndexPath) -> Entry? {
    guard let item = itemAt(indexPath: indexPath) else {
      return nil
    }
    switch item {
    case .entry(let entry):
      return entry
    case .feed:
      return nil
    }
  }
  
  func indexPath(matching entry: Entry) -> IndexPath? {
    for (sectionIndex, section) in sections.enumerated() {
      for (itemIndex, item) in section.items.enumerated() {
        if case .entry(let itemEntry) = item {
          if itemEntry == entry {
            return IndexPath(item: itemIndex, section: sectionIndex)
          }
        }
      }
    }
    return nil
  }
  
}

// MARK: - Handling Swipe Actions

extension QueueDataSource {
  
  /// Returns a fresh contextual action handler for the row at `indexPath`,
  /// dequeueing its episode, when submitted.
  func makeDequeueHandler(
    forRowAt indexPath: IndexPath,
    of tableView: UITableView) -> UIContextualAction.Handler {
    func handler(
      action: UIContextualAction,
      sourceView: UIView,
      completionHandler: @escaping (Bool) -> Void) {
      guard let entry = self.entry(at: indexPath) else {
        return
      }
      self.userQueue.dequeue(entry: entry) { guids, error in
        guard error == nil else {
          os_log("dequeue error: %{public}@", type: .error, error! as CVarArg)
          return DispatchQueue.main.async {
            completionHandler(false)
          }
        }
    
        DispatchQueue.main.async {
          completionHandler(true)
        }
      }
    }
    return handler
  }
  
}

// MARK: - UITableViewDataSourcePrefetching

extension QueueDataSource: UITableViewDataSourcePrefetching  {
  
  private func imaginables(for indexPaths: [IndexPath]) -> [Imaginable] {
    return indexPaths.compactMap { indexPath in
      guard let item = itemAt(indexPath: indexPath) else {
        return nil
      }
      switch item {
      case .entry(let entry):
        return entry
      default:
        return nil
      }
    }
  }
  
  func tableView(
    _ tableView: UITableView,
    prefetchRowsAt indexPaths: [IndexPath]) {
    let images = self.images
    DispatchQueue.global().async {
      let items = self.imaginables(for: indexPaths)
      let size = CGSize(width: 60, height: 60)
      let reqs = images.prefetchImages(for: items, at: size, quality: .medium)
      self.requests = reqs
    }
  }
  
  func tableView(
    _ tableView: UITableView,
    cancelPrefetchingForRowsAt indexPaths: [IndexPath]) {
    let images = self.images
    DispatchQueue.global().async {
      guard let reqs = self.requests else {
        return
      }
      // Ignoring indexPaths, relying on the repo to do the right thing.
      images.cancel(prefetching: reqs)
      self.requests = nil
    }
  }
  
}
