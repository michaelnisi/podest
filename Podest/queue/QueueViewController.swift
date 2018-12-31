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

private let log = OSLog.disabled

/// The `QueueViewController` is the initial/main view controller of this app,
/// it renders the user’s queued episodes and, in its navigation item, provides
/// the global search.
final class QueueViewController: UITableViewController, Navigator {

  // MARK: - Navigator

  /// The navigations delegate gets forwarded to the search proxy.
  var navigationDelegate: ViewControllers? {
    didSet {
      searchProxy.navigationDelegate = navigationDelegate
    }
  }

  var isSearchDismissed: Bool {
    return searchProxy.isSearchDismissed
  }

  // MARK: - Data Source

  lazy var dataSource: QueueDataSource = {
    dispatchPrecondition(condition: .onQueue(.main))

    return QueueDataSource(
      userQueue: Podest.userQueue,
      images: Podest.images
    )
  }()

  /// Reloads the table view.
  ///
  /// - Parameters:
  ///   - animated: A flag to disable animations.
  ///   - completionBlock: Submitted to the main queue when the table view has
  /// has been reloaded.
  ///
  /// NOP if the table view is in editing mode.
  func reload(_ animated: Bool = true, completionBlock: ((Error?) -> Void)? = nil) {
    guard !tableView.isEditing else {
      completionBlock?(nil)
      return
    }

    dataSource.reload { [weak self] sections, updates, error in
      func done() {
        self?.selectCurrentRow(animated: false, scrollPosition: .none)
        completionBlock?(nil)
      }

      guard !updates.isEmpty else {
        return done()
      }

      guard animated else {
        self?.dataSource.sections = sections
        
        self?.tableView.reloadData()
        return done()
      }

      self?.tableView.performBatchUpdates({
        self?.dataSource.sections = sections

        let t = self?.tableView

        t?.deleteRows(at: updates.rowsToDelete, with: .none)
        t?.insertRows(at: updates.rowsToInsert, with: .none)
        t?.reloadRows(at: updates.rowsToReload, with: .none)

        t?.deleteSections(updates.sectionsToDelete, with: .none)
        t?.insertSections(updates.sectionsToInsert, with: .none)
        t?.reloadSections(updates.sectionsToReload, with: .none)
      }) { _ in
        done()
      }
    }
  }

  /// Updates the queue, fetching new episodes using the remote service.
  ///
  /// - Parameters:
  ///   - error: An upstream error to consider while updating.
  ///   - completionHandler: Submitted to the main queue when the table view
  /// has been updated.
  ///
  /// The frequency of subsequent updates is limited.
  func update(
    considering error: Error? = nil,
    completionHandler: ((Bool, Error?) -> Void)? = nil
  ) {
    let isInitial = dataSource.isEmpty || dataSource.isMessage

    guard isInitial || dataSource.shouldUpdate() else {
      completionHandler?(false, nil)
      return
    }

    let animated = !isInitial

    reload(animated) { [weak self] initialReloadError in
      self?.dataSource.update(considering: error) { newData, updateError in
        self?.reload { error in
          completionHandler?(newData, updateError ?? error)
        }
      }
    }
  }

  // MARK: - Store Reachability
  
  var probe: Ola? {
    willSet {
      probe?.invalidate()
    }
  }

  // MARK: - Keeping Store Access

  @objc func onShowStore() {
    navigationDelegate?.showStore()
  }

  var isStoreAccessibleChanged: Bool = false

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

  /// A state machine handling events from the search controller.
  private var searchProxy: SearchControllerProxy!

  /// Saving the refresh control hiding animation.
  private var refreshControlTimer: DispatchSourceTimer? {
    willSet {
      refreshControlTimer?.cancel()
    }
  }

}

// MARK: - UIRefreshControl

extension QueueViewController {

  @objc func refreshControlValueChanged(_ sender: UIRefreshControl) {
    guard sender.isRefreshing,
      refreshControlTimer == nil,
      dataSource.shouldUpdate() else {
      return
    }

    dataSource.update()
  }

  func makeRefreshControl() -> UIRefreshControl {
    let rc = UIRefreshControl()
    let action = #selector(refreshControlValueChanged)

    rc.addTarget(self, action: action, for: .valueChanged)

    return rc
  }

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

      self?.reload()
    }

  }

}

// MARK: - UIViewController

extension QueueViewController {

