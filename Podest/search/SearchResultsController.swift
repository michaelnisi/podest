//
//  SearchResultsController.swift
//  Podest
//
//  Created by Michael Nisi on 05.12.14.
//  Copyright (c) 2014 Michael Nisi. All rights reserved.
//

import FeedKit
import Foundation
import UIKit
import os.log

private let log = OSLog.disabled

protocol SearchResultsControllerDelegate: Navigator {

  /// Communicating back selections from the list of search results.
  func searchResultsController(
    _ searchResultsController: SearchResultsController,
    didSelectFind: Find
  )

  /// The main split view controller state.
  ///
  /// In landscape, episodes can be selected, flipping to portrait must clear
  /// these selections in place, for `viewDidAppear(_:)` not happening in that
  /// case.
  var isCollapsed: Bool { get }

}

final class SearchResultsController: UITableViewController {
  
  private let dataSource: SearchResults = SearchResultsDataSource()

  func deselect(_ animated: Bool) {
    guard let indexPath = tableView.indexPathForSelectedRow else {
      return
    }

    tableView.deselectRow(at: indexPath, animated: animated)
  }
  
  /// Scrolls the selected row into view.
  func scrollToSelectedRow(animated: Bool) {
    guard let indexPath = tableView.indexPathForSelectedRow,
      !(tableView.indexPathsForVisibleRows?.contains(indexPath))! else {
      return
    }

    tableView.scrollToRow(at: indexPath, at: .none, animated: animated)
  }

  /// Scrolls to the first row.
  private func scrollToFirstRow(animated: Bool) {
    let path = IndexPath(row: 0, section: 0)

    guard dataSource.itemAt(indexPath: path) != nil else {
      return
    }

    tableView.scrollToRow(at: path, at: .none, animated: animated)
  }

  var delegate: SearchResultsControllerDelegate?

  func update(_ items: [Find], separatorInset: UIEdgeInsets? = nil) {
    assert(items.count ==  Set(items).count)

    adjustInsets()
    
    /// Disabling animations is not safe during cancellation, for its
    /// interference with UISearchController’s deactictivation animation,
    /// preventing it from removing the 'Cancel' button from the search bar.

    guard !items.isEmpty else {
      let _ = dataSource.updatesForItems(items: items)
      return tableView.reloadData()
    }
    
    let t = self.tableView!
    
    t.performBatchUpdates({
      // Should be quick, under one millisecond.
      let updates: Updates = dataSource.updatesForItems(items: items)
      
      UIView.setAnimationsEnabled(false)
      
      t.deleteRows(at: updates.rowsToDelete, with: .none)
      t.insertRows(at: updates.rowsToInsert, with: .none)
      t.reloadRows(at: updates.rowsToReload, with: .none)
      
      t.deleteSections(updates.sectionsToDelete, with: .none)
      t.insertSections(updates.sectionsToInsert, with: .none)
      t.reloadSections(updates.sectionsToReload, with: .none)
    }) { [weak self] ok in
      assert(ok)

      UIView.setAnimationsEnabled(true)
      
      self?.scrollToFirstRow(animated: false)
    }
  }

  weak var operation: Operation? {
    willSet {
      operation?.cancel()
    }
  }

  /// Get ready!
  fileprivate func ready() {
    operation = nil
    hideMessage()
  }
  
  func reset() {
    assert(Thread.isMainThread)
    update([])
    ready()
  }

  // Our search repository/container, handling operations for us.
  lazy fileprivate var repo = Podest.finder
  
  func suggest(_ term: String) {
    let ignored = CharacterSet(charactersIn: " ")
    let trimmed = term.trimmingCharacters(in: ignored)
    
    guard !trimmed.isEmpty else {
      return reset()
    }

    ready()

    var items = [Find]()

    operation = repo.suggest(term, perFindGroupBlock: { error, finds in
      guard error == nil else {
        fatalError(String(describing: error))
      }
      
      DispatchQueue.main.async {
        items += finds
      }
    }) { [weak self] error in
      guard error == nil else {
        return DispatchQueue.main.async {
          // Aborting default error handling if we have gotten items.
          guard items.isEmpty else {
            self?.update(items)
            return
          }
          if let message = StringRepository.message(describing: error!) {
            self?.clear(showing: message)
          }
        }
      }

      DispatchQueue.main.async { [weak self] in
        guard !items.isEmpty else {
          return
        }
        self?.update(items)
      }
    }
  }
  
  fileprivate func clear(showing message: NSAttributedString) {
    showMessage(message)
    update([])
  }

  /// Optionally, an alternative table view separator inset applied while
  /// listing search results.
  var searchSeparatorInset: UIEdgeInsets?
  
  func search(_ term: String) {
    ready()

    var items = [Find]()

    operation = repo.search(term, perFindGroupBlock: { error, finds in
      guard error == nil else {
        fatalError(String(describing: error))
      }
      DispatchQueue.main.async {
        items += finds
      }
    }) { [weak self] error in
      guard error == nil else {
        return DispatchQueue.main.async {
          // Aborting default error handling if we have gotten items.
          guard items.isEmpty else {
            self?.update(items)
            return
          }
          if let message = StringRepository.message(describing: error!) {
            self?.clear(showing: message)
          }
        }
      }

      DispatchQueue.main.async {
        guard !items.isEmpty else {
          let message = StringRepository.noResult(for: term)
          self?.clear(showing: message)
          return
        }

        self?.update(items, separatorInset: self?.searchSeparatorInset)
      }
    }
  }

}

// MARK: - UIViewController

extension SearchResultsController {

  override func viewDidLoad() {
    super.viewDidLoad()

    tableView.dataSource = dataSource
    tableView.prefetchDataSource = dataSource
    tableView.keyboardDismissMode = .onDrag
    tableView.contentInsetAdjustmentBehavior = .never

    SearchResultsDataSource.registerCells(with: tableView)

    tableView.rowHeight = UITableView.automaticDimension
    tableView.estimatedRowHeight = 64

    var separatorInset = tableView.separatorInset
    separatorInset.left = UITableView.automaticDimension
    tableView.separatorInset = separatorInset

    clearsSelectionOnViewWillAppear = true
  }

  /// Integrates the mini-player height into the insets.
  private func adjustInsets() {
    let bottom = delegate?.navigationDelegate?.miniPlayerEdgeInsets.bottom

    tableView.contentInset = UIEdgeInsets(
      top: tableView.safeAreaInsets.top,
      left: tableView.contentInset.left,
      bottom: bottom ?? tableView.contentInset.bottom,
      right: tableView.contentInset.right
    )

    tableView.scrollIndicatorInsets = UIEdgeInsets(
      top: tableView.safeAreaInsets.top,
      left: tableView.scrollIndicatorInsets.left,
      bottom: bottom ?? tableView.scrollIndicatorInsets.bottom,
      right: tableView.scrollIndicatorInsets.right
    )
  }

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

    clearSelection(true)

    // Waiting for the searchbar to be resized by SearchController.

    DispatchQueue.main.async {
      self.adjustInsets()
    }
  }
  
}

// MARK: - UITableViewDelegate

extension SearchResultsController {
  
  override func tableView(
    _ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    guard let find = dataSource.itemAt(indexPath: indexPath) else {
      fatalError("no item at index path: \(indexPath)")
    }

    delegate?.searchResultsController(self, didSelectFind: find)
  }

}
