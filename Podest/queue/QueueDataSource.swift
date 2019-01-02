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

/// Provides access to queue and subscription data.
final class QueueDataSource: NSObject, SectionedDataSource {
  
  /// Enumerates queue data source item types.
  enum Item: Hashable {
    case entry(Entry)
    case feed(Feed)
    case message(NSAttributedString)
  }
  
  /// An internal serial queue for synchronized access.
  private var sQueue = DispatchQueue(
    label: "ink.codes.podest.QueueDataSource-\(UUID().uuidString).sQueue")
  
  private var _sections = [Section<Item>(
    items: [.message(StringRepository.loadingQueue())]
  )]

  /// Accessing the sections of the table view is synchronized.
  var sections: [Section<Item>] {
    get {
      return sQueue.sync { _sections }
    }
    set {
      sQueue.sync { _sections = newValue }
    }
  }

  /// This data source is showing a message.
  var isMessage: Bool {
    if case .message? = sections.first?.first {
      return true
    }

    return false
  }
  
  private var invalidated = false
  
  /// Removes all observers.
  func invalidate() {
    dispatchPrecondition(condition: .onQueue(DispatchQueue.main))

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

  private static func makeSections(
    items: [Item],
    error: Error? = nil
  ) -> [Section<Item>] {
    var messages = Section<Item>()

    guard !items.isEmpty else {
      let text = (error != nil ?
        StringRepository.message(describing: error!) : nil)
        ?? StringRepository.emptyQueue()
      messages.append(.message(text))
      return [messages]
    }

    var entries = Section<Item>(title: "Episodes")
    var feeds = Section<Item>(title: "Podcasts")

    for item in items {
      switch item {
      case .entry:
        entries.append(item)
      case .feed:
        feeds.append(item)
      case .message:
        messages.append(item)
      }
    }

    guard messages.isEmpty else {
      precondition(messages.count == 1)
      return [messages]
    }
    
    return [entries, feeds].filter {
      !$0.isEmpty
    }
  }

  /// Drafts updates from `items` and `error` with `sections` as current state.
  private static func makeUpdates(
    sections current: [Section<Item>],
    items: [Item],
    error: Error? = nil
  ) -> ([Section<Item>], Updates) {
    let sections = makeSections(items: items, error: error)
    let updates = makeUpdates(old: current, new: sections)

    return (sections, updates)
  }

  private weak var reloading: Operation?

  /// Reloads the queue locally, fetching missing items remotely if necessary,
  /// without committing sections. That’s our users’ job, preferably in
  /// `performBatchUpdates(_:completion:)`.
  ///
  /// - Parameters:
  ///   - completionBlock: A block that executes on the main queue when
  /// reloading completes, receiving new, not yet committed sections, the diff,
  /// and an error if something went wrong.
  func reload(completionBlock: (([Section<Item>], Updates, Error?) -> Void)? = nil) {
    dispatchPrecondition(condition: .onQueue(.main))

    if completionBlock == nil {
      guard reloading == nil else {
        os_log("ignoring redundant queue reloading request", log: log)
        return
      }
    }

    var acc = [Item]()

    os_log("reloading queue", log: log, type: .debug)

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

      let (sections, updates) = QueueDataSource.makeUpdates(
        sections: self.sections,
        items: acc,
        error: error ?? self.updateError
      )

      DispatchQueue.main.async {
        completionBlock?(sections, updates, error)
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

  /// Returns a block for checking if downloaded files should be removed now,
  /// where block creation time is used for comparison. It submits its work
  /// to the main queue, calling the completionBlock from there.
  ///
  /// We do not want to do this IO too often, thus it’s limited to once per day
  /// per uptime, when no new data has been received from the triggering update
  /// and we are in the background.
  private func makeShouldRemoveBlock() -> (Bool, @escaping (Bool) -> Void) -> Void {
    let now = Date().timeIntervalSince1970
    let stale = now - lastTimeFilesHaveBeenRemoved > 86400
    
    return { newData, completionBlock in
      DispatchQueue.main.async {
        guard stale,
          !newData,
          UIApplication.shared.applicationState == .background else {
          return completionBlock(false)
        }

        self.lastTimeFilesHaveBeenRemoved = now

       completionBlock(true)
      }

    }
  }

  private var _updateError: Error?

  private var updateError: Error? {
    get { return sQueue.sync { _updateError } }
    set { sQueue.sync { _updateError = newValue } }
  }
  
  /// Updates the queue, reloading current items to update from, and asks the
  /// system to download enclosed media files in the background. Fuzzy
  /// preloading of episodes in limited batches, aquiring all files eventually.
  ///
  /// Too frequent updates are ignored. Despite downloading to the cache
  /// directory, we are removing stale files at appropriate times. Batches are
  /// limited to 64 files for downloads and 16 files for deletions.
  ///
  /// - Parameters:
  ///   - window: Threshold in seconds, below which, after reloading and before
  /// preloading, updating is skipped.
  ///   - completionHandler: This block gets submitted to the main queue when
  /// all is done, receiving a Boolean, indicating new data, and an error value
  /// if something went wrong.
  func update(
    minding window: TimeInterval = 3600,
    considering error: Error? = nil,
    completionHandler: ((Bool, Error?) -> Void)? = nil)
  {
    os_log("updating queue", log: log, type: .debug)

    updateError = error

    let shouldUpdate = self.shouldUpdate()
    let shouldRemove = self.makeShouldRemoveBlock()

    func preload(forwarding newData: Bool, updateError: Error?) -> Void {
      shouldRemove(newData) { rm in
        dispatchPrecondition(condition: .onQueue(.main))

        DispatchQueue.global().async {
          Podest.files.preloadQueue(removingFiles: rm) { error in
            if let er = error {
              os_log("queue preloading error: %{public}@",
                     log: log, type: .debug, er as CVarArg)
            }

            DispatchQueue.main.async {
              os_log("updating complete", log: log, type: .debug)
              completionHandler?(newData, updateError)
            }
          }
        }
      }
    }

    func next() {
      guard shouldUpdate else {
        os_log("ignoring excessive queue update request",
               log: log, type: .debug)
        return preload(forwarding: false, updateError: nil)
      }

      Podest.userLibrary.update { newData, error in
        if let er = error {
          os_log("updating error: %{public}@", log: log, er as CVarArg)
          self.updateError = error
        }

        os_log("queue updating complete: %{public}i",
               log: log, type: .debug, newData)

        preload(forwarding: newData, updateError: error)
      }
    }
    
    // For simulators, not receiving remote notifications, we are pulling
    // iCloud manually, making working on iCloud sync less erratic.
    
    #if arch(i386) || arch(x86_64)
    guard window <= 60 else {
      return next()
    }

    os_log("** simulating iCloud pull", log: log)

    Podest.iCloud.pull { newData, error in
      if let er = error {
        os_log("** simulated iCloud pull failed: %{public}@",
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

  /// Registers nib objects with `tableView` under identifiers.
  static func registerCells(with tableView: UITableView) {
    let cells = [
      (Cells.message.nib, Cells.message.id),
      (Cells.subtitle.nib, Cells.subtitle.id)
    ]

    for cell in cells {
      tableView.register(cell.0, forCellReuseIdentifier: cell.1)
    }
  }
  
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

    tableView.separatorStyle = .singleLine
    
    switch item {
    case .entry(let entry):
      let cell = tableView.dequeueReusableCell(
        withIdentifier: Cells.subtitle.id, for: indexPath
      ) as! SubtitleTableViewCell

      cell.item = entry
      cell.textLabel?.text = entry.title
      cell.detailTextLabel?.text = StringRepository.episodeCellSubtitle(for: entry)
      cell.imageView?.image = UIImage(named: "Oval")
      cell.imageQuality = .high
    
      return cell
    case .feed:
      // We might reuse the feed cell from search here.
      fatalError("niy")
    case .message(let text):
      let cell = tableView.dequeueReusableCell(
        withIdentifier: Cells.message.id, for: indexPath
      ) as! MessageTableViewCell

      cell.titleLabel.attributedText = text
      cell.selectionStyle = .none
      cell.targetHeight = tableView.bounds.height * 0.6

      tableView.separatorStyle = .none

      return cell
    }
  }

  func tableView(
    _ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
    if case .message? = itemAt(indexPath: indexPath) {
      return false
    }

    return true
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
    case .feed, .message:
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

    // Jumping through extra hoops for smooth scrolling is worth it.

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