  private func makeSearchProxy() -> (UISearchController, SearchControllerProxy) {
    let searchResultsController = SearchResultsController()
    
    let searchController = UISearchController(
      searchResultsController: searchResultsController
    )

    searchController.hidesNavigationBarDuringPresentation = true

    let fsm = SearchControllerProxy(
      searchController: searchController,
      searchResultsController: searchResultsController
    )

    return (searchController, fsm)
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    definesPresentationContext = true

    let (searchController, searchProxy) = makeSearchProxy()

    searchProxy.install()

    navigationItem.searchController = searchController
    navigationItem.title = "Queue"
    navigationItem.largeTitleDisplayMode = .automatic

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

    // Setting the delegate first to make sure the store is in `interested` or
    // `subscribed` state to handle incoming transaction updates correctly.
    Podest.store.subscriberDelegate = self
    Podest.store.activate()
  }

  private func updateStoreButton() {
    guard viewIfLoaded != nil, isStoreAccessibleChanged else {
      return
    }
    
    if isStoreAccessible {
      let it = UIBarButtonItem(
        title: "BUY", style: .plain,
        target: self, action: #selector(onShowStore))
      navigationItem.rightBarButtonItem = it
    } else {
      navigationItem.rightBarButtonItem = nil
    }

    isStoreAccessibleChanged = false
  }

  override func viewWillAppear(_ animated: Bool) {
    let isCollapsed = (splitViewController?.isCollapsed)!
    let isDifferent = entry != navigationDelegate?.entry
    let isNotDismissed = !searchProxy.isSearchDismissed

    clearsSelectionOnViewWillAppear = (
      isCollapsed || isDifferent || isNotDismissed
    )

    super.viewWillAppear(animated)
  }

  override func viewDidAppear(_ animated: Bool) {
    searchProxy.deselect(animated)

    super.viewDidAppear(animated)
  }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    updateStoreButton()
  }
  
  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)

    let insets = navigationDelegate?.miniPlayerEdgeInsets ?? .zero
    tableView.scrollIndicatorInsets = insets
    tableView.contentInset = insets

    refreshControl = makeRefreshControl()

    if splitViewController!.isCollapsed {
      clearSelection(true)
    } else {
      selectCurrentRow(animated: true, scrollPosition: .none)
    }
  }

}

// MARK: - UITableViewDelegate

extension QueueViewController {

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
    _ tableView: UITableView,
    didSelectRowAt indexPath: IndexPath
  ) {
    guard let entry = dataSource.entry(at: indexPath) else {
      return
    }

    navigationDelegate?.show(entry: entry)
  }

  // MARK: Handling Swipe Actions

  private func makeDequeueAction(
    forRowAt indexPath: IndexPath) -> UIContextualAction {
    let h = dataSource.makeDequeueHandler(forRowAt: indexPath, of: tableView)
    let a = UIContextualAction(style: .destructive, title: nil, handler: h)
    let img = UIImage(named: "Trash")

    a.image = img

    return a
  }

  override func tableView(
    _ tableView: UITableView,
    trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
  ) -> UISwipeActionsConfiguration? {
    let actions = [makeDequeueAction(forRowAt: indexPath)]
    let conf = UISwipeActionsConfiguration(actions: actions)

    conf.performsFirstActionWithFullSwipe = true

    return conf
  }

  override func tableView(
    _ tableView: UITableView,
    didEndEditingRowAt indexPath: IndexPath?) {
    reload()
  }

}

// MARK: - EntryRowSelectable

extension QueueViewController: EntryRowSelectable {}

// MARK: - EntryProvider

extension QueueViewController: EntryProvider {

  /// Couple of options here, the currently selected entry, the entry in the
  /// player, the first entry in the queue, or `nil`.
  var entry: Entry? {
    guard let indexPath = tableView.indexPathForSelectedRow else {
      return Podest.playback.currentEntry ??
        dataSource.entry(at: IndexPath(row: 0, section: 0))
    }

    return dataSource.entry(at: indexPath)
  }

}

// MARK: - StoreAccessDelegate

extension QueueViewController: StoreAccessDelegate {
  
  func reach() -> Bool {
    let host = "https://itunes.apple.com"
    // "https://sandbox.itunes.apple.com"
    let log = OSLog.disabled
    
    guard let probe = self.probe ?? Ola(host: host, log: log) else {
      os_log("creating reachability probe failed", log: log, type: .error)
      return true
    }
    
    switch probe.reach() {
    case .cellular, .reachable:
      return true
    case .unknown:
      let ok = probe.activate { [weak self] status in
        switch status {
        case .cellular, .reachable:
          self?.probe = nil
          Podest.store.online()
        case .unknown:
          break
        }
      }
      
      if ok {
        self.probe = probe
      } else {
        os_log("installing reachability callback failed", log: log, type: .error)
      }
      
      return false
    }
  }
  
  func store(_ store: Shopping, isAccessible: Bool) {
    DispatchQueue.main.async { [weak self] in
      self?.isStoreAccessible = isAccessible
    }
  }

}
