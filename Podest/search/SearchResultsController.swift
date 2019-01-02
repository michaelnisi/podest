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
  
  private let dataSource = SearchResultsDataSource(repo: Podest.finder)

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

  /// Returns a shared completion block for updating.
  private func makeUpdatingBlock(
    completionBlock: ((Error?) -> Void)?
  ) -> (([Section<SearchResultsDataSource.Item>], Updates, Error?) -> Void) {
    return { [weak self] sections, updates, error in
      guard !updates.isEmpty else {
        completionBlock?(error)
        return
      }

      // There must be a smarter place for adjusting insets.
      self?.adjustInsets()

      self?.tableView.performBatchUpdates({
        // For smooth dismission, hiding the search bar, we need animations.
        UIView.setAnimationsEnabled(sections.isEmpty)

        self?.dataSource.sections = sections

        let t = self?.tableView

        t?.deleteRows(at: updates.rowsToDelete, with: .none)
        t?.insertRows(at: updates.rowsToInsert, with: .none)
        t?.reloadRows(at: updates.rowsToReload, with: .none)

        t?.deleteSections(updates.sectionsToDelete, with: .none)
        t?.insertSections(updates.sectionsToInsert, with: .none)
        t?.reloadSections(updates.sectionsToReload, with: .none)
      }) { _ in
        UIView.setAnimationsEnabled(true)
        completionBlock?(error)
      }
    }
  }

  func search(_ term: String, completionBlock: ((Error?) -> Void)? = nil) {
    dataSource.search(
      term: term,
      completionBlock: makeUpdatingBlock(completionBlock: completionBlock)
    )
  }

  func suggest(_ term: String, completionBlock: ((Error?) -> Void)? = nil) {
    dataSource.suggest(
      term: term,
      completionBlock: makeUpdatingBlock(completionBlock: completionBlock)
    )
  }
  
  func reset(completionBlock: ((Error?) -> Void)? = nil) {
    dataSource.suggest(
      term: "",
      completionBlock: makeUpdatingBlock(completionBlock: completionBlock)
    )
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
    guard let find = dataSource.findAt(indexPath: indexPath) else {
      fatalError("no item at index path: \(indexPath)")
    }

    delegate?.searchResultsController(self, didSelectFind: find)
  }

}
