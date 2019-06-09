//
//  ListOperation.swift
//  Podest
//
//  Created by Michael Nisi on 21.04.19.
//  Copyright © 2019 Michael Nisi. All rights reserved.
//

import Foundation
import FeedKit
import os.log
import BatchUpdates

private let log = OSLog(subsystem: "ink.codes.podest", category: "list")

/// Loads podcast feed at `url` and its entries.
class ListOperation: Operation, Receiving {
  
  let url: String
  let originalFeed: Feed?
  let forcing: Bool
  let isCompact: Bool
  
  /// Creates a new list operation fetching feed and entries.
  ///
  /// - Parameters:
  ///   - url: The URL of the podcast feed.
  ///   - originalFeed: The original feed object if available.
  ///   - forcing: Overrides cache settings, forcing reloading (to some degree).
  ///   - isCompact: Characterizes the user interface.
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
    
    os_log("initializing: ( %@, %@, %i, %i )", log: log, type: .debug,
           url, String(describing: originalFeed), forcing, isCompact)
    
    super.init()
  }
  
  /// Creates a new list operation using the properties of another `operation`.
  init(operation: ListOperation) {
    self.url = operation.url
    self.originalFeed = operation.originalFeed
    self.forcing = operation.forcing
    self.isCompact = operation.isCompact
    
    super.init()
  }
  
  override var description: String {
    return """
    ListOperation: (\(url), \(originalFeed?.title ?? "none"), \
    \(forcing), \(isCompact))
    """
  }
  
  override func cancel() {
    super.cancel()
    
    for dep in dependencies {
      dep.cancel()
    }
  }
  
  typealias Item = ListDataSource.Item
  
  /// This block receives new sections, changes, and an error.
  var updatesBlock: (([Array<Item>], [[Change<Item>]], Error?) -> Void)?
  
  /// This block receives the feed and an error.
  var feedBlock: ((Feed?, Error?) -> Void)?
  
  /// Accumulates previous `sections`, fresh `items`, and possibly an `error`
  /// into the next sections.
  ///
  /// Making the next sections structure is the main task of the data source.
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
    
    let changes = ListDataSource.makeChanges(old: current, new: sections)
    
    return (sections, changes)
  }
  
}

final class FetchFeedOperation: ListOperation, Providing {
  
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

final class FetchEntriesOperation: ListOperation {
  
  var locators: [EntryLocator]
  
  override init(operation: ListOperation) {
    self.locators = [EntryLocator(url: operation.url)]
    
    super.init(operation: operation)
  }
  
  func findCurrent() -> [Array<Item>]? {
    guard let p = dependencies.first(where: { $0 is FetchFeedOperation })
      as? FetchFeedOperation else {
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
