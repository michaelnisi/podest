//
//  SearchResultsDataSource.swift
//  Podest
//
//  Created by Michael Nisi on 02.02.15.
//  Copyright (c) 2015 Michael Nisi. All rights reserved.
//

import Foundation
import FeedKit

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
  
  var sections = [Section<Item>]()

  private var requests: [ImageRequest]?

  private let repo: Searching

  /// Creates a new search results data source.
  ///
  /// - Parameters:
  ///   - repo: The API to use for searching.
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
  
}

// MARK: - Diffing Sections

extension SearchResultsDataSource {

  private static func makeSections(
    term: String,
    items: [Find],
    error: Error? = nil
  ) -> [Section<Item>]? {
    guard error == nil else {
      if let text = StringRepository.message(describing: error!) {
        return [Section(id: 0, items: [.message(text)])]
      }

      return nil
    }

    guard !items.isEmpty else {
      if !term.isEmpty {
        let text = StringRepository.noResult(for: term)
        return [Section(id: 0, items: [.message(text)])]
      }

      return []
    }

    if items.count == 1,
      case .suggestedTerm(let suggestion)? = items.first,
      suggestion.term == term {
      let text = StringRepository.noResult(for: term)
      return [Section(id: 0, items: [.message(text)])]
    }

    var results = Section<Item>(id: 1, title: "Top Hits")
    var sugs = Section<Item>(id: 2, title: "iTunes Search")
    var feeds = Section<Item>(id: 3, title: "Podcasts")
    var entries = Section<Item>(id: 4, title: "Episodes")

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
    sections current: [Section<Item>],
    items: [Find],
    error: Error? = nil
  ) -> ([Section<Item>], Updates)? {
    guard let sections = makeSections(term: term, items: items, error: error) else {
      return nil
    }

    let updates = makeUpdates(old: current, new: sections)

    return (sections, updates)
  }

}

// MARK: - Suggesting and Searching

extension SearchResultsDataSource {

  func suggest(
    term: String,
    updatesBlock: (([Section<Item>], Updates, Error?) -> Void)?
  ) {
    dispatchPrecondition(condition: .onQueue(.main))

    let ignored = CharacterSet(charactersIn: " ")
    let trimmed = term.trimmingCharacters(in: ignored)

    guard !trimmed.isEmpty else {
      operation = nil
      
      guard let (sections, updates) = SearchResultsDataSource.makeUpdates(
        term: trimmed,
        sections: self.sections,
        items: []
      ) else {
        return
      }

      updatesBlock?(sections, updates, nil)
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

      guard let (sections, updates) = SearchResultsDataSource.makeUpdates(
        term: trimmed,
        sections: current,
        items: acc,
        error: error
      ) else {
        return
      }

      DispatchQueue.main.async { [weak self] in
        guard self?.sections == current else {
          return
        }
        updatesBlock?(sections, updates, error)
      }
    }
  }

  func search(
    term: String,
    updatesBlock: (([Section<Item>], Updates, Error?) -> Void)?
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

      guard let (sections, updates) = SearchResultsDataSource.makeUpdates(
        term: term,
        sections: current,
        items: acc,
        error: error
      ) else {
        return
      }

      DispatchQueue.main.async { [weak self] in
        guard self?.sections == current else {
          return
        }
        updatesBlock?(sections, updates, error)
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
    return sections.count > 1 ? sections[section].title : nil
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

        cell.item = nil
        cell.textLabel?.text = feed.title
        cell.detailTextLabel?.text = feed.author
        cell.imageView?.image = nil

        return cell
      case .suggestedEntry(let entry):
        let cell = tableView.dequeueReusableCell(
          withIdentifier: UITableView.Nib.subtitle.id, for: indexPath
        ) as! SubtitleTableViewCell

        cell.item = nil
        cell.textLabel?.text = entry.title
        cell.detailTextLabel?.text = entry.feedTitle
        cell.imageView?.image = nil

        return cell
      case .foundFeed(let feed):
        let cell = tableView.dequeueReusableCell(
          withIdentifier: UITableView.Nib.subtitle.id, for: indexPath
        ) as! SubtitleTableViewCell

        cell.images = Podest.images
        cell.item = feed
        cell.textLabel?.text = feed.title
        cell.detailTextLabel?.text = StringRepository.feedCellSubtitle(for: feed)
        cell.imageView?.image = UIImage(named: "Oval")

        return cell
      }
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
  
  func tableView(
    _ tableView: UITableView,
    prefetchRowsAt indexPaths: [IndexPath]
  ) {
    let items = imaginables(for: indexPaths)
    let size = CGSize(width: 60, height: 60)

    requests = Podest.images.prefetchImages(
      for: items, at: size, quality: .medium
    )
  }

  func tableView(
    _ tableView: UITableView,
    cancelPrefetchingForRowsAt indexPaths: [IndexPath]
  ) {
    guard let reqs = requests else {
      return
    }

    // Ignoring indexPaths, relying on the repo to do the right thing.
    Podest.images.cancel(prefetching: reqs)

    requests = nil
  }
  
}
