//
//  SearchResultsDataSource.swift
//  Podest
//
//  Created by Michael Nisi on 02.02.15.
//  Copyright (c) 2015 Michael Nisi. All rights reserved.
//

import Foundation
import FeedKit
import BatchUpdates

/// A table view data source for searching.
///
/// This data source executes a single operation at a time. Overlapping
/// operations cancel the preceding. Completion blocks of cancelled
/// operations are executed, but receive unchanged sections and empty updates.
final class SearchResultsDataSource: NSObject, SectionedDataSource {

  /// Enumerates items presented by this data source.
  enum Item: Hashable {
    case find(Find)
    case message(NSAttributedString)
  }

  private let repo: Searching

  /// Creates a new search results data source.
  ///
  /// - Parameter repo: The API to use for searching.
  init(repo: Searching) {
    self.repo = repo

    super.init()
  }

  /// The singly search or suggest operation.
  weak var operation: Operation? {
    willSet {
      operation?.cancel()
    }
  }

  /// The current sections.
  var sections = [Array<Item>]()

  /// In-flight image requests.
  private var requests: [ImageRequest]?

  /// The previous trait collection.
  var previousTraitCollection: UITraitCollection?
  
}

// MARK: - Diffing Sections

extension SearchResultsDataSource {

  /// Returns new sections representing `term`, `items`, and `error`.
  ///
  /// - Returns: The new sections or `nil` if current sections should be kept.
  private static func makeSections(
    term: String,
    items: [Find],
    error: Error? = nil
  ) -> [Array<Item>]? {
    guard error == nil else {
      if let text = StringRepository.message(describing: error!) {
        return [[.message(text)]]
      }

      return nil
    }

    guard !items.isEmpty else {
      if !term.isEmpty {
        let text = StringRepository.noResult(for: term)
        return [[.message(text)]]
      }

      return []
    }

    var results = [Item]()
    var sugs = [Item]()
    var feeds = [Item]()
    var entries = [Item]()

    for item in items {
      switch item {
      case .recentSearch:
        results.append(.find(item))
      case .suggestedTerm:
        sugs.append(.find(item))
      case .suggestedFeed, .foundFeed:
        feeds.append(.find(item))
      case .suggestedEntry:
        entries.append(.find(item))
      }
    }

    return [results, sugs, feeds, entries].filter { !$0.isEmpty }
  }

  /// Drafts updates from `items` and `error` with `sections` as current state.
  private static func makeUpdates(
    term: String,
    sections current: [Array<Item>],
    items: [Find],
    error: Error? = nil
  ) -> [[Change<Item>]] {
    guard let sections = makeSections(
      term: term, items: items, error: error) else {
      return []
    }

    let changes = makeChanges(old: current, new: sections)

    return changes
  }

}

// MARK: - Suggesting and Searching

extension SearchResultsDataSource {

  /// Return a trimmed search query `term`.
  private static func makeTrimmed(term: String) -> String {
    let ignored = CharacterSet(charactersIn: " ")

    return term.trimmingCharacters(in: ignored)
  }

  /// Updates the sections with suggestions for `term`.
  ///
  /// - Parameters:
  ///   - term: The search term.
  ///   - reloadBlock: This block executes on the main queue when it’s time for
  /// the table view to reload data.
  func suggest(term: String, reloadBlock: (() -> Void)?) {
    dispatchPrecondition(condition: .onQueue(.main))

    let trimmed = SearchResultsDataSource.makeTrimmed(term: term)

    guard !trimmed.isEmpty else {
      operation = nil
      sections = []

      reloadBlock?()
      return
    }

    let checkpoint = sections

    var acc = [Find]()

    operation = repo.suggest(trimmed, perFindGroupBlock: { error, finds in
      guard error == nil else {
        fatalError(String(describing: error))
      }

      acc += finds
    }) { error in
      dispatchPrecondition(condition: .notOnQueue(.main))

      let sections = SearchResultsDataSource.makeSections(
        term: term, items: acc, error: error)

      DispatchQueue.main.async { [weak self] in
        guard self?.sections == checkpoint, let s = sections else {
          return
        }

        self?.sections = s

        reloadBlock?()
      }
    }
  }

