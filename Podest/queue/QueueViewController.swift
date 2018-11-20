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

private let log = OSLog(subsystem: "ink.codes.podest", category: "qvc")

private enum SearchState: Int {
  case dismissed, searching, suggesting
}

private enum SearchEvent {
  case suggest, search, dismiss
}

/// The `QueueViewController` is the initial/main view controller of this app,
/// it renders the user’s queued episodes and, in its navigation item, provides
/// the global search.
final class QueueViewController: UITableViewController, Navigator {

  private var searchController: UISearchController!
  private var searchResultsController: SearchResultsController!

  // MARK: - Search FSM

  private var state = SearchState.dismissed {
    didSet {
      os_log("queue: new state: %{public}@, old state: %{public}@",
             log: log, type: .debug,
             String(describing: state), String(describing: oldValue)
      )
    }
  }

  var isDismissed: Bool { get { return state == .dismissed } }

  private var term: String? // == searchBar.text?
  private var searchBar: UISearchBar {
    get {
      return searchController.searchBar
    }
  }

  private func event(_ e: SearchEvent, term: String?) {
    let src = searchResultsController

    self.term = term

    switch state {
    case .dismissed:
      switch e {
      case .dismiss:
        break
      case .search:
        src?.search(term!)
        state = .searching
      case .suggest:
        guard term != nil, term != "" else {
          break
        }
        src?.suggest(term!)
        state = .suggesting
      }
    case .suggesting:
      switch e {
      case .dismiss:
        src?.reset()
        state = .dismissed
      case .search:
        if searchBar.text != term {
          searchBar.text = term
        }

        if searchBar.isFirstResponder {
          searchBar.resignFirstResponder()
        }

        src?.search(term!)
        state = .searching
      case .suggest:
        src?.suggest(term!)
        state = .suggesting
      }
    case .searching:
      switch e {
      case .dismiss:
        src?.reset()
        state = .dismissed
      case .search:
        src?.search(term!)
        state = .searching
      case .suggest:
        src?.suggest(term!)
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

  // MARK: - Navigator

  var navigationDelegate: ViewControllers?

  // MARK: - Data Source

  /// Deferred, temporarily cached, updates to apply later, likely, while
  /// animations are running, pull-to-refresh or swipe editing.
  private var deferred: (Updates, Error?)?

  private func selectCurrentRow(animated: Bool, scrollPosition: UITableView.ScrollPosition) {
    guard viewIfLoaded?.window != nil,
      let entry = self.navigationDelegate?.entry else {
        return
    }
    selectRow(with: entry, animated: animated, scrollPosition: scrollPosition)
  }
  
  var isFirstRun = true
  
  var shouldAnimate: Bool {
    guard navigationController?.topViewController == self else {
      return false
    }
    
    if isShowingMessage {
      return false
    } else if dataSource.isEmpty {
      return false
    } else if deferred != nil {
      return false
    } else if isFirstRun {
      return false
    }
    
    return true
  }

  /// Produces a simple closure that updates the table view.
  private func makeUpdateCompletionBlock() -> ((Updates, Error?, (() -> Void)?) -> Void) {
    return { [weak self] updates, error, completion in
      DispatchQueue.main.async { [weak self] in
        os_log("entering queue update completion block: %{public}@",
               log: log, type: .debug,
               String(describing: updates))
        
        guard error == nil else {
          if let msg = StringRepository.message(describing: error!) {
            self?.showMessage(msg)

            completion?()
            return
          }

          fatalError("unhandled error: \(error!)")
        }
        
        let shouldAnimate = self?.shouldAnimate ?? false
        let isEditing = self?.tableView.isEditing ?? false

        guard let rc = self?.refreshControl, !rc.isRefreshing, !isEditing else {
          os_log("deferring queue updates", log: log, type: .debug)
          self?.deferred = (updates, error)

          completion?()
          return
        }

        // Completion block for after reloading or animating.
        func done(animated: Bool, scrollPosition: UITableView.ScrollPosition) {
          let isEmpty = self?.dataSource.isEmpty ?? true
          
          if isEmpty {
            os_log("queue is empty", log: log, type: .debug)
            self?.showMessage(StringRepository.emptyQueue())
          } else {
            self?.selectCurrentRow(
              animated: animated, scrollPosition: scrollPosition)
          }
          
          self?.navigationItem.hidesSearchBarWhenScrolling = !isEmpty
          self?.deferred = nil

          completion?()
        }
        
        guard !updates.isEmpty else {
          os_log("leaving queue: no updates", log: log, type: .debug)
          return done(animated: false, scrollPosition: .none)
        }

        self?.hideMessage()
        self?.isFirstRun = false
        
        let t = self?.tableView
        
        guard shouldAnimate else {
          t?.reloadData()
          let scrollPosition: UITableView.ScrollPosition = {
            return self?.deferred == nil ? .middle : .none
          }()
          return done(animated: false, scrollPosition: scrollPosition)
        }
        
        self?.tableView.performBatchUpdates({ [weak t] in
          t?.deleteRows(at: updates.rowsToDelete, with: .automatic)
          t?.insertRows(at: updates.rowsToInsert, with: .automatic)
          t?.reloadRows(at: updates.rowsToReload, with: .automatic)

          t?.deleteSections(updates.sectionsToDelete, with: .automatic)
          t?.insertSections(updates.sectionsToInsert, with: .automatic)
          t?.reloadSections(updates.sectionsToReload, with: .automatic)
        }) { finished in
          done(animated: false, scrollPosition: .none)
        }
      }
    }
  }

  lazy var dataSource: QueueDataSource = {
    dispatchPrecondition(condition: .onQueue(.main))

    let ds = QueueDataSource(userQueue: Podest.userQueue, images: Podest.images)
    ds.updateCompletionBlock = makeUpdateCompletionBlock()
    ds.activate()

    return ds
  }()
  
  /// Forwards update request and completion handler to data source.
  func update(completionHandler: ((Bool, Error?) -> Void)?) {
    dataSource.update(completionHandler: completionHandler)
  }

  /// Forwards reload request and completion handler to data source.
  func reload(completionBlock: ((Error?) -> Void)?) {
    dataSource.reload(completionBlock: completionBlock)
  }

  // MARK: - Store Reachability
  
  var probe: Ola? {
    willSet {
      probe?.invalidate()
    }
  }
  
  // MARK: - Internals

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
  
  /// Orignal separator inset left from IB.
  private var separatorInsetLeft: CGFloat!

}

// MARK: - UIResponder

extension QueueViewController {

  @discardableResult override func resignFirstResponder() -> Bool {
    return searchBar.resignFirstResponder() && super.resignFirstResponder()
  }

}

// MARK: - UIViewController

extension QueueViewController {
  
  @objc func refreshControlValueChanged(_ sender:AnyObject) {
    dataSource.update(minding: 60)
  }

  func makeRefreshControl() -> UIRefreshControl {
    let rc = UIRefreshControl()
    let action = #selector(refreshControlValueChanged)
    rc.addTarget(self, action: action, for: .valueChanged)
    return rc
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    definesPresentationContext = true
    navigationItem.title = "Queue"

    refreshControl = makeRefreshControl()

    searchResultsController = SearchResultsController()
    searchResultsController.delegate = self
    searchResultsController.searchSeparatorInset = tableView.separatorInset

    searchController = UISearchController(
      searchResultsController: searchResultsController
    )
    searchController.delegate = self
    searchController.searchResultsUpdater = self
    searchBar.delegate = self

    navigationItem.searchController = searchController
    navigationItem.largeTitleDisplayMode = .always
//    navigationItem.hidesSearchBarWhenScrolling = false

    Cells.registerFKImageCell(with: tableView)
    tableView.dataSource = dataSource
    tableView.prefetchDataSource = dataSource
    separatorInsetLeft = tableView.separatorInset.left

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
    let isNotDismissed = state != .dismissed

    clearsSelectionOnViewWillAppear = (
      isCollapsed || isDifferent || isNotDismissed
    )
    
    super.viewWillAppear(animated)
  }

  override func viewDidAppear(_ animated: Bool) {
    searchController.isActive = state != .dismissed

    // Managing the selection of search results controller here from here,
    // due to easier access to the split view controller state.
    searchResultsController.scrollToSelectedRow(animated: true)
    searchResultsController.deselect(isCollapsed: (splitViewController?.isCollapsed)!)

    super.viewDidAppear(animated)
  }
  
  override func viewWillLayoutSubviews() {
    defer {
      super.viewWillLayoutSubviews()
    }

    guard !(refreshControl?.isRefreshing)! else {
      return
    }

    let insets = navigationDelegate?.miniPlayerEdgeInsets ?? .zero

    tableView.scrollIndicatorInsets = insets
    tableView.contentInset = insets
  }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    updateStoreButton()
  }
  
  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    selectCurrentRow(animated: false, scrollPosition: .middle)
   
    var insets = tableView.separatorInset
    insets.left = view.safeAreaInsets.left + separatorInsetLeft
    tableView.separatorInset = insets
  }
  
  // MARK: Managing State Restoration

  // Encountering layout issues with the search controller, state restoration
  // is disabled for now. In fact, it‘s questionable if it‘s required at all:
  // restoring search UI is kind of clunky.

  override func encodeRestorableState(with coder: NSCoder) {
    super.encodeRestorableState(with: coder)
  }

  override func decodeRestorableState(with coder: NSCoder) {
    super.decodeRestorableState(with: coder)
  }

}

// MARK: - UIScrollViewDelegate

extension QueueViewController {

