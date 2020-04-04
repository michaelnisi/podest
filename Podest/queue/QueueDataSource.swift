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
import BatchUpdates
import Playback

private let log = OSLog(subsystem: "ink.codes.podest", category: "queue")

/// Provides access to queue and subscription data.
final class QueueDataSource: NSObject, SectionedDataSource {

  /// Enumerates queue data source item types.
  enum Item: Hashable {
    
    /// An enqueued entry and wether it has been played.
    case entry(Entry, Bool)
    
    /// A subscribed feed. However, not in use at the moment.
    case feed(Feed)
    
    /// A (single) message to display.
    case message(NSAttributedString)
  }

  /// An internal serial queue for synchronized access.
  private var sQueue = DispatchQueue(
    label: "ink.codes.podest.QueueDataSource-\(UUID().uuidString)",
    target: .global(qos: .userInteractive)
  )

  private var _sections: [Array<Item>] = [
    [.message(StringRepository.loadingQueue)]
  ]

  var isEmpty: Bool {
    guard let first = sections.first?.first, case .message = first else {
      return sections.isEmpty
    }

    return true
  }

  /// Accessing the sections of the table view is synchronized.
  var sections: [Array<Item>] {
    get {
      return sQueue.sync { _sections }
    }
    set {
      sQueue.sync { _sections = newValue }
    }
  }

  /// The previous trait collection.
  var previousTraitCollection: UITraitCollection?

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
    dispatchPrecondition(condition: .onQueue(.main))
    reloading?.cancel()

