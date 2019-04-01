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

/// Provides data for a table view displaying a podcast.
final class ListDataSource: NSObject, SectionedDataSource {

  /// Enumerates items provided by this data source.
  enum Item: Hashable {
    case feed(Feed, NSAttributedString?)
    case entry(Entry, String)
    case author(String)
    case message(NSAttributedString)
  }

  // MARK: - Operations

  /// The list data source coordinates its tasks with operations.
  class ListOperation: Operation, Receiving {

    let url: String
    let originalFeed: Feed?
    let forcing: Bool
    let isCompact: Bool

    init(
      url: String,
      originalFeed: Feed?,
      forcing: Bool = false,
      isCompact: Bool = false
    ) {
      self.url = url
      self.originalFeed = originalFeed
      self.forcing = forcing
      self.isCompact = isCompact

      super.init()
    }

    init(operation: ListOperation) {
      self.url = operation.url
      self.originalFeed = operation.originalFeed
      self.forcing = operation.forcing
      self.isCompact = operation.isCompact

      super.init()
    }

    override var description: String {
      return """
      ListDataSourceOperation: (\(url), \(originalFeed?.title ?? "none"), \
      \(forcing), \(isCompact))
      """
    }

    override func cancel() {
      super.cancel()
      
      for dep in dependencies {
        dep.cancel()
      }
    }

    /// This block receives new sections, changes, and an error.
    var updatesBlock: (([Array<Item>], [[Change<Item>]], Error?) -> Void)?

    /// This block receives the feed and an error.
    var feedBlock: ((Feed?, Error?) -> Void)?

    /// Accumulates previous `sections`, fresh `items`, and possibly an `error`
    /// into the next sections.
    ///
    /// Making the next sections structure is at the core of the data source.
    static func makeSections(
      sections current: [Array<Item>],
      items: [Item],
      error: Error?,
      isCompact: Bool
    ) -> [Array<Item>] {
      var messages = [Item]()

      guard !items.isEmpty else {
        guard let er = error,
          let text = StringRepository.message(describing: er) else {
          let t = StringRepository.emptyFeed()

          messages.append(.message(t))

          return [messages]
        }

        messages.append(.message(text))

        return [messages]
      }

      var header = Set<Item>()
      var entries = [Item]()
      var footer = Set<Item>()

      // Keeping some items.
      for section in current {
        for item in section {
          switch item {
          case .author:
            footer.insert(item)
          case .feed:
            guard !isCompact else {
              continue
            }
            header.insert(item)
          case .entry, .message:
            continue
          }
        }
      }

      for item in items {
        switch item {
        case .author:
          footer.insert(item)
        case .entry:
          entries.append(item)
        case .feed:
          guard !isCompact else {
            messages.append(.message(StringRepository.loadingEpisodes))
            continue
          }
          header.insert(item)
        case .message:
          messages.append(item)
        }
      }

      guard messages.isEmpty else {
        return [[messages.first!]]
      }

      return [Array(header), entries, Array(footer)].filter { !$0.isEmpty }
    }

    fileprivate static func makeUpdates(
      sections current: [Array<Item>],
      items: [Item],
      error: Error?,
      isCompact: Bool
    ) -> ([Array<Item>], [[Change<Item>]]) {
      let sections = makeSections(
        sections: current,
        items: items,
        error: error,
        isCompact: isCompact
      )

      let changes = makeChanges(old: current, new: sections)

      return (sections, changes)
    }

  }

  final private class FetchFeed: ListOperation, Providing {

    /// The current sections.
    var current: [Array<Item>]!

    /// The submitted items must be set, the dependent fetch entries operation
    /// relies on this.
    var submitted: [Array<Item>]?

    fileprivate func submitUpdatesBlockWith(
      _ feed: Feed, error: Error? = nil) -> Void {
      guard !isCancelled else {
        return
      }

      var items = [Item]()

      let summary = StringRepository.makeSummaryWithHeadline(feed: feed)

      items.append(.feed(feed, summary))

      if let author = feed.author {
        items.append(.author(author))
      }

      guard !isCancelled, !items.isEmpty else {
        return
      }

      let (sections, updates) = ListOperation.makeUpdates(
        sections: current,
        items: items,
        error: error,
        isCompact: isCompact
      )

      guard !isCancelled else {
        return
      }

      os_log("executing updates block", log: log, type: .debug)
      updatesBlock?(sections, updates, error)

      submitted = sections
    }

    var error: Error?

