//
//  QueueViewController.swift
//  Podest
//
//  Created by Michael on 11/11/14.
//  Copyright (c) 2014 Michael Nisi. All rights reserved.
//

import FeedKit
import UIKit
import os.log
import Ola

/// The `QueueViewController` is the initial/main view controller of this app,
/// it renders the user’s queued episodes and, in its navigation item, provides
/// the global search.
final class QueueViewController: UITableViewController, Navigator {

  let log = OSLog.disabled

  /// A state machine handling events from the search controller.
  private var searchProxy: SearchControllerProxy!

  /// Saving the refresh control hiding animation.
  private var refreshControlTimer: DispatchSourceTimer? {
    willSet {
      refreshControlTimer?.cancel()
    }
  }

  // MARK: - Navigator

  /// The navigations delegate gets forwarded to the search proxy.
  var navigationDelegate: ViewControllers? {
    didSet {
      searchProxy?.navigationDelegate = navigationDelegate
    }
  }

  var isSearchDismissed: Bool {
    return searchProxy?.isSearchDismissed ?? true
  }

  // MARK: - Data Source

  /// The queue data source, indirectly via its spread dependencies, intializes
  /// a large part of a our object tree on the main queue.
  lazy var dataSource: QueueDataSource = {
    dispatchPrecondition(condition: .onQueue(.main))

    // Explicit dependencies may be wordy but they are expressive, enabling
    // controlled intialization in regards of timing and target thread. We want
    // to initialize these core objects on the main thread.

    let ds = QueueDataSource(
      userQueue: Podest.userQueue,
      store: Podest.store,
      files: Podest.files ,
      userLibrary: Podest.userLibrary,
      images: Podest.images,
      playback: Podest.playback,
      iCloud: Podest.iCloud
    )

    ds.entriesBlock = { [weak self] entries in
      dispatchPrecondition(condition: .onQueue(.main))
      Podest.images.preloadImages(
        representing: entries, at: CGSize(width: 600, height: 600))
    }

    return ds
  }()

  func updateSelection(_ animated: Bool = true) {
    guard let svc = splitViewController, svc.isCollapsed else {
      selectCurrentRow(animated: animated, scrollPosition: .none)
      return
    }

    clearSelection(animated)
  }

  // MARK: - Store Reachability

  var probe: Ola? {
    willSet {
      probe?.invalidate()
    }
  }

  // MARK: - Keeping Store Access

  private var isStoreAccessibleChanged: Bool = false

  @objc func onShowStore() {
    navigationDelegate?.showStore()
  }

  var isStoreAccessible: Bool = false {
    didSet {
      isStoreAccessibleChanged = isStoreAccessible != oldValue

      // Disabling the button must be immediate.

      guard isStoreAccessibleChanged, !isStoreAccessible else {
        return
      }

      updateStoreButton()
    }
  }

}

// MARK: - UIRefreshControl

extension QueueViewController {

  @objc func refreshControlValueChanged(_ sender: UIRefreshControl) {
    guard sender.isRefreshing, refreshControlTimer == nil else {
      return
    }

    refreshControlTimer = nil

    dataSource.update(minding: 60)
  }

  private func installRefreshControl() {
    refreshControl?.addTarget(
      self,
      action: #selector(refreshControlValueChanged),
      for: .valueChanged
    )
  }

}

// MARK: - UIScrollViewDelegate

extension QueueViewController {

  override func scrollViewDidEndDragging(
    _ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
    guard let rc = refreshControl, rc.isRefreshing else {
      return
    }

    DispatchQueue.main.async {
      rc.endRefreshing()
    }

    refreshControlTimer = setTimeout(delay: .milliseconds(600), queue: .main) {
      [weak self] in
      self?.refreshControlTimer = nil

      guard let rc = self?.refreshControl, !rc.isRefreshing else {
        return
      }

      self?.reload()
    }

  }

  override func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
    Podest.store.cancelReview()
  }

}

// MARK: - UISearchController

extension QueueViewController {

  /// Returns a new search controller and its managing proxy for accessing it.
  private static
  func makeSearchProxy() -> (UISearchController, SearchControllerProxy) {
    let searchResultsController = SearchResultsController()

    let searchController = UISearchController(
      searchResultsController: searchResultsController
    )

    let fsm = SearchControllerProxy(
      searchController: searchController,
      searchResultsController: searchResultsController
    )

    return (searchController, fsm)
  }

}