    invalidated = true
  }

  let userQueue: Queueing
  let store: Shopping
  let files: Downloading
  let userLibrary: Subscribing
  let images: Images
  let playback: Playback
  let iCloud: UserSyncing

  init(
    userQueue: Queueing,
    store: Shopping,
    files: Downloading,
    userLibrary: Subscribing,
    images: Images,
    playback: Playback,
    iCloud: UserSyncing
  ) {
    os_log("initializing queue data source", log: log, type: .info)

    self.userQueue = userQueue
    self.store = store
    self.files = files
    self.userLibrary = userLibrary
    self.images = images
    self.playback = playback
    self.iCloud = iCloud
  }

  deinit {
    precondition(invalidated)
  }

  private static func makeSections(
    items: [Item],
    error: Error? = nil
  ) -> [Array<Item>] {
    var messages = [Item]()

    guard !items.isEmpty else {
      let text = (error != nil ?
        StringRepository.message(describing: error!) : nil)
        ?? StringRepository.emptyQueue
      messages.append(.message(text))
      return [messages]
    }

    var entries = [Item]()
    var feeds = [Item]()

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
    sections current: [Array<Item>],
    items: [Item],
    error: Error? = nil
  ) -> [[Change<Item>]] {
    let sections = makeSections(items: items, error: error)
    let changes = makeChanges(old: current, new: sections)

    return changes
  }

  /// This block receives the currently enqueued entries with each change.
  var entriesBlock: (([Entry]) -> Void)?

  private weak var reloading: Operation?
  
  private func isUnplayed(url: String?) -> Bool {
    guard let uid = url else {
      return false
    }
    
    return playback.isUnplayed(uid: uid)
  }

  /// Reloads the queue locally, fetching missing items remotely if necessary.
  ///
  /// - Parameters:
  ///   - completionBlock: A block that executes on the main queue when
  /// reloading completes, receiving the changes and maybe an error.
  ///
  /// We are not commiting sections here. That’s our users’ job, preferably in
  /// `performBatchUpdates(_:completion:)` or now with our very own amazing
  /// `commit(batch:performingWith:)`.
  func reload(completionBlock: (([[Change<Item>]], Error?) -> Void)? = nil) {
    dispatchPrecondition(condition: .onQueue(.main))
    
    if completionBlock == nil {
      guard reloading == nil else {
        os_log("ignoring redundant queue reloading request", log: log)
        return
      }
    }

    var acc = [Item]()

    os_log("reloading queue", log: log, type: .debug)

    reloading = userQueue.populate(entriesBlock: { [weak self] entries, error in
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
        acc.append(.entry(
          entry, 
          self?.isUnplayed(url: entry.enclosure?.url) ?? false)
        )
      }

      DispatchQueue.main.async {
        self?.entriesBlock?(entries)
      }
    }) { error in
      os_log("queue reloading complete", log: log, type: .debug)

      dispatchPrecondition(condition: .notOnQueue(.main))

      let changes = QueueDataSource.makeUpdates(
        sections: self.sections,
        items: acc,
        error: error ?? self.updateError
      )

      DispatchQueue.main.async {
        completionBlock?(changes, error)
      }
    }
  }

  /// Returns `true` if the time interval between the last time this method
  /// was executed is larger than `deadline`, which defaults to one hour.
  ///
  /// - Parameters:
  ///   - deadline: Stay outside of this time window.
  ///   - setting: Pass `false` for just asking, not setting a new time.
  private func shouldUpdate(
    outside deadline: TimeInterval = 3600,
    setting: Bool = true
  ) -> Bool {
    let k = UserDefaults.lastUpdateTimeKey
    let ts = UserDefaults.standard.double(forKey: k)

    let now = Date().timeIntervalSince1970
    let diff = now - ts
    let yes = diff > deadline

    if yes {
      if setting {
        UserDefaults.standard.set(now, forKey: k)
      }
    } else {
      os_log("should not update: %f < %f", log: log, type: .debug, diff, deadline)
      DispatchQueue.global(qos: .utility).async {
        Podest.files.preloadQueue(removingFiles: false, completionHandler: nil)
      }
    }

    return yes
  }

  /// Ready to update?
  var isReady: Bool {
    return shouldUpdate(setting: false)
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
  /// The app must not be expired for this operation.
  ///
  /// - Parameters:
  ///   - window: Within this time interval since the last update, updating is
  /// skipped. However, preloading and removing files might be performed.
  ///   - error: An upstream error that should be considered.
  ///   - completionHandler: This block gets submitted to the main queue when
  /// all is done, receiving a Boolean, indicating new data, and an error value
  /// if something went wrong.
  func update(
    minding window: TimeInterval = 3600,
    considering error: Error? = nil,
    completionHandler: ((Bool, Error?) -> Void)? = nil)
  {
    guard !store.isExpired() else {
      os_log("free trial expired", log: log)
      return DispatchQueue.main.async {
        completionHandler?(false, error)
      }
    }

    updateError = error

    let shouldUpdate = self.shouldUpdate(outside: window)
    let shouldRemove = self.makeShouldRemoveBlock()

    func preload(forwarding newData: Bool, updateError: Error?) -> Void {
      shouldRemove(newData) { rm in
        dispatchPrecondition(condition: .onQueue(.main))

        os_log("preloading and removing files: %i", log: log, type: .debug, rm)

        DispatchQueue.global(qos: .utility).async { [weak self] in
          self?.files.preloadQueue(removingFiles: rm) { error in
            if let er = error {
              os_log("queue preloading error: %{public}@",
                     log: log, type: .debug, er as CVarArg)
            }

            os_log("updating complete: %i",
                   log: log, type: .debug, shouldUpdate)

            DispatchQueue.main.async {
              completionHandler?(newData, updateError)
            }
          }
        }
      }
    }

    // Normal code path begins here, in next.

    func next() {
      guard shouldUpdate else {
        os_log("ignoring excessive queue update request",
               log: log, type: .debug)
        return preload(forwarding: false, updateError: nil)
      }

      os_log("updating queue", log: log, type: .debug)

      userLibrary.update { newData, error in
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
    // iCloud manually, for less erratic conditions while working on sync.

    #if targetEnvironment(simulator)
    guard window <= 60 else {
      return next()
    }

    os_log("** simulating iCloud pull", log: log)

    iCloud.pull { newData, error in
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

// MARK: - Image Loading

extension QueueDataSource {
  
  /// Loads image into `cell` if cell is not already configured to load said
  /// image.
  private func prepareImage(cell: SubtitleTableViewCell, displaying entry: Entry) {
    guard cell.tag != entry.hashValue else {
      return
    }
    
    images.cancel(displaying: cell.imageView)
    cell.invalidate(image: UIImage(named: "Oval"))

    cell.tag = entry.hashValue
    
    cell.layoutSubviewsBlock = { [weak self] imageView in
      guard cell.tag == entry.hashValue else {
        return
      }
      
      self?.images.loadImage(
        representing: entry,
        into: imageView,
        options: FKImageLoadingOptions(
          fallbackImage: UIImage(named: "Oval"),
          quality: .medium,
          isDirect: true
        )
      )
    }
  }
}

// MARK: - UITableViewDataSource

extension QueueDataSource: UITableViewDataSource {

  /// Registers nib objects with `tableView` under identifiers.
  static func registerCells(with tableView: UITableView) {
    let cells = [
      (UITableView.Nib.message.nib, UITableView.Nib.message.id),
      (UITableView.Nib.subtitle.nib, UITableView.Nib.subtitle.id)
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
  
  private static func makeAccessory() -> UIView {
    let frame = CGRect(x: 0, y: 0, width: 18, height: 18)
    let view = PieView(frame: frame)
    view.percentage = 1.0
    view.backgroundColor = .clear

    return view
  }
  
  @discardableResult
  private static func updateIsUnplayed(
    cell: UITableViewCell, isUnplayed: Bool) -> UITableViewCell {
    if cell.accessoryView == nil {
      cell.accessoryView =  QueueDataSource.makeAccessory()
      cell.tintColor = UIColor(named: "Purple")
    }
    
    if let pie = cell.accessoryView as? PieView {
      pie.percentage = isUnplayed ? 1.0 : 0
    }
    
    return cell
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath
  ) -> UITableViewCell {
    guard let item = itemAt(indexPath: indexPath) else {
      fatalError("no item at index path: \(indexPath)")
    }

    tableView.separatorStyle = .singleLine

    switch item {
    case .entry(let entry, let isUnplayed):
      let cell = tableView.dequeueReusableCell(
        withIdentifier: UITableView.Nib.subtitle.id, for: indexPath
      ) as! SubtitleTableViewCell

      // Supporting Dynamic Type.
      if tableView.traitCollection != previousTraitCollection {
        cell.textLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
        cell.textLabel?.numberOfLines = 0

        cell.detailTextLabel?.font = UIFont.preferredFont(forTextStyle: .body)
        cell.detailTextLabel?.numberOfLines = 0
      }

      prepareImage(cell: cell, displaying: entry)

      cell.textLabel?.text = entry.feedTitle ?? entry.title
      cell.detailTextLabel?.text = entry.title
      
      return QueueDataSource
        .updateIsUnplayed(cell: cell, isUnplayed: isUnplayed)
      
    case .feed:
      // We might reuse the feed cell from search here.
      fatalError("niy")
    case .message(let text):
      let cell = tableView.dequeueReusableCell(
        withIdentifier: UITableView.Nib.message.id, for: indexPath
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
    case .entry(let entry, _):
      return entry
    case .feed, .message:
      return nil
    }
  }

  func indexPath(matching entry: Entry) -> IndexPath? {
    for (sectionIndex, section) in sections.enumerated() {
      for (itemIndex, item) in section.enumerated() {
        if case .entry(let itemEntry, _) = item {
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
  /// dequeueing its episode when submitted.
  func makeDequeueHandler(
    indexPath: IndexPath, 
    tableView: UITableView
  ) -> UIContextualAction.Handler {
    return { [weak self] action, sourceView, completionHandler in
      guard let entry = self?.entry(at: indexPath) else {
        return completionHandler(false)
      }

      self?.userQueue.dequeue(entry: entry) { guids, error in
        guard error == nil else {
          os_log("dequeue error: %{public}@", type: .error, error! as CVarArg)

          return DispatchQueue.main.async {
            completionHandler(false)
          }
        }

        DispatchQueue.main.async {
          self?.sections[0].remove(at: indexPath.row)
          tableView.deleteRows(at: [indexPath], with: .fade)
          completionHandler(true)
        }
      }
    }
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
      case .entry(let entry, _):
        return entry
      default:
        return nil
      }
    }
  }

  /// Assuming the the first row is representative.
  private func estimateCellSize(tableView: UITableView) -> CGSize {
    let ip = IndexPath(row: 0, section: 0)
    let tmp = !self.isEmpty ? tableView.cellForRow(at: ip) : nil

    return tmp?.imageView?.bounds.size ?? CGSize(width: 82, height: 82)
  }

  func tableView(
    _ tableView: UITableView,
    prefetchRowsAt indexPaths: [IndexPath]
  ) {
    let items = imaginables(for: indexPaths)
    let size = estimateCellSize(tableView: tableView)

    images.prefetchImages(representing: items, at: size, quality: .medium)
  }

  func tableView(
    _ tableView: UITableView,
    cancelPrefetchingForRowsAt indexPaths: [IndexPath]
  ) {
    let items = imaginables(for: indexPaths)
    let size = estimateCellSize(tableView: tableView)

    images.cancelPrefetching(items, at: size, quality: .medium)
  }
}

// MARK: - Updating Playback State

extension QueueDataSource {
  
  func tableView(_ tableView: UITableView, updateCellMatching entry: Entry, isUnplayed: Bool) {
    guard let indexPath = indexPath(matching: entry), 
      let cell = tableView.cellForRow(at: indexPath) else {
      return
    }
    
    QueueDataSource.updateIsUnplayed(cell: cell, isUnplayed: isUnplayed)
    
    sections[indexPath.section][indexPath.row] = .entry(entry, isUnplayed)
  }
}