  /// Updates the sections with search results for `term`.
  ///
  /// - Parameters:
  ///   - term: The search term.
  ///   - reloadBlock: This block executes on the main queue when the table
  /// view should reload data.
  func search(term: String, reloadBlock: (() -> Void)?) {
    dispatchPrecondition(condition: .onQueue(.main))

    let checkpoint = sections

    var acc = [Find]()

    operation = repo.search(term, perFindGroupBlock: { error, finds in
      guard error == nil else {
        fatalError(String(describing: error))
      }

      acc += finds
    }) { error in
      dispatchPrecondition(condition: .notOnQueue(.main))

      let sections = SearchResultsDataSource.makeSections(
        term: term, items: acc, error: error)

      DispatchQueue.main.async { [weak self] in
        guard self?.sections == checkpoint, let s = sections else {
          return
        }

        self?.sections = s

        reloadBlock?()
      }
    }
  }

}

// MARK: - Suggesting and Searching (Diffing)

extension SearchResultsDataSource {

  func suggest(
    term: String,
    updatesBlock: (([[Change<Item>]], Error?) -> Void)?
  ) {
    dispatchPrecondition(condition: .onQueue(.main))

    let trimmed = SearchResultsDataSource.makeTrimmed(term: term)

    guard !trimmed.isEmpty else {
      operation = nil

      let changes = SearchResultsDataSource.makeUpdates(
        term: trimmed, sections: self.sections, items: [])

      updatesBlock?(changes, nil)
      return
    }

    // Capturing current sections on the main queue.
    let current = sections

    var acc = [Find]()

    operation = repo.suggest(trimmed, perFindGroupBlock: { error, finds in
      guard error == nil else {
        fatalError(String(describing: error))
      }

      acc += finds
    }) { error in
      dispatchPrecondition(condition: .notOnQueue(.main))

      let changes = SearchResultsDataSource.makeUpdates(
        term: trimmed, sections: current, items: acc, error: error)

      guard !changes.isEmpty else {
        return
      }

      DispatchQueue.main.async { [weak self] in
        // Making sure our operation is relevant still.
        guard self?.sections == current else {
          return
        }

        updatesBlock?(changes, error)
      }
    }
  }

  func search(
    term: String,
    updatesBlock: (([[Change<Item>]], Error?) -> Void)? = nil
  ) {
    dispatchPrecondition(condition: .onQueue(.main))

    // Capturing current sections on the main queue.
    let current = sections

    var acc = [Find]()

    operation = repo.search(term, perFindGroupBlock: { error, finds in
      guard error == nil else {
        fatalError(String(describing: error))
      }

      acc += finds
    }) { error in
      dispatchPrecondition(condition: .notOnQueue(.main))

      let changes = SearchResultsDataSource.makeUpdates(
        term: term, sections: current, items: acc, error: error)

      guard !changes.isEmpty else {
        return
      }

      DispatchQueue.main.async { [weak self] in
        guard self?.sections == current else {
          return
        }

        updatesBlock?(changes, error)
      }
    }
  }

}

// MARK: - Accessing Items

extension SearchResultsDataSource {

  func findAt(indexPath: IndexPath) -> Find? {
    guard let item = itemAt(indexPath: indexPath) else {
      return nil
    }

    switch item {
    case .find(let find):
      return find
    case .message:
      return nil
    }
  }

}

// MARK: - Configuring a Table View

extension SearchResultsDataSource: UITableViewDataSource {

  /// Registers nib objects with `tableView` under identifiers.
  static func registerCells(with tableView: UITableView) {
    let cells = [
      (UITableView.Nib.message.nib, UITableView.Nib.message.id),
      (UITableView.Nib.subtitle.nib, UITableView.Nib.subtitle.id),
      (UITableView.Nib.suggestion.nib, UITableView.Nib.suggestion.id)
    ]

    for cell in cells {
      tableView.register(cell.0, forCellReuseIdentifier: cell.1)
    }
  }
  
  func numberOfSections(in tableView: UITableView) -> Int {
    return sections.count
  }
  
  func tableView(
    _ tableView: UITableView,
    numberOfRowsInSection section: Int) -> Int {
    return sections[section].count
  }
  
  func tableView(
    _ tableView: UITableView,
    titleForHeaderInSection section: Int
  ) -> String? {
    guard sections.count > 1, let first = sections[section].first else {
      return nil
    }

    switch first {
    case .find(let find):
      switch find {
      case .foundFeed, .suggestedFeed:
        return "Podcasts"
      case .recentSearch:
        return "Top Hits"
      case .suggestedEntry:
        return "Episodes"
      case .suggestedTerm:
        return "iTunes Search"
      }
    case .message:
      return nil
    }
  }
  
