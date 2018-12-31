//
//  ListDataSource.swift
//  Podest
//
//  Created by Michael on 11/8/17.
//  Copyright © 2017 Michael Nisi. All rights reserved.
//

import UIKit
import FeedKit
import os.log

private let log = OSLog.disabled

private enum ListDataSourceEvent {
  case feedFetched(Feed?, Error?)
  case entriesFetched([ListDataSource.Item]?, Error?)
  case cancel
  case update(ListDataSource.UpdateRequest)
}

private enum ListDataSourceState {
  case fetchingFeed(ListDataSource.UpdateRequest)
  case fetchingEntries(ListDataSource.UpdateRequest)
  case offline
  case ready
}

/// Provides data for a table view displaying a podcast.
final class ListDataSource: NSObject, SectionedDataSource {
  
  /// Wraps update parameters.
  struct UpdateRequest {
    let url: String
    let feed: Feed?
    let forcing: Bool
    
    /// Returns a copy of this request but forced.
    fileprivate func makeForced() -> UpdateRequest {
      return UpdateRequest(url: url, feed: feed, forcing: true)
    }
  }
  
  /// Enumerates types of items that can be listed by this data source.
  enum Item: Equatable {
    case entry(Entry)

    static func ==(lhs: Item, rhs: Item) -> Bool {
      switch (lhs, rhs) {
      case (.entry(let a), .entry(let b)):
        return a == b
      }
    }
  }

  /// An internal serial queue for synchronized access.
  let sQueue = DispatchQueue(
    label: "ink.codes.podest.ListDataSource-\(UUID().uuidString).serial")

  var _sections = [Section<Item>]()

  var sections:  [Section<Item>] {
    get {
      return sQueue.sync {
        _sections
      }
    }

    set {
      sQueue.sync {
        _sections = newValue
      }
    }
  }

  /// The Browsing API for fetching feeds and entries.
  private let browser: Browsing

  /// Creates a new list data source.
  ///
  /// - Parameters:
  ///   - browser: The Browsing API for fetching feeds and entries.
  init(browser: Browsing) {
    self.browser = browser

    super.init()
  }
  
  private var state = ListDataSourceState.ready
  
  weak private var fetchingFeed: Operation? {
    willSet {
      fetchingFeed?.cancel()
    }
  }
  
  private weak var fetchingEntries: Operation? {
    willSet {
      fetchingEntries?.cancel()
    }
  }
  
  /// Serial queue for event handling.
  let fsmQueue = DispatchQueue(
    label: "ink.codes.podest.ListDataSource-\(UUID().uuidString).fsm")
  
  // MARK: Callbacks
  
  /// The block to execute once the feed has been fetched.
  var feedCompletionBlock: ((Feed) -> Void)?
  
  /// The block to execute with updates for the table view.
  var updatesCompletionBlock: ((Updates) -> Void)?
  
  /// The block to execute when fetching feed and entries has been completed
  /// with the second parameter being a formatted error message.
  private var completionBlock: ((Error?, NSAttributedString?) -> Void)?
 
}

// MARK: - Fetching Feed and Entries

extension ListDataSource {
  
  func removeAll() {
    DispatchQueue.global().async { [weak self] in
      let _ = self?.updates(for: [Item]())
    }
  }
  
  private func sections(for items: [Item]) -> [Section<Item>] {
    var entries = Section<Item>(title: "Episodes")
    
    for item in items {
      switch item {
      case .entry:
        entries.append(item)
      }
    }
    
    return [entries].filter {
      !$0.items.isEmpty
    }
  }
  
  private func updates(for items: [Item]) -> Updates {
    os_log("ListDataSource: updates for items: %@",
           log: log, type: .debug, items)
    
    dispatchPrecondition(condition: .notOnQueue(.main))

    let sections = self.sections(for: items)
    let updates = ListDataSource.makeUpdates(old: self.sections, new: sections)
    
    self.sections = sections
    
    return updates
  }
  
  private static func isCancelled(_ obj: Any?, error: Error?) -> Bool {
    if obj == nil, let er = error as? FeedKitError, case .cancelledByUser = er {
      return true
    }
    return false
  }
  
  @discardableResult
  private func fetchEntries(
    _ request: UpdateRequest,
    forwarding prevError: Error? = nil
  ) -> ListDataSourceState {
    let locators = [EntryLocator(url: request.url)]
    
    var acc = ([Entry](), [Error]())
    
    fetchingEntries = browser.entries(
      locators, force: request.forcing, entriesBlock: { error, entries in
        acc.0 = acc.0 + entries
        if let er = error {
          acc.1 = acc.1 + [er]
        }
    }) { [weak self] error in
      guard !ListDataSource.isCancelled(self, error: error) else {
        return
      }
      
      let (entries, entriesErrors) = acc

      if !request.forcing {
        guard entries.count > 3 else {
          os_log("reloading to fully populate: %{public}@",
                 log: log, type: .debug, request.url)
          self?.fetchEntries(request.makeForced())
          return
        }
      } else if entries.isEmpty {
        os_log("no entries: %{public}@", log: log, request.url)
      }
      
      let sorted = entries.sorted() {
        let a = $0.updated
        let b = $1.updated
        return a.compare(b) == .orderedDescending
      }
      
      let items = sorted.map { Item.entry($0) }
      
      // Errors are merely informative if we got items.
      let er = error ?? prevError ?? entriesErrors.first

      guard let latest = sorted.first,
        Podest.userLibrary.has(subscription: latest.feed) else {
        self?.process(event: .entriesFetched(items, er))
        return
      }

      // Experimentally, trying to automatically enqueue entries, expecting
      // user queue to ignore latest if it has been enqueued previously. This
      // filtering is implemented in FeedKit.EnqueueOperation now, but not
      // thoroughly tested yet.

      Podest.userQueue.enqueue(entries: [latest]) { enqueued, enqueueError in
        if let enqerr = enqueueError {
          os_log("enqueue error: %@", log: log, enqerr as CVarArg)
        }
        self?.process(event: .entriesFetched(items, er))
      }
    }
    
    return .fetchingEntries(request)
  }
  
