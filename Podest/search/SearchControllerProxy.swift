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

private enum SearchState: Equatable {
  case dismissed
  case searching(String)
  case suggesting(String)
}

private enum SearchEvent: Equatable {
  case suggest(String)
  case search(String)
  case dismiss
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

  /// `true` if the search controller is not active. The default state.
  var isSearchDismissed: Bool {
    return state == .dismissed
  }

  func deselect(_ animated: Bool) {
    searchResultsController.deselect(animated)
  }

  private var searchBar: UISearchBar {
    return searchController.searchBar
  }

  private func event(_ e: SearchEvent) {
    let src = searchResultsController

    switch state {
    case .dismissed:
      switch e {
      case .dismiss:
        return

      case .search(let term):
        src.search(term)

        state = .searching(term)

      case .suggest(let term):
        src.suggest(term)

        state = .suggesting(term)
      }
      
    case .suggesting(let oldTerm):
      switch e {
      case .dismiss:
        src.reset()

        state = .dismissed

      case .search(let term):
        src.search(term)

        state = .searching(term)

        if searchBar.text != term {
          os_log("resetting text", log: log, type: .debug)
          searchBar.text = term
        }

        if searchBar.isFirstResponder {
          os_log("resigning first responder", log: log, type: .debug)
          searchBar.resignFirstResponder()
        }

      case .suggest(let term):
        guard oldTerm != term else {
          os_log("aborting: same term", log: log, type: .debug)
          return
        }

        src.suggest(term)

        state = .suggesting(term)

        if searchBar.text != term {
          os_log("resetting text", log: log, type: .debug)
          searchBar.text = term
        }
      }

    case .searching(let oldTerm):
      switch e {
      case .dismiss:
        src.reset()

        state = .dismissed

      case .search(let term):
        guard oldTerm != term else {
          os_log("aborting: same term", log: log, type: .debug)
          return
        }
        
        src.search(term)

        state = .searching(term)

      case .suggest(let term):
        src.suggest(term)

        state = .suggesting(term)
      }
    }
  }

  func suggest(_ term: String) {
    event(.suggest(term))
  }

  func search(_ term: String) {
    event(.search(term))
  }

  func dismiss() {
    event(.dismiss)
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
    switch state {
    case .dismissed:
      return
    case .searching(let term), .suggesting(let term):
      let newTerm = sc.searchBar.text ?? ""

      guard term != newTerm else {
        return
      }

      suggest(newTerm)
    }
  }

}

// MARK: - UISearchControllerDelegate

extension SearchControllerProxy: UISearchControllerDelegate {

  func willPresentSearchController(_ searchController: UISearchController) {
    Podest.store.cancelReview()
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

  func searchResults(
    _ searchResults: SearchResultsController,
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

  func searchResultsWillBeginDragging(
    _ searchResults: SearchResultsController) {
    os_log("resigning first responder", log: log, type: .debug)
    searchBar.resignFirstResponder()
  }

}