  override func scrollViewDidEndDragging(
    _ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
    DispatchQueue.main.async { [weak self ] in
      guard let rc = self?.refreshControl, rc.isRefreshing else {
        return
      }
      
      rc.endRefreshing()
      
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
        guard let (updates, error) = self?.deferred else {
          return
        }
        
        self?.dataSource.updateCompletionBlock?(updates, error, nil)
      }
    }
  }

}

// MARK: - UITableViewController: UITableViewDelegate

extension QueueViewController {

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
    super.tableView(tableView, didEndEditingRowAt: indexPath)
    guard
      let (updates, error) = self.deferred,
      let cb = dataSource.updateCompletionBlock else {
      return
    }
    // Waiting just a tiny bit for the swipe animation to finish.
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      cb(updates, error, nil)
    }
  }

}

// MARK: - UISearchBarDelegate

extension QueueViewController: UISearchBarDelegate {

  func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
    guard let text = searchBar.text else {
      return
    }
    search(text)
  }

}

// MARK: - UISearchResultsUpdating

extension QueueViewController: UISearchResultsUpdating {

  func updateSearchResults(for sc: UISearchController) {
    guard let text = sc.searchBar.text, text != term else {
      return
    }
    suggest(text)
  }

}

// MARK: - UISearchControllerDelegate

extension QueueViewController: UISearchControllerDelegate {

  func willDismissSearchController(_ sc: UISearchController) {
    dismiss()
  }

}

// MARK: - SearchResultsControllerDelegate

extension QueueViewController: SearchResultsControllerDelegate {

  private func show(feed: Feed) {
    navigationDelegate?.show(feed: feed)
  }

  private func show(entry: Entry) {
    if let svc = splitViewController, !svc.isCollapsed,
      searchBar.isFirstResponder {
      searchBar.resignFirstResponder()
    }
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

// MARK: - EntryRowSelectable

extension QueueViewController: EntryRowSelectable {}

// MARK: - EntryProvider

extension QueueViewController: EntryProvider {

  /// The entry of the selected row, the first entry of the data source, or
  /// `nil`.
  var entry: Entry? {
    get {
      let indexPath = tableView.indexPathForSelectedRow ??
        IndexPath(row: 0, section: 0)
      return dataSource.entry(at: indexPath)
    }
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