  @discardableResult
  private func fetchFeed(_ request: UpdateRequest) -> ListDataSourceState {
    var acc: (Feed?, Error?)?
    
    let ttl: CacheTTL = request.forcing ? .none : .long
    
    fetchingFeed = browser.feeds(
      [request.url], ttl: ttl, feedsBlock: { error, feeds in
      precondition(acc == nil)
      acc = (feeds.first, error)
    }) { [weak self] error in
      guard !ListDataSource.isCancelled(self, error: error) else {
        return
      }
      
      guard error == nil,
        let (feed, feedError) = acc,
        let f = feed,
        feedError == nil else {
          self?.process(event: .feedFetched(nil, error ?? acc?.1))
          return
      }
      
      if !request.forcing {
        guard f.summary != nil else {
          os_log("retrying to aquire summary: %{public}@",
                 log: log, type: .debug, request.url)
          self?.fetchFeed(request.makeForced())
          return
        }

        os_log("** summary: %{public}@",
               log: log, type: .debug, f.summary!)
      }
      
      self?.process(event: .feedFetched(f, nil))
    }
    
    return .fetchingFeed(request)
  }
  
}

// MARK: - FSM

extension ListDataSource {

  /// Returns error message, assuming empty feed if `error` is `nil` or message
  /// suggests ignoring the error.
  private static func makeMessage(
    title: String, error: Error?) -> NSAttributedString {
    guard let er = error,
      let msg = StringRepository.message(describing: er) else {
      return StringRepository.emptyFeed(titled: title)
    }

    return msg
  }
  
  private func updateState(event: ListDataSourceEvent) -> ListDataSourceState {
    switch state {
    case .fetchingFeed(let req):
      switch event {
      case .cancel:
        fetchingFeed?.cancel()
        return .ready
      case .feedFetched(let feed, let error):
        if let f = feed {
          feedCompletionBlock?(f)
        }
        
        return fetchEntries(req, forwarding: error)
      default:
        fatalError("unhandled event")
      }
      
    case .fetchingEntries(let req):
      switch event{
      case .cancel:
        self.fetchingEntries?.cancel()
        return .ready
      case .entriesFetched(let items, let error):
        guard let it = items, !it.isEmpty else {
          let msg = ListDataSource.makeMessage(title: req.url, error: error)
          completionBlock?(error, msg)
          return .ready
        }

        // Either showing entries or the message. If we still got an error,
        // the receiver decides.

        updatesCompletionBlock?(updates(for: it))
        completionBlock?(error, nil)

        return .ready
      default:
        fatalError("unhandled event")
      }
      
    case .offline:
      switch event {
      case .cancel, .entriesFetched, .feedFetched, .update:
        return state
      }
      
    case .ready:
      switch event {
      case .update(let req):
        guard let f = req.feed, f.summary != nil else {
          return fetchFeed(req)
        }
        
        feedCompletionBlock?(f)
        
        return fetchEntries(req)
        
      case .cancel, .entriesFetched, .feedFetched:
        return state
      }
      
    }
  }
  
  /// Serially processes `event` for synchronized access of our state.
  private func process(event: ListDataSourceEvent) {
    fsmQueue.async { [weak self] in
      guard let me = self else {
        return
      }
      me.state = me.updateState(event: event)
    }
  }
  
}

// MARK: - API

extension ListDataSource {
  
  /// Cancels all operations.
  func cancel() {
    process(event: .cancel)
  }
  
  func update(
    _ request: UpdateRequest,
    completionBlock cb: ((Error?, NSAttributedString?) -> Void)?
  ) {
    os_log("** update: %@",
           log: log, type: .error, String(describing: request))
    self.completionBlock = cb
    process(event: .update(request))
  }
  
}

// MARK: - Configuring a Table View

extension ListDataSource: UITableViewDataSource {

  /// Registers nib objects with `tableView` under identifiers.
  static func registerCells(with tableView: UITableView) {
    let cells = [
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
  
  func tableView(
    _ tableView: UITableView,
    cellForRowAt indexPath: IndexPath
  )-> UITableViewCell {
    guard let item = itemAt(indexPath: indexPath) else {
      fatalError("no item at index path: \(indexPath)")
    }
    
    switch item {
    case .entry(let entry):
      let cell = tableView.dequeueReusableCell(
        withIdentifier: Cells.subtitle.id, for: indexPath
      ) as! SubtitleTableViewCell

      cell.textLabel?.text = entry.title
      cell.detailTextLabel?.text = StringRepository.episodeCellSubtitle(for: entry)
      cell.imageView?.image = nil

      return cell
    }
  }
  
}

// MARK: - EntryIndexPathMapping

extension ListDataSource: EntryIndexPathMapping {
  
  func entry(at indexPath: IndexPath) -> Entry? {
    guard let item = itemAt(indexPath: indexPath) else {
      return nil
    }

    switch item {
    case .entry(let entry):
      return entry
    }
  }

  /// Returns the first index path matching `entry`.
  func indexPath(matching entry: Entry) -> IndexPath? {
    for (s, section) in sections.enumerated() {
      for (r, item) in section.items.enumerated() {
        switch item {
        case .entry(let e):
          if e == entry {
            return IndexPath(row: r, section: s)
          }
        }
      }
    }

    return nil
  }

}
