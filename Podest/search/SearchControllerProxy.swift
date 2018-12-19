//
//  SearchControllerFSM.swift
//  Podest
//
//  Created by Michael Nisi on 17.12.18.
//  Copyright © 2018 Michael Nisi. All rights reserved.
//

import Foundation
import UIKit
import os.log
import FeedKit

private let log = OSLog(subsystem: "ink.codes.podest", category: "search")

private enum SearchState: Int {
  case dismissed, searching, suggesting
}

private enum SearchEvent {
  case suggest, search, dismiss
}

/// A finite state machine proxying between search controller and search
/// results controller.
///
/// Managing three simple search states:
///
/// - `.dismissed` The default state.
/// - `.searching` Search results are being displayed.
/// - `.suggesting` Suggestions are displayed while users are typing.
final class SearchControllerProxy: NSObject {

  private let searchController: UISearchController
  private let searchResultsController: SearchResultsController

  init(
    searchController: UISearchController,
    searchResultsController: SearchResultsController
  ) {
    self.searchController = searchController
    self.searchResultsController = searchResultsController
  }

  var navigationDelegate: ViewControllers?

  func install() {
    searchController.delegate = self
    searchController.searchResultsUpdater = self
    searchController.searchBar.delegate = self
    searchResultsController.delegate = self
  }

  func uninstall() {
    searchController.delegate = nil
    searchController.searchResultsUpdater = nil
    searchController.searchBar.delegate = nil
    searchResultsController.delegate = nil

    navigationDelegate = nil
  }

  private var state: SearchState = .dismissed {
    didSet {
      os_log("queue: new state: %{public}@, old state: %{public}@",
             log: log, type: .debug,
             String(describing: state), String(describing: oldValue)
      )
    }
  }

  /// `true` if users are currently not using search.
  var isSearchDismissed: Bool {
    return state == .dismissed
  }

  func deselect(_ animated: Bool) {
    searchResultsController.deselect(animated)
  }

  private var searchBar: UISearchBar {
    return searchController.searchBar
  }

  private func event(_ e: SearchEvent, term: String?) {
    let src = searchResultsController

    switch state {
    case .dismissed:
      switch e {
      case .dismiss:
        break
      case .search:
        src.search(term!)
        state = .searching
      case .suggest:
        guard term != nil else {
          break
        }
        if term != "" {
          src.suggest(term!)
        }
        state = .suggesting
      }
    case .suggesting:
      switch e {
      case .dismiss:
        src.reset()
        state = .dismissed
      case .search:
        if searchBar.text != term {
          searchBar.text = term
        }

        if searchBar.isFirstResponder {
          searchBar.resignFirstResponder()
        }

        src.search(term!)
        state = .searching
      case .suggest:
        guard term != nil else {
          break
        }
        if term != "" {
          src.suggest(term!)
        }
        src.suggest(term!)
        state = .suggesting
      }
    case .searching:
      switch e {
      case .dismiss:
        src.reset()
        state = .dismissed
      case .search:
        src.search(term!)
        state = .searching
      case .suggest:
        src.suggest(term!)
        state = .suggesting
      }
    }
  }

  func suggest(_ term: String) {
    event(.suggest, term: term)
  }

  func search(_ term: String) {
    event(.search, term: term)
  }

  func dismiss() {
    event(.dismiss, term: nil)
  }
  
}

// MARK: - UISearchBarDelegate

extension SearchControllerProxy: UISearchBarDelegate {

  func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
    guard let text = searchBar.text else {
      return
    }

    search(text)
  }

}

// MARK: - UISearchResultsUpdating

extension SearchControllerProxy: UISearchResultsUpdating {

  func updateSearchResults(for sc: UISearchController) {
    suggest(sc.searchBar.text ?? "")
  }

}

// MARK: - UISearchControllerDelegate

extension SearchControllerProxy: UISearchControllerDelegate {

  func willPresentSearchController(_ searchController: UISearchController) {
    suggest("")
  }

  func willDismissSearchController(_ sc: UISearchController) {
    dismiss()
  }

}

// MARK: - SearchResultsControllerDelegate

extension SearchControllerProxy: SearchResultsControllerDelegate {

  var isCollapsed: Bool {
    return navigationDelegate?.isCollapsed ?? true
  }

  private func show(feed: Feed) {
    navigationDelegate?.show(feed: feed)
  }

  private func show(entry: Entry) {
    navigationDelegate?.show(entry: entry)
  }

  func searchResultsController(
    _ searchResultsController: SearchResultsController,
    didSelectFind find: Find
  ) {
    switch find {
    case .recentSearch(let feed):
      show(feed: feed)
    case .suggestedEntry(let entry):
      show(entry: entry)
    case .suggestedFeed(let feed), .foundFeed(let feed):
      show(feed: feed)
    case .suggestedTerm(let suggestion):
      search(suggestion.term)
    }
  }

}
