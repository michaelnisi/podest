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
  func searchResultsController(
    _ searchResultsController: SearchResultsController,
    didSelectFind: Find
  )
}

final class SearchResultsController: UITableViewController {
  
  private let ds: SearchResults = SearchResultsDataSource()

  func deselect(isCollapsed: Bool) {
    guard let indexPath = tableView.indexPathForSelectedRow else {
      return
    }
    if !isCollapsed, let find = ds.itemAt(indexPath: indexPath) {
      switch find {
      case .suggestedEntry(let entry):
        if delegate?.navigationDelegate?.entry == entry {
          return
        }
        break
      default:
        break
      }
    }
    tableView.deselectRow(at: indexPath, animated: true)
  }
  
  /// Scrolls the selected row into view.
  func scrollToSelectedRow(animated: Bool) {
    guard let indexPath = tableView.indexPathForSelectedRow,
      !(tableView.indexPathsForVisibleRows?.contains(indexPath))! else {
      return
    }
    tableView.scrollToRow(at: indexPath, at: .middle, animated: animated)
  }
  
  private func scrollToFirstRow(animated: Bool) {
    let path = IndexPath(row: 0, section: 0)
    guard ds.itemAt(indexPath: path) != nil else {
      return
    }
    tableView.scrollToRow(at: path, at: .top, animated: animated)
  }

  var delegate: SearchResultsControllerDelegate?

  func update(_ items: [Find], separatorInset: UIEdgeInsets? = nil) {
    assert(items.count ==  Set(items).count)
    
    tableView.separatorInset = separatorInset ?? originalSeparatorInset
    
    /// Performing batch updates with disabled animations is not safe during
    /// cancellation, it interferes with UISearchController’s deactictivation
    /// animation, preventing it from removing the 'Cancel' button from the
    /// search bar.
    guard !items.isEmpty else {
      let _ = ds.updatesForItems(items: items)
      return tableView.reloadData()
    }
    
    let t = self.tableView!
    
    t.performBatchUpdates({
      // Should be quick, under one millisecond.
      let updates: Updates = ds.updatesForItems(items: items)
      
      UIView.setAnimationsEnabled(false)
      
      t.deleteRows(at: updates.rowsToDelete, with: .none)
      t.insertRows(at: updates.rowsToInsert, with: .none)
      t.reloadRows(at: updates.rowsToReload, with: .none)
      
      t.deleteSections(updates.sectionsToDelete, with: .none)
      t.insertSections(updates.sectionsToInsert, with: .none)
      t.reloadSections(updates.sectionsToReload, with: .none)
    }) { [weak self] finished in
      if !finished {
        os_log("search: animations interrupted", log: log)
      }
      
      // Do not remove!
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
    prevTop = nil
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
  var searchSeparatorInset: UIEdgeInsets? {
    didSet {
      
    }
  }
  
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
  
  /// While the search bar is visible the top edge insets is taller. To prevent
  /// the table view from jolting upwards, when the navigation controller pushes
  /// the next view controller, without search bar, we store the previous top
  /// value from Safe Area insets. See: `tableView(didSelectRowAt indexPath)`.
  fileprivate var prevTop: CGFloat?
  
  /// The original separator inset of the table view, assuming it doesn’t
  /// change dynamically.
  private var originalSeparatorInset: UIEdgeInsets!
}

// MARK: - UIViewController

extension SearchResultsController {
  
  override func viewDidLoad() {
    super.viewDidLoad()

    tableView.dataSource = ds
    tableView.prefetchDataSource = ds
    tableView.keyboardDismissMode = .onDrag
    tableView.contentInsetAdjustmentBehavior = .never

    Cells.registerSuggestionCell(with: tableView)
    Cells.registerSearchResultCell(with: tableView)
    Cells.registerFKImageCell(with: tableView)
  }
  
  override func viewWillLayoutSubviews() {
    defer {
      super.viewWillLayoutSubviews()
    }
    
    guard let vcs = delegate?.navigationDelegate else {
      return
    }
    
    var insets = vcs.miniPlayerEdgeInsets
    
    insets.top = prevTop ?? view.safeAreaInsets.top
    
    tableView.scrollIndicatorInsets = insets
    tableView.contentInset = insets
    
    originalSeparatorInset = originalSeparatorInset ?? tableView.separatorInset
  }
  
  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    prevTop = nil
  }
  
}

// MARK: - UITableViewDelegate

extension SearchResultsController {
  
  override func tableView(
    _ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    guard let find = ds.itemAt(indexPath: indexPath) else {
      fatalError("no item at index path: \(indexPath)")
    }
    prevTop = view.safeAreaInsets.top
    delegate?.searchResultsController(self, didSelectFind: find)
  }

}
