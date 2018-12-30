//
//  SearchResultsDataSource.swift
//  Podest
//
//  Created by Michael Nisi on 02.02.15.
//  Copyright (c) 2015 Michael Nisi. All rights reserved.
//

import Foundation
import FeedKit

// MARK: API

protocol SearchResults: UITableViewDataSource, UITableViewDataSourcePrefetching {
  func updatesForItems(items: [Find]) -> Updates
  func itemAt(indexPath: IndexPath) -> Find?
}

// MARK: - Internals

/// Enumerate search result section identifiers.
enum SearchSectionID: Int {
  case search, recent, feed, entry
}

/// A table view data source providing search result items.
final class SearchResultsDataSource: NSObject, SearchResults, SectionedDataSource {

  typealias Item = Find
  
  var sections = [Section<Find>]()

  func sectionsFor(items: [Find]) -> [Section<Find>] {
    var results = Section<Find>(
      id: SearchSectionID.recent.rawValue, title: "Top Hits")
    var sugs = Section<Find>(
      id: SearchSectionID.search.rawValue, title: "iTunes Search")
    var feeds = Section<Find>(
      id: SearchSectionID.feed.rawValue, title: "Podcasts")
    var entries = Section<Find>(
      id: SearchSectionID.entry.rawValue, title: "Episodes")
    
    for item in items {
      switch item {
      case .recentSearch:
        results.append(item: item)
      case .suggestedTerm:
        sugs.append(item: item)
      case .suggestedFeed, .foundFeed:
        feeds.append(item: item)
      case .suggestedEntry:
        entries.append(item: item)
      }
    }
    
    return [results, sugs, feeds, entries].filter {
      !$0.items.isEmpty
    }
  }
  
  /// Return required table view updates for specified items.
  ///
  /// - Parameter items: The found items to use.
  ///
  /// - Returns: Required table view updates for the items.
  func updatesForItems(items: [Find]) -> Updates {
    let sections = sectionsFor(items: items)
    let updates = SearchResultsDataSource.makeUpdates(old: self.sections, new: sections)
    
    self.sections = sections
    
    return updates
  }

  // MARK: UITableViewDataSourcePrefetching
  
  fileprivate var requests: [ImageRequest]?
  
}

// MARK: - UITableViewDataSource

extension SearchResultsDataSource: UITableViewDataSource {

  /// Registers nib objects with `tableView` under identifiers.
  static func registerCells(with tableView: UITableView) {
    let cells = [
      (Cells.message.nib, Cells.message.id),
      (Cells.subtitle.nib, Cells.subtitle.id),
      (Cells.suggestion.nib, Cells.suggestion.id)
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
    case .suggestedTerm(let sug):
      let cell = tableView.dequeueReusableCell(
        withIdentifier: Cells.suggestion.id, for: indexPath)
      cell.textLabel?.text = sug.term

      return cell
    case .recentSearch(let feed), .suggestedFeed(let feed):
      let cell = tableView.dequeueReusableCell(
        withIdentifier: Cells.subtitle.id, for: indexPath
      ) as! SubtitleTableViewCell

      cell.item = nil
      cell.textLabel?.text = feed.title
      cell.detailTextLabel?.text = feed.author
      cell.imageView?.image = nil

      return cell
    case .suggestedEntry(let entry):
      let cell = tableView.dequeueReusableCell(
        withIdentifier: Cells.subtitle.id, for: indexPath
      ) as! SubtitleTableViewCell

      cell.item = nil
      cell.textLabel?.text = entry.title
      cell.detailTextLabel?.text = entry.feedTitle
      cell.imageView?.image = nil

      return cell
    case .foundFeed(let feed):
      let cell = tableView.dequeueReusableCell(
        withIdentifier: Cells.subtitle.id, for: indexPath
      ) as! SubtitleTableViewCell

      cell.item = feed
      cell.textLabel?.text = feed.title
      cell.detailTextLabel?.text = StringRepository.feedCellSubtitle(for: feed)
      cell.imageView?.image = UIImage(named: "Oval")

      return cell
    }
  }
  
}

// MARK: - UITableViewDataSourcePrefetching

extension SearchResultsDataSource: UITableViewDataSourcePrefetching  {
  
  private func imaginables(for indexPaths: [IndexPath]) -> [Imaginable] {
    return indexPaths.compactMap { indexPath in
      guard let item = itemAt(indexPath: indexPath) else {
        return nil
      }
      switch item {
      case .foundFeed(let feed):
        return feed
      default:
        return nil
      }
    }
  }
  
  func tableView(_ tableView: UITableView,
                 prefetchRowsAt indexPaths: [IndexPath]) {
    let items = imaginables(for: indexPaths)
    let size = CGSize(width: 60, height: 60)

    requests = Podest.images.prefetchImages(
      for: items, at: size, quality: .medium
    )
  }

  func tableView(_ tableView: UITableView,
                 cancelPrefetchingForRowsAt indexPaths: [IndexPath]) {
    guard let reqs = requests else {
      return
    }
    // Ignoring indexPaths, relying on the repo to do the right thing.
    Podest.images.cancel(prefetching: reqs)
    requests = nil
  }
  
}