  func tableView(
    _ tableView: UITableView,
    cellForRowAt indexPath: IndexPath
  ) -> UITableViewCell {
    guard let item = itemAt(indexPath: indexPath) else {
      fatalError("no item at index path: \(indexPath)")
    }
    switch item {
    case .find(let find):
      switch find {
      case .suggestedTerm(let sug):
        let cell = tableView.dequeueReusableCell(
          withIdentifier: UITableView.Nib.suggestion.id, for: indexPath)

        cell.textLabel?.text = sug.term

        return cell
      case .recentSearch(let feed), .suggestedFeed(let feed):
        let cell = tableView.dequeueReusableCell(
          withIdentifier: UITableView.Nib.subtitle.id, for: indexPath
        ) as! SubtitleTableViewCell

        cell.accessoryType = .none

        if let imageView = cell.imageView { 
          Podest.images.cancel(displaying: imageView)
        }
        
        cell.imageView?.image = nil
        cell.layoutSubviewsBlock = nil

        cell.textLabel?.font = UIFont.preferredFont(forTextStyle: .body)
        cell.textLabel?.numberOfLines = 0
        cell.textLabel?.text = feed.title

        cell.detailTextLabel?.font = UIFont.preferredFont(forTextStyle: .footnote)
        cell.detailTextLabel?.numberOfLines = 0
        cell.detailTextLabel?.textColor = .darkText
        cell.detailTextLabel?.text = feed.author

        return cell
      case .suggestedEntry(let entry):
        let cell = tableView.dequeueReusableCell(
          withIdentifier: UITableView.Nib.subtitle.id, for: indexPath
        ) as! SubtitleTableViewCell

        cell.accessoryType = .none
        
        if let imageView = cell.imageView { 
          Podest.images.cancel(displaying: imageView)
        }
        
        cell.imageView?.image = nil
        cell.layoutSubviewsBlock = nil

        cell.textLabel?.font = UIFont.preferredFont(forTextStyle: .body)
        cell.textLabel?.numberOfLines = 0
        cell.textLabel?.text = entry.title

        cell.detailTextLabel?.font = UIFont.preferredFont(forTextStyle: .footnote)
        cell.detailTextLabel?.numberOfLines = 0
        cell.detailTextLabel?.textColor = .darkText
        cell.detailTextLabel?.text = entry.feedTitle

        return cell
      case .foundFeed(let feed):
        let cell = tableView.dequeueReusableCell(
          withIdentifier: UITableView.Nib.subtitle.id, for: indexPath
        ) as! SubtitleTableViewCell

        cell.accessoryType = .disclosureIndicator
        
        if let imageView = cell.imageView { 
          Podest.images.cancel(displaying: imageView)
        }
        cell.imageView?.image = UIImage(named: "Oval")
        cell.layoutSubviewsBlock = { imageView in
          Podest.images.loadImage(
            representing: feed,
            into: imageView,
            options: FKImageLoadingOptions(
              fallbackImage: UIImage(named: "Oval"),
              quality: .medium,
              isDirect: true
            )
          )
        }

        cell.textLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
        cell.textLabel?.numberOfLines = 0

        cell.detailTextLabel?.font = UIFont.preferredFont(forTextStyle: .body)
        cell.detailTextLabel?.numberOfLines = 0
        cell.detailTextLabel?.textColor = UIColor(named: "Asphalt")

        cell.textLabel?.text = feed.title
        cell.detailTextLabel?.text = StringRepository.feedCellSubtitle(for: feed)

        return cell
      }
    case .message(let text):
      let cell = tableView.dequeueReusableCell(
        withIdentifier: UITableView.Nib.message.id, for: indexPath
      ) as! MessageTableViewCell

      cell.titleLabel.attributedText = text
      cell.selectionStyle = .none
      cell.targetHeight = tableView.bounds.height * 0.6
      cell.backgroundColor = .white

      tableView.separatorStyle = .none

      return cell
    }
  }
  
}

// MARK: - Managing Data Prefetching

extension SearchResultsDataSource: UITableViewDataSourcePrefetching  {
  
  private func imaginables(for indexPaths: [IndexPath]) -> [Imaginable] {
    return indexPaths.compactMap { indexPath in
      guard let item = itemAt(indexPath: indexPath) else {
        return nil
      }
      
      switch item {
      case .find(let find):
        switch find {
        case .foundFeed(let feed):
          return feed
        case .recentSearch, .suggestedEntry, .suggestedFeed:
          return nil
        case .suggestedTerm:
          return nil
        }
      case .message:
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

    Podest.images.prefetchImages(for: items, at: size, quality: .medium)
  }

  func tableView(
    _ tableView: UITableView,
    cancelPrefetchingForRowsAt indexPaths: [IndexPath]
  ) {
    let items = imaginables(for: indexPaths)
    let size = estimateCellSize(tableView: tableView)

    Podest.images.cancelPrefetching(items, at: size, quality: .medium)
  }
  
}