    override func main() {
      os_log("fetching feed", log: log, type: .debug)

      guard !isCancelled else {
        return
      }

      // Originally provided with a summary, we can short cut this.

      if let feed = originalFeed, feed.summary != nil {
        return submitUpdatesBlockWith(feed)
      }

      let foundFeed = findFeed()
      let error = findError()

      // Providing error to dependents, namely to FetchEntries.
      self.error = error

      os_log("executing feed block", log: log, type: .debug)
      feedBlock?(foundFeed, error)

      if let feed = foundFeed {
        submitUpdatesBlockWith(feed, error: error)
      }
    }

  }

  final private class FetchEntries: ListOperation {

    var locators: [EntryLocator]

    override init(operation: ListOperation) {
      self.locators = [EntryLocator(url: operation.url)]

      super.init(operation: operation)
    }

    func findCurrent() -> [Array<Item>]? {
      guard let p = dependencies.first(where: { $0 is FetchFeed })
        as? FetchFeed else {
        return nil
      }

      return p.submitted
    }

    override func main() {
      os_log("fetching entries", log: log, type: .debug)

      guard !isCancelled else {
        return
      }

      guard let current = findCurrent() else {
        return
      }

      let sorted = findEntries().sorted() {
        let a = $0.updated
        let b = $1.updated

        return a.compare(b) == .orderedDescending
      }

      let items = sorted.map {
        Item.entry($0, StringRepository.episodeCellSubtitle(for: $0))
      }

      let error = findError()

      let (sections, updates) = ListOperation.makeUpdates(
        sections: current,
        items: items,
        error: error,
        isCompact: isCompact
      )

      guard !isCancelled else {
        return
      }

      os_log("executing updates block", log: log, type: .debug)
      updatesBlock?(sections, updates, error)
    }

  }

  /// Fetches feed and entries.
  final class UpdateOperation: ListOperation {

    /// Creates a new update operation for fetching items.
    ///
    /// - Parameters:
    ///   - url: The URL of the podcast feed.
    ///   - originalFeed: The original feed object if available.
    ///   - forcing: Overrides cache settings, forcing reloading to some degree.
    override init(
      url: String,
      originalFeed: Feed?,
      forcing: Bool = false,
      isCompact: Bool = false) {
      super.init(
        url: url,
        originalFeed: originalFeed,
        forcing: forcing,
        isCompact: isCompact
      )

      os_log("initializing: ( %@, %@, %i, %i )", log: log, type: .debug,
             url, String(describing: originalFeed), forcing, isCompact)
    }

  }

  // MARK: - Properties

  private let browser: Browsing
  private let images: Images
  private let store: Expiring

  /// Creates a new list data source.
  ///
  /// - Parameters:
  ///   - browser: A browser for fetching feed and entries.
  ///   - images: An image loading API.
  ///   - store: For checking user status before updating a feed.
  init(browser: Browsing, images: Images, store: Expiring) {
    self.browser = browser
    self.images = images
    self.store = store

    super.init()
  }

  private let operationQueue = OperationQueue()

  var sections = [[Item.message(StringRepository.loadingPodcast)]]

  /// The previous trait collection.
  ///
  /// The previous trait collection can sometimes help to reason about efficient
  /// cell resetting, especially when using default cells, like we do.
  var previousTraitCollection: UITraitCollection?
}

// MARK: - Fetching Feed and Entries

extension ListDataSource {

  /// Drafts an update of this data source using `operation`. After fetching the
  /// feed, completing its summary, and fetching the entries, callback blocks
  /// are submitted to the main queue, from where changes should be committed.
  ///
  /// For its somewhat complex nature, we are using operation dependencies to
  /// model this task. Use the operation to configure details.
  ///
  /// We are assuming that users will commit changes back into this data source
  /// via its `commit(batch:performingWith:completionBlock:)`. Only then
  /// sequential data consistency of collection changes can be ensured.
  ///
  /// Cancels `operation` if user status doesn’t allow updating.
  ///
  /// - Parameters:
  ///   - operation: The update operation to execute.
  ///   - forcing: Overrides cache settings, replacing all entries.
  func update(_ operation: UpdateOperation, forcing: Bool = false) -> UpdateOperation {
    guard !store.isExpired() else {
      os_log("free trial expired", log: log)
      operation.cancel()
      return operation
    }

    os_log("updating: %@", log: log, type: .debug, operation)
    
    let a = FetchFeed(operation: operation)

    a.updatesBlock = operation.updatesBlock
    a.feedBlock = operation.feedBlock
    a.current = sections

    let noFeed = operation.originalFeed == nil
    let noSummary = operation.originalFeed?.summary == nil

    // Without feed, of course, we cannot have a summary.

    if noFeed || noSummary {
      a.addDependency(browser.feeds(
        [operation.url],
        ttl: noSummary ? .none : .long,
        feedsBlock: nil,
        feedsCompletionBlock: nil
      ))
    }

    let b = FetchEntries(operation: operation)

    b.updatesBlock = operation.updatesBlock

    b.addDependency(browser.entries(
      b.locators,
      force: forcing,
      entriesBlock: nil,
      entriesCompletionBlock: nil
    ))

    b.addDependency(a)

    operation.addDependency(b)

    operationQueue.addOperation(a)
    operationQueue.addOperation(b)
    operationQueue.addOperation(operation)

    return operation
  }

}

