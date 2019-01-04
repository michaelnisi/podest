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
    case entry(Entry)
    case summary(NSAttributedString)
    case message(NSAttributedString)
    // TODO: case image(Imaginable)
  }

  /// An abstract operation that does nothing.
  class ListDataSourceOperation: Operation, Receiving {

    let url: String
    let originalFeed: Feed?
    let forcing: Bool

    init(url: String, originalFeed: Feed?, forcing: Bool = false) {
      self.url = url
      self.originalFeed = originalFeed
      self.forcing = forcing

      super.init()
    }

    init(operation: ListDataSourceOperation) {
      self.url = operation.url
      self.originalFeed = operation.originalFeed
      self.forcing = operation.forcing

      super.init()
    }

    override func cancel() {
      super.cancel()
      
      for dep in dependencies {
        dep.cancel()
      }
    }

    /// A block submitted to the main queue drafting a new state.
    var updatesBlock: (([Section<Item>], Updates, Error?) -> Void)?

    /// A block submitted to the main queue when the feed has been fetched.
    var feedBlock: ((Feed?, Error?) -> Void)?

    /// Accumulates previous `sections`, fresh `items`, and possibly an `error`
    /// into the next sections.
    ///
    /// Making the next sections structure is the core of the data source.
    static func makeSections(
      sections current: [Section<Item>],
      items: [Item],
      error: Error?
    ) -> [Section<Item>] {
      var messages = Section<Item>(id: 0)

      // TODO: Review error messaging

      guard !items.isEmpty else {
        let text = (error != nil ?
          StringRepository.message(describing: error!) : nil)
          ?? StringRepository.emptyFeed(titled: "Podcast")
        messages.append(.message(text))
        return [messages]
      }

      var summary = Set<Item>()
      var entries = Section<Item>(id: 2, title: "Episodes")

      // Fishing existing summary out of current sections.
      for section in current {
        for item in section.items {
          switch item {
          case .summary:
            summary.insert(item)
          case .entry, .message:
            continue
          }
        }
      }

      for item in items {
        switch item {
        case .entry:
          entries.append(item)
        case .summary:
          summary.insert(item)
        case .message:
          messages.append(item)
        }
      }

      return [Section<Item>(id: 1, items: Array(summary)), entries].filter {
        !$0.isEmpty
      }
    }

    static func makeUpdates(
      sections current: [Section<Item>],
      items: [Item],
      error: Error?
    ) -> ([Section<Item>], Updates) {
      let sections = makeSections(sections: current, items: items, error: error)
      let updates = ListDataSource.makeUpdates2(old: current, new: sections)

      return (sections, updates)
    }

  }

  final private class FetchFeed: ListDataSourceOperation, Providing {

    /// The current sections.
    var current: [Section<Item>]!

    var submitted: [Section<Item>]?

    fileprivate func submitSummary(_ string: String?, error: Error? = nil) -> Void {
      guard !isCancelled else {
        return
      }

      var items = [Item]()

      if let str = string {
        let text = StringRepository.attribute(summary: str)
        items.append(.summary(text))
      }

      let (sections, updates) = ListDataSourceOperation.makeUpdates(
        sections: current,
        items: items,
        error: error
      )

      guard !isCancelled else {
        return
      }

      // Assuming users commit sections.
      self.submitted = sections

      let cb = updatesBlock

      DispatchQueue.main.async {
        cb?(sections, updates, error)
      }
    }

    var error: Error?

    override func main() {
      guard !isCancelled else {
        return
      }

      if let summary = originalFeed?.summary {
        return submitSummary(summary)
      }

      let feed = findFeed()
      let error = findError()

      // Providing error to dependents, namely to FetchEntries.
      self.error = error

      let cb = feedBlock

      DispatchQueue.main.async {
        cb?(feed, error)
      }

      submitSummary(feed?.summary, error: error)
    }

  }

  final private class FetchEntries: ListDataSourceOperation {

    var locators: [EntryLocator]

    override init(operation: ListDataSourceOperation) {
      self.locators = [EntryLocator(url: operation.url)]

      super.init(operation: operation)
    }

    func findCurrent() -> [Section<Item>]? {
      guard let p = dependencies.first(where: { $0 is FetchFeed })
        as? FetchFeed else {
        return nil
      }

      return p.submitted
    }

    override func main() {
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

      let items = sorted.map { Item.entry($0) }

      let error = findError()

      let (sections, updates) = ListDataSourceOperation.makeUpdates(
        sections: current,
        items: items,
        error: error
      )

      guard !isCancelled else {
        return
      }

      let updatesBlock = self.updatesBlock

      DispatchQueue.main.async {
        updatesBlock?(sections, updates, error)
      }
    }

  }

  /// Fetches feed and entries.
  final class UpdateOperation: ListDataSourceOperation {

    /// Creates a new update operation for fetching items.
    ///
    /// - Parameters:
    ///   - url: The URL of the podcast feed.
    ///   - originalFeed: The original feed object if available.
    ///   - forcing: Overrides cache settings, forcing reloading to some degree.
    override init(url: String, originalFeed: Feed?, forcing: Bool = false) {
      super.init(url: url, originalFeed: originalFeed, forcing: forcing)
    }

    // This stooge operation has no main function and completes instantly.

  }

  private let operationQueue = OperationQueue()

  var sections = [Section<Item>]()

  private let browser: Browsing

  /// Creates a new list data source.
  ///
  /// - Parameters:
  ///   - browser: A browser for fetching feed and entries.
  init(browser: Browsing) {
    self.browser = browser

    super.init()
  }

}