// MARK: - UIViewController

extension QueueViewController {

  override func viewDidLoad() {
    super.viewDidLoad()

    definesPresentationContext = true

    refreshControl = UIRefreshControl()
    installRefreshControl()

    let (searchController, searchProxy) = QueueViewController.makeSearchProxy()

    searchProxy.install()

    navigationItem.searchController = searchController
    navigationItem.title = "Queue"
    navigationItem.largeTitleDisplayMode = .never

    self.searchProxy = searchProxy

    QueueDataSource.registerCells(with: tableView)

    tableView.rowHeight = UITableView.automaticDimension
    tableView.estimatedRowHeight = 104

    var separatorInset = tableView.separatorInset
    separatorInset.left = UITableView.automaticDimension
    tableView.separatorInset = separatorInset

    tableView.dataSource = dataSource
    tableView.prefetchDataSource = dataSource

    clearsSelectionOnViewWillAppear = true

    Podest.store.subscriberDelegate = self

    Podest.store.resume()
  }

  private func updateStoreButton() {
    guard viewIfLoaded != nil, isStoreAccessibleChanged else {
      return
    }

    if isStoreAccessible {
      let it = UIBarButtonItem(
        title: "Free Trial",
        style: .plain,
        target: self,
        action: #selector(onShowStore)
      )

      navigationItem.leftBarButtonItem = it
    } else {
      navigationItem.leftBarButtonItem = nil
    }

    isStoreAccessibleChanged = false
  }

  override func viewWillAppear(_ animated: Bool) {
    let isCollapsed = (navigationDelegate?.isCollapsed)!
    let isDifferent = entry != navigationDelegate?.entry
    let isNotDismissed = !searchProxy.isSearchDismissed

    clearsSelectionOnViewWillAppear = (
      isCollapsed || isDifferent || isNotDismissed
    )

    super.viewWillAppear(animated)
  }

  override func viewDidAppear(_ animated: Bool) {
    if searchProxy.isSearchDismissed {
      Podest.store.considerReview()
    }

    searchProxy.deselect(animated)

    if Podest.store.isExpired() {
      os_log("free trial expired", log: log)
    }

    super.viewDidAppear(animated)
  }

  override func viewDidDisappear(_ animated: Bool) {
    updateStoreButton()

    super.viewDidDisappear(animated)
  }

  override func viewWillDisappear(_ animated: Bool) {
    refreshControlTimer = nil
    Podest.store.cancelReview()

    super.viewWillDisappear(animated)
  }

}

// MARK: - Responding to a Change in the Interface Environment

extension QueueViewController {

  override func viewLayoutMarginsDidChange() {
    super.viewLayoutMarginsDidChange()

    additionalSafeAreaInsets = navigationDelegate?.miniPlayerEdgeInsets ?? .zero
  }

  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)

    dataSource.previousTraitCollection = previousTraitCollection

    updateSelection()
  }
}

// MARK: - EntryRowSelectable

extension QueueViewController: EntryRowSelectable {}

// MARK: - EntryProvider

extension QueueViewController: EntryProvider {

  /// Couple of options here, the currently selected entry, the entry in the
  /// player, the first entry in the queue, or `nil`.
  var entry: Entry? {
    get {
      guard let indexPath = tableView.indexPathForSelectedRow else {
        return Podest.playback.currentEntry ??
          dataSource.entry(at: IndexPath(row: 0, section: 0))
      }

      return dataSource.entry(at: indexPath)
    }

    set {}
  }
}

// MARK: - PlaybackResponding

extension QueueViewController: PlaybackResponding {

  func dismiss() {
    os_log("ignoring dismiss", log: log)
  }

  func playing(entry: Entry) {
    os_log("playing: %s", log: log, type: .debug, entry.title)

    guard let cell = tableView.visibleCells
      .first(where: { $0.tag == entry.hashValue }),
      let pie = cell.accessoryView as? PieView else {
      return
    }

    pie.percentage = 0
  }

  func pausing(entry: Entry) {
    os_log("pausing: %s", log: log, type: .debug, entry.title)
  }
}
