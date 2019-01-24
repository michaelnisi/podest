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

  var delegate: SearchResultsControllerDelegate?

  /// Returns a shared completion block for updating.
  private func makeUpdatingBlock()
    -> (([[Change<SearchResultsDataSource.Item>]], Error?) -> Void) {
    return { [weak self] batch, error in
      // There must be a smarter place for adjusting insets.
      self?.adjustInsets()

      guard let tv = self?.tableView else {
        return
      }

      UIView.performWithoutAnimation {
        self?.dataSource.commit(batch, performingWith: .table(tv))
      }
    }
  }

  func search(_ term: String) {
    dataSource.search(term: term, updatesBlock: makeUpdatingBlock())
  }

  func suggest(_ term: String) {
    dataSource.suggest(term: term, updatesBlock: makeUpdatingBlock())
  }
  
  func reset() {
    dataSource.suggest(term: "", updatesBlock: makeUpdatingBlock())
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
    tableView.backgroundColor = .groupTableViewBackground

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
    dataSource.previousTraitCollection = previousTraitCollection

    // Waiting for the searchbar to be resized by SearchController.

    DispatchQueue.main.async {
      self.adjustInsets()
    }
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

    delegate?.searchResultsController(self, didSelectFind: find)
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
