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
import BatchUpdates

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

  /// Drafts an update of this data source adding `operation` to its queue.
  /// After fetching the feed, completing its summary, and fetching the entries,
  /// callback blocks are submitted to the main queue, from where changes should
  /// be committed.
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
  ///
  /// - Returns: The installed operation that has been added to operation queue.
  func add(_ operation: ListOperation, forcing: Bool = false) -> ListOperation {
    guard !store.isExpired() else {
      os_log("free trial expired", log: log)
      operation.cancel()
      return operation
    }

    os_log("updating: %@", log: log, type: .debug, operation)
    
    let a = FetchFeedOperation(operation: operation)

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

    let b = FetchEntriesOperation(operation: operation)

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
    typealias Nib = UITableView.Nib
    
    let cells = [
      (Nib.message.nib, Nib.message.id),
      (Nib.subtitle.nib, Nib.subtitle.id),
      (Nib.display.nib, Nib.display.id)
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
  
  static var cellBackgroundColor: UIColor {
    if #available(iOS 13.0, *) {
      return .systemGroupedBackground
    } else {
      return .white
    }
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

      cell.selectionStyle = .default
      cell.backgroundColor = ListDataSource.cellBackgroundColor

      cell.images = nil
      cell.item = entry

      cell.textLabel?.font = .preferredFont(forTextStyle: .headline)
      cell.textLabel?.numberOfLines = 0

      cell.textLabel?.text = entry.title

      cell.detailTextLabel?.font = .preferredFont(forTextStyle: .body)
      cell.detailTextLabel?.numberOfLines = 3

      cell.detailTextLabel?.attributedText = nil
      cell.detailTextLabel?.text = subtitle

      return cell

    case .author(let author):
      let cell = tableView.dequeueReusableCell(
        withIdentifier: UITableView.Nib.subtitle.id, for: indexPath
      ) as! SubtitleTableViewCell

      cell.accessoryType = .none
      cell.selectionStyle = .none
      cell.backgroundColor = ListDataSource.cellBackgroundColor

      cell.images = nil
      cell.item = nil

      cell.textLabel?.attributedText = nil
      cell.textLabel?.text = nil

      cell.detailTextLabel?.font = .preferredFont(forTextStyle: .body)
      cell.detailTextLabel?.numberOfLines = 0

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
