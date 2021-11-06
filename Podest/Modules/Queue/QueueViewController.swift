//===----------------------------------------------------------------------===//
//
// This source file is part of the Podest open source project
//
// Copyright (c) 2021 Michael Nisi and collaborators
// Licensed under MIT License
//
// See https://github.com/michaelnisi/podest/blob/main/LICENSE for license information
//
//===----------------------------------------------------------------------===//

import FeedKit
import UIKit
import os.log
import Ola
import Playback
import Podcasts
import Combine

/// The `QueueViewController` is the initial/main view controller of this app,
/// it renders the user’s queued episodes and, in its navigation item, provides
/// the global search.
final class QueueViewController: UITableViewController, Navigator {

  let log = OSLog(subsystem: "ink.codes.podest", category: "queue")
  
  private var subscriptions = Set<AnyCancellable>()

  /// A state machine handling events from the search controller.
  private var searchProxy: SearchControllerProxy!
  
  /// Coordinates refreshing animations with other table view animations.
  private(set) var choreographer: Choreographing = RefreshingFSM()

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

    // Explicit dependencies are wordy but expressive, enabling controlled 
    // intialization in regards of timing and target thread. We want to 
    // initialize these core objects on the main thread.

    let ds = QueueDataSource(
      userQueue: Podcasts.userQueue,
      store: Podcasts.store,
      files: Podcasts.files ,
      userLibrary: Podcasts.userLibrary,
      images: Podcasts.images,
      playback: Podcasts.playback,
      iCloud: Podcasts.iCloud
    )

    ds.entriesBlock = { [weak self] entries in
      dispatchPrecondition(condition: .onQueue(.main))
      Podcasts.images.preloadImages(
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

  @objc func refreshControlValueChanged(target: UIRefreshControl) {
    dataSource.update(minding: 60) { [weak self] newData, error in 
      guard newData else { 
        return DispatchQueue.main.async { 
          target.endRefreshing()
        }
      }
      
      self?.reload()
    }
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

  override func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
    Podcasts.store.cancelReview()
  }
  
  override 
  func scrollViewShouldScrollToTop(_ scrollView: UIScrollView) -> Bool {
    choreographer.wait()
    return !(scrollView.refreshControl?.isRefreshing ?? false)
  }
  
  override func scrollViewDidScrollToTop(_ scrollView: UIScrollView) {
    choreographer.clear()
  }
}

// MARK: - UIViewController

extension QueueViewController {

  override func viewDidLoad() {
    super.viewDidLoad()
    
    navigationController?.navigationBar.prefersLargeTitles = true
    navigationItem.title = "Queue"
    clearsSelectionOnViewWillAppear = true
    searchProxy = SearchControllerProxy(viewController: self)
    choreographer.delegate = self
    
    refreshControl = UIRefreshControl()
    tableView.rowHeight = UITableView.automaticDimension
    tableView.estimatedRowHeight = 104
    var separatorInset = tableView.separatorInset
    separatorInset.left = UITableView.automaticDimension
    separatorInset.right = 20
    tableView.separatorInset = separatorInset
    tableView.dataSource = dataSource
    tableView.prefetchDataSource = dataSource
    
    Podcasts.store.subscriberDelegate = self
    
    searchProxy.install()
    QueueDataSource.registerCells(with: tableView)
    Podcasts.store.resume()
    installRefreshControl()
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

  override func viewDidAppear(_ animated: Bool) {
    if searchProxy.isSearchDismissed {
      Podcasts.store.considerReview()
    }
    
    if Podcasts.store.isExpired() {
      os_log("free trial expired", log: log)
    }

    searchProxy.deselect(animated)
    updateStoreButton()
    choreographer.clear()
    reload()
    _subscribe()

    super.viewDidAppear(animated)
  }

  override func viewWillDisappear(_ animated: Bool) {
    Podcasts.store.cancelReview()
    _unsubscribe()

    super.viewWillDisappear(animated)
  }
}

private extension QueueViewController {
  func _subscribe() {
    Podcasts.playback.$state.sink { [unowned self] state in
      switch state {
      case let .listening(entry, _), let .viewing(entry, _):
        self.dataSource.tableView(self.tableView, updateCellMatching: entry, isUnplayed: false)
      default:
        break
      }
    }
    .store(in: &subscriptions)
  }
  
  func _unsubscribe() {
    subscriptions.removeAll()
  }
}

// MARK: - UI Enviroment Changes

extension QueueViewController {

  override func traitCollectionDidChange(
    _ previousTraitCollection: UITraitCollection?) {
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
    guard let indexPath = tableView.indexPathForSelectedRow else {
      return dataSource.entry(at: IndexPath(row: 0, section: 0))
    }
    
    return dataSource.entry(at: indexPath)
  }
}
