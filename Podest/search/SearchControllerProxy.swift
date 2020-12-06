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

/// Integrates a search controller.
///
/// Managing three simple search states:
///
/// - `.dismissed` The default state.
/// - `.searching` Search results are being displayed.
/// - `.suggesting` Suggestions are displayed while users are typing.
final class SearchControllerProxy: NSObject {

  let targetController: UITableViewController

  /// Prepares search for `viewController`.
  init(viewController vc: UITableViewController) {
    targetController = vc
  }
  
  var navigationDelegate: ViewControllers?
  
  private var searchController: UISearchController!
  private var searchResultsController: SearchResultsController!
  
  func install() {
    let rc = SearchResultsController()
    
    let sc = UISearchController(searchResultsController: rc)
    sc.searchBar.autocorrectionType = .no
    sc.searchBar.autocapitalizationType = .none

    
    if #available(iOS 13.0, *) {
      // NOP
    } else {
      targetController.definesPresentationContext = true
    }

    targetController.navigationItem.searchController = sc
    
    self.searchController = sc
    self.searchResultsController = rc
    
    searchController?.delegate = self
    searchController?.searchResultsUpdater = self
    searchController?.searchBar.delegate = self
    searchResultsController?.delegate = self
  }

  func uninstall() {
    searchController?.delegate = nil
    searchController?.searchResultsUpdater = nil
    searchController?.searchBar.delegate = nil
    searchResultsController?.delegate = nil
    
    searchController = nil
    searchResultsController = nil

    navigationDelegate = nil
  }
  
  // MARK: - FSM
  
  private enum State: Equatable {
    case dismissed
    case searching(String)
    case suggesting(String)
  }

  private enum Event: Equatable {
    case suggest(String)
    case search(String)
    case dismiss
  }

  private var state: State = .dismissed {
    didSet {
      os_log("queue: new state: %{public}@, old state: %{public}@",
             log: log, type: .info,
             String(describing: state), String(describing: oldValue)
      )
    }
  }

  /// `true` if the search controller is not active. The default state.
  var isSearchDismissed: Bool {
    return state == .dismissed
  }

  func deselect(_ animated: Bool) {
    searchResultsController?.deselect(animated)
  }

  private var searchBar: UISearchBar {
    return searchController.searchBar
  }

  private func event(_ e: Event) {
    let src = searchResultsController

    switch state {
    case .dismissed:
      switch e {
      case .dismiss:
        return

      case .search(let term):
        src?.search(term)

        state = .searching(term)

      case .suggest(let term):
        src?.suggest(term)

        state = .suggesting(term)
      }
      
    case .suggesting(let oldTerm):
      switch e {
      case .dismiss:
        src?.reset()

        state = .dismissed

      case .search(let term):
        src?.search(term)

        state = .searching(term)

        if searchBar.text != term {
          os_log("resetting text", log: log, type: .info)
          searchBar.text = term
        }

        if searchBar.isFirstResponder {
          os_log("resigning first responder", log: log, type: .info)
          searchBar.resignFirstResponder()
        }

      case .suggest(let term):
        guard oldTerm != term else {
          os_log("aborting: same term", log: log, type: .info)
          return
        }

        src?.suggest(term)

        state = .suggesting(term)

        if searchBar.text != term {
          os_log("resetting text", log: log, type: .info)
          searchBar.text = term
        }
      }

    case .searching(let oldTerm):
      switch e {
      case .dismiss:
        src?.reset()

        state = .dismissed

      case .search(let term):
        guard oldTerm != term else {
          os_log("aborting: same term", log: log, type: .info)
          return
        }
        
        src?.search(term)

        state = .searching(term)

      case .suggest(let term):
        src?.suggest(term)

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

// MARK: - Home

extension SearchControllerProxy: HomePresenting {}

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
    addHome()
    suggest("")
  }

  func willDismissSearchController(_ sc: UISearchController) {
    removeHome()
    dismiss()
  }
}

// MARK: - SearchResultsControllerDelegate

extension SearchControllerProxy: SearchResultsControllerDelegate {

  var isCollapsed: Bool {
    return navigationDelegate?.isCollapsed ?? true
  }

  private func show(feed: Feed) {
    navigationDelegate?.show(feed: feed, animated: true)
    
    searchController.isActive = false
  }

  private func show(entry: Entry) {
    navigationDelegate?.show(entry: entry)
    
    searchController.isActive = false
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
    os_log("resigning first responder", log: log, type: .info)
    searchBar.resignFirstResponder()
  }
}