// MARK: - Fetching Entries

extension ListDataSource {

  /// Drafts an update of this data source executing `operation`, fetching
  /// the feed, completing its summary, and fetching entries.
  ///
  /// Use the operation to configure this.
  func update(_ operation: UpdateOperation) {
    let a = FetchFeed(operation: operation)

    a.updatesBlock = operation.updatesBlock
    a.feedBlock = operation.feedBlock
    a.current = sections

    if operation.originalFeed?.summary == nil {
      a.addDependency(browser.feeds(
        [operation.url],
        ttl: .none,
        feedsBlock: nil,
        feedsCompletionBlock: nil
      ))
    }

    let b = FetchEntries(operation: operation)

    b.updatesBlock = operation.updatesBlock

    b.addDependency(browser.entries(
      b.locators,
      entriesBlock: nil,
      entriesCompletionBlock: nil
    ))

    b.addDependency(a)

    operation.addDependency(b)

    operationQueue.addOperation(a)
    operationQueue.addOperation(b)
    operationQueue.addOperation(operation)
  }

}

// MARK: - Providing Data and Views

extension ListDataSource: UICollectionViewDataSource {

  /// Registers nib objects with `collectionView` under identifiers.
  static func registerCells(with collectionView: UICollectionView) {
    let cells = [
      (UICollectionView.Nib.text.nib, UICollectionView.Nib.text.id)
    ]

    for cell in cells {
      collectionView.register(cell.0, forCellWithReuseIdentifier: cell.1)
    }
  }

  func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return sections[section].count
  }

  func numberOfSections(in collectionView: UICollectionView) -> Int {
    return sections.count
  }

  func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    guard let item = itemAt(indexPath: indexPath) else {
      fatalError("no item at index path: \(indexPath)")
    }

    switch item {
    case .entry(let entry):
      let cell = collectionView.dequeueReusableCell(
        withReuseIdentifier: UICollectionView.Nib.text.id, for: indexPath
      ) as! TextCollectionViewCell

      cell.label.text = entry.title

      return cell
    case .summary(let text):
      let cell = collectionView.dequeueReusableCell(
        withReuseIdentifier: UICollectionView.Nib.text.id, for: indexPath
      ) as! TextCollectionViewCell

      cell.label.attributedText = text

      return cell
    case .message(let text):
      let cell = collectionView.dequeueReusableCell(
        withReuseIdentifier: UICollectionView.Nib.text.id, for: indexPath
      ) as! TextCollectionViewCell

      cell.label.attributedText = text

      return cell
    }
  }

}

// MARK: - EntryIndexPathMapping

extension ListDataSource: EntryIndexPathMapping {
  
  func entry(at indexPath: IndexPath) -> Entry? {
    dispatchPrecondition(condition: .onQueue(.main))

    guard let item = itemAt(indexPath: indexPath) else {
      return nil
    }

    switch item {
    case .entry(let entry):
      return entry
    case .summary, .message:
      return nil
    }
  }

  /// Returns the first index path matching `entry`.
  func indexPath(matching entry: Entry) -> IndexPath? {
    dispatchPrecondition(condition: .onQueue(.main))
    
    for (s, section) in sections.enumerated() {
      for (r, item) in section.items.enumerated() {
        switch item {
        case .entry(let e):
          if e == entry {
            return IndexPath(row: r, section: s)
          }
        case .summary, .message:
          return nil
        }
      }
    }

    return nil
  }

}
