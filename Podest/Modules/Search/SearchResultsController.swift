//===----------------------------------------------------------------------===//
//
// This source file is part of the Podest open source project
//
// Copyright (c) 2021 Michael Nisi and collaborators
// Licensed under MIT License
//
// See https://github.com/michaelnisi/podest/blob/main/LICENSE for license information
//
//===----------------------------------------------------------------------===//

import FeedKit
import UIKit
import Podcasts

protocol SearchResultsControllerDelegate: Navigator {

  /// Forwards table view selection.
  func searchResults(
    _ searchResults: SearchResultsController,
    didSelectFind: Find
  )

  /// Forwards scroll view begin dragging event.
  func searchResultsWillBeginDragging(
    _ searchResults: SearchResultsController)

  /// The main split view controller state.
  ///
  /// In landscape, episodes can be selected, flipping to portrait must clear
  /// these selections in place.
  var isCollapsed: Bool { get }
}

final class SearchResultsController: UITableViewController {

  let dataSource = SearchResultsDataSource(
    repo: Podcasts.finder, 
    images: Podcasts.images
  )

  var delegate: SearchResultsControllerDelegate?

  /// Returns a new closure over self refreshing the table view.
  private func makeReloadBlock() -> () -> Void {
    return { [weak self] in
      self?.tableView.reloadData()

      let zero = IndexPath(row: 0, section: 0)

      guard self?.dataSource.findAt(indexPath: zero) != nil else {
        return
      }

      self?.tableView.scrollToRow(at: zero, at: .top, animated: false)
    }
  }

  func search(_ term: String) {
    dataSource.search(term: term, reloadBlock: makeReloadBlock())
  }

  func suggest(_ term: String) {
    dataSource.suggest(term: term, reloadBlock: makeReloadBlock())
  }
  
  func reset() {
    suggest("")
  }
}

// MARK: - UIViewController

extension SearchResultsController {

  override func viewDidLoad() {
    super.viewDidLoad()

    tableView.dataSource = dataSource
    tableView.prefetchDataSource = dataSource
    
    tableView.keyboardDismissMode = .onDrag
    tableView.backgroundColor = .systemGroupedBackground
    
    if #available(iOS 13.0, *) {
      // NOP
    } else {
      tableView.contentInsetAdjustmentBehavior = .never
    }
    
    SearchResultsDataSource.registerCells(with: tableView)

    tableView.rowHeight = UITableView.automaticDimension
    tableView.estimatedRowHeight = 64
    
    var separatorInset = tableView.separatorInset
    separatorInset.left = UITableView.automaticDimension
    tableView.separatorInset = separatorInset
    
    if #available(iOS 15.0, *) {
      tableView.sectionHeaderTopPadding = 0
    }

    clearsSelectionOnViewWillAppear = true
  }
}

// MARK: - UI Enviroment Changes

extension SearchResultsController {
  
  private func clearSelection(_ animated: Bool = false) {
    guard delegate?.isCollapsed ?? true,
      let ip = tableView.indexPathForSelectedRow else {
      return
    }
    
    tableView.deselectRow(at: ip, animated: true)
  }

  override func traitCollectionDidChange(
    _ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    
    dataSource.previousTraitCollection = previousTraitCollection
    
    clearSelection(true)
  }
}

// MARK: - UIScrollViewDelegate

extension SearchResultsController {

  override func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
    delegate?.searchResultsWillBeginDragging(self)
  }
}

// MARK: - UITableViewDelegate

extension SearchResultsController {

  override func tableView(
    _ tableView: UITableView,
    willSelectRowAt indexPath: IndexPath
  ) -> IndexPath? {
    if case .message? = dataSource.itemAt(indexPath: indexPath) {
      return nil
    }

    return indexPath
  }
  
  override func tableView(
    _ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    guard let find = dataSource.findAt(indexPath: indexPath) else {
      fatalError("no item at index path: \(indexPath)")
    }

    delegate?.searchResults(self, didSelectFind: find)
  }
}

// MARK: - Selecting Rows

extension SearchResultsController {

  func deselect(_ animated: Bool) {
    guard let indexPath = tableView.indexPathForSelectedRow else {
      return
    }

    tableView.deselectRow(at: indexPath, animated: animated)
  }
}

extension SearchResultsController: Unsubscribing {}