// MARK: - UITableViewDataSource

extension ListDataSource: UITableViewDataSource {

  /// Registers nib objects with `collectionView` under identifiers.
  static func registerCells(with tableView: UITableView) {
    let cells = [
      (UITableView.Nib.message.nib, UITableView.Nib.message.id),
      (UITableView.Nib.subtitle.nib, UITableView.Nib.subtitle.id),
      (UITableView.Nib.display.nib, UITableView.Nib.display.id)
    ]

    for cell in cells {
      tableView.register(cell.0, forCellReuseIdentifier: cell.1)
    }
  }

  func numberOfSections(in tableView: UITableView) -> Int {
    return sections.count
  }

  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return sections[section].count
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    guard let item = itemAt(indexPath: indexPath) else {
      fatalError("no item at index path: \(indexPath)")
    }

    switch item {

    case .feed(let feed, let summary):
      let cell = tableView.dequeueReusableCell(
        withIdentifier: UITableView.Nib.display.id, for: indexPath
      ) as! DisplayTableViewCell

      cell.selectionStyle = .none

      cell.images = images
      cell.imageQuality = .high
      cell.item = feed

      cell.textView?.attributedText = summary

      return cell
    case .entry(let entry, let subtitle):
      tableView.separatorStyle = .singleLine

      let cell = tableView.dequeueReusableCell(
        withIdentifier: UITableView.Nib.subtitle.id, for: indexPath
      ) as! SubtitleTableViewCell

      cell.accessoryType = .disclosureIndicator
      cell.selectionStyle = .default
      cell.backgroundColor = .white

      cell.images = nil
      cell.item = entry

      cell.textLabel?.font = .preferredFont(forTextStyle: .headline)
      cell.textLabel?.numberOfLines = 0

      cell.textLabel?.text = entry.title

      cell.detailTextLabel?.font = .preferredFont(forTextStyle: .body)
      cell.detailTextLabel?.numberOfLines = 3
      cell.detailTextLabel?.textColor = UIColor(named: "Asphalt")

      cell.detailTextLabel?.attributedText = nil
      cell.detailTextLabel?.text = subtitle

      return cell

    case .author(let author):
      let cell = tableView.dequeueReusableCell(
        withIdentifier: UITableView.Nib.subtitle.id, for: indexPath
      ) as! SubtitleTableViewCell

      cell.accessoryType = .none
      cell.selectionStyle = .none
      cell.backgroundColor = .white

      cell.images = nil
      cell.item = nil

      cell.textLabel?.attributedText = nil
      cell.textLabel?.text = nil

      cell.detailTextLabel?.font = .preferredFont(forTextStyle: .body)
      cell.detailTextLabel?.numberOfLines = 0
      cell.detailTextLabel?.textColor = UIColor(named: "Asphalt")

      cell.detailTextLabel?.attributedText = nil
      cell.detailTextLabel?.text = author

      return cell

    case .message(let text):
      tableView.separatorStyle = .none

      let cell = tableView.dequeueReusableCell(
        withIdentifier: UITableView.Nib.message.id, for: indexPath
      ) as! MessageTableViewCell

      cell.titleLabel.attributedText = text
      cell.selectionStyle = .none
      cell.targetHeight = tableView.bounds.height * 0.6

      return cell
    }
  }

  var isMessage: Bool {
    guard case .message? = sections.first?.first else {
      return false
    }

    return true
  }

}

// MARK: - EntryIndexPathMapping

extension ListDataSource: EntryIndexPathMapping {
  
  func entry(at indexPath: IndexPath) -> Entry? {
    dispatchPrecondition(condition: .onQueue(.main))

    guard let item = itemAt(indexPath: indexPath) else {
      return nil
    }

    guard case .entry(let entry, _) = item else {
      return nil
    }

    return entry
  }

  /// Returns the first index path matching `entry`.
  func indexPath(matching entry: Entry) -> IndexPath? {
    dispatchPrecondition(condition: .onQueue(.main))
    
    for (s, section) in sections.enumerated() {
      for (r, item) in section.enumerated() {
        guard case .entry(let e, _) = item, e == entry else {
          continue
        }

        return IndexPath(row: r, section: s)
      }
    }

    return nil
  }

}
