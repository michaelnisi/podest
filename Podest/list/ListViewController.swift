//
//  ListViewController.swift
//  Podest
//
//  Created by Michael on 11/11/14.
//  Copyright (c) 2014 Michael Nisi. All rights reserved.
//

import UIKit
import FeedKit
import os.log
import BatchUpdates

private let log = OSLog(subsystem: "ink.codes.podest", category: "list")

final class ListViewController: UITableViewController,
Navigator,
EntryRowSelectable {

  /// The URL of the feed to display.
  var url: String?

  private var isSubscribed: Bool = false {
    didSet {
      configureNavigationItem(url: url!)
    }
  }

  /// Updates the `isSubscribed` property using `urls` or the user library.
  func updateIsSubscribed(using urls: Set<FeedURL>? = nil) {
    if let subscribed = urls, let url = self.url {
      isSubscribed = subscribed.contains(url)
      return
    }

    if let feed = self.feed {
      isSubscribed = Podest.userLibrary.has(subscription: feed.url)
    } else {
      // At launch, during state restoration, the user library might not be
      // sufficiently synchronized yet, so we sync and wait before configuring
      // the navigation item.

      Podest.userLibrary.synchronize { [weak self] urls, _, error in
        if let er = error {
          switch er {
          case QueueingError.outOfSync(let queue, let guids):
            if queue == 0, guids != 0 {
              os_log("queue not populated", log: log, type: .debug)
            } else {
              os_log("** out of sync: ( queue: %i, guids: %i )",
                     log: log, type: .debug, queue, guids)
            }
          default:
            fatalError("probably a database error: \(er)")
          }
        }

        DispatchQueue.main.async { [weak self] in
          guard let url = self?.url else {
            return
          }

          self?.isSubscribed = urls?.contains(url) ?? false
        }
      }
    }
  }

  /// The feed to display. If we start from `url`, `feed` will be updated after
  /// it has been fetched. Setting this to `nil` is a mistake.
  var feed: Feed? {
    didSet {
      guard let f = feed else {
        fatalError("ListViewController: feed cannot be nil")
      }

      guard f != oldValue || f.summary != oldValue?.summary else {
        return
      }

      url = feed?.url

      updateIsSubscribed()
    }
  }

  /// The table view data source.
  ///
  /// Exposing a data source for adopting a protocol, EntryRowSelectable in
  /// this case, is just gross.
  var dataSource = ListDataSource(
    browser: Podest.browser,
    images: Podest.images,
    store: Podest.store
  )

  /// The current updating operation.
  private weak var updating: Operation? {
    willSet {
      updating?.cancel()
    }
  }

  /// Navigates to items in this list.
  var navigationDelegate: ViewControllers?

  /// Deferred sequence of changes.
  private var changeBatches = [[[Change<ListDataSource.Item>]]]()

  /// Delays our commiting of above deferred changes, so refresh control can
  /// finish its hiding animation.
  private var refreshControlTimer: DispatchSourceTimer? {
    willSet {
      refreshControlTimer?.cancel()
    }
  }
  
  /// This flag is `true` after the collection has been updated it has finished
  /// its animations.
  private var isReady = false

}

// MARK: - Fetching Feed and Entries

extension ListViewController {

  private typealias Sections = [Array<ListDataSource.Item>]
  private typealias Changes = [[Change<ListDataSource.Item>]]

  private func makeUpdateOperation(
    updatesBlock: ((Sections, Changes, Error?) -> Void)? = nil
  ) -> ListOperation {
    guard let url = self.url else {
      fatalError("cannot refresh without URL")
    }

    let op = ListOperation(
      url: url, originalFeed: feed, isCompact: isCompact)

    op.feedBlock = { [weak self] feed, error in
      DispatchQueue.main.async {
        self?.feed = feed
      }
    }

    op.updatesBlock = updatesBlock

    return op
  }

  /// Reloads this list, executing `completionBlock` when done.
  ///
  /// The crux: feed and entries are separate, the feed object might not be
  /// available yet or it might contain no summary—it must be fetched remotely.
  private func update(completionBlock: (() -> Void)? = nil) {
    let op = makeUpdateOperation { [weak self] sections, changes, error in
      DispatchQueue.main.async {
        guard let tv = self?.tableView else {
          return
        }
        
        self?.isReady = false
        
        self?.dataSource.commit(changes, performingWith: .table(tv)) { _ in
          if let entry = self?.navigationDelegate?.entry {
            self?.selectRow(representing: entry, animated: true)
          }
          
          self?.additionalSafeAreaInsets = self?.navigationDelegate?.miniPlayerEdgeInsets ?? .zero
          self?.isReady = true
          
          completionBlock?()
        }
      }
    }

    updating = dataSource.add(op)
  }
  
}

// MARK: - Managing the View

extension ListViewController {

  private var isRegular: Bool {
    return traitCollection.verticalSizeClass == .regular &&
      traitCollection.horizontalSizeClass == .regular
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    refreshControl = UIRefreshControl()
    installRefreshControl()

    navigationItem.largeTitleDisplayMode = .never

    ListDataSource.registerCells(with: tableView!)

    tableView.dataSource = dataSource

    // Leaving off the last separator.
    tableView.tableFooterView = UIView(frame:
      CGRect(origin: .zero, size: CGSize(width: 0, height: 1))
    )
  }
  
  override func viewWillAppear(_ animated: Bool) {
    let isCollapsed = (splitViewController?.isCollapsed)!
    let isDifferent = entry != navigationDelegate?.entry
    
    clearsSelectionOnViewWillAppear = isCollapsed || isDifferent

    updateIsSubscribed()
   
      update()
    

    super.viewWillAppear(animated)
  }

  override func viewWillDisappear(_ animated: Bool) {
    updating?.cancel()
    refreshControlTimer = nil
    changeBatches.removeAll()

    super.viewWillDisappear(animated)
  }

}

// MARK: - Responding to a Change in the Interface Environment

extension ListViewController {

  private var isCompact: Bool {
    return !(splitViewController?.isCollapsed ?? false)
  }

  override func viewLayoutMarginsDidChange() {
    super.viewLayoutMarginsDidChange()
    
    // Preventing interference with collection animations.
    guard isReady else {
      return
    }

    additionalSafeAreaInsets = navigationDelegate?.miniPlayerEdgeInsets ?? .zero
  }

  override func traitCollectionDidChange(
    _ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)

    guard isViewLoaded else {
      return
    }

    resignFirstResponder()

    if isRegular {
      title = feed?.title
    } else {
      title = nil
    }

    // Showing or hiding header if available height has changed.

    if traitCollection.verticalSizeClass !=
      previousTraitCollection?.verticalSizeClass {
      update()
    }
  }

}

// MARK: - State Preservation and Restoration

extension ListViewController {

  override func encodeRestorableState(with coder: NSCoder) {
    coder.encode(url, forKey: "url")

    super.encodeRestorableState(with: coder)
  }

  override func decodeRestorableState(with coder: NSCoder) {
    super.decodeRestorableState(with: coder)

    guard let url = coder.decodeObject(forKey: "url") as? String else {
      return
    }

    self.url = url
  }

}

// MARK: - Managing Refresh Control

extension ListViewController {

  @objc func refreshControlValueChanged(_ sender: UIRefreshControl) {
    guard sender.isRefreshing else {
      return
    }

    changeBatches.removeAll()

    let op = makeUpdateOperation { [weak self] sections, changes, error in
      DispatchQueue.main.async {
        self?.changeBatches.append(changes)
      }
    }

    updating = dataSource.add(op, forcing: true)
  }

  private func installRefreshControl() {
    let s = #selector(refreshControlValueChanged)
    refreshControl?.addTarget(self, action: s, for: .valueChanged)
  }

  override func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
    refreshControlTimer = nil
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

      guard
        let rc = self?.refreshControl,
        !rc.isRefreshing,
        let tv = self?.tableView,
        let changes = self?.changeBatches,
        !changes.isEmpty else {
        return
      }

      UIView.performWithoutAnimation {
        for batch in changes {
          self?.dataSource.commit(batch, performingWith: .table(tv)) { ok in
            os_log("refreshed: %i", log: log, type: .debug, ok)
          }
        }

        if let entry = self?.navigationDelegate?.entry {
          self?.selectRow(representing: entry, animated: false)
        }

        self?.changeBatches.removeAll()
      }
    }

  }

}

// MARK: - UITableViewDelegate

extension ListViewController {

  override func tableView(
    _ tableView: UITableView,
    willSelectRowAt indexPath: IndexPath
  ) -> IndexPath? {
    guard case .entry? = dataSource.itemAt(indexPath: indexPath) else {
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
  
}

// MARK: - EntryProvider

extension ListViewController: EntryProvider {
  
  var entry: Entry? {
    return dataSource.entry(at:
      tableView?.indexPathForSelectedRow ??
      IndexPath(row: 0, section: 0)
    )
  }
  
}

// MARK: - Action Sheets

extension ListViewController: ActionSheetPresenting {}

// MARK: - Sharing Action Sheet

extension ListViewController {
  
  private static func makeSharingActionSheet(feed: Feed) -> [UIAlertAction] {
    var actions = [UIAlertAction]()
    
    if let openLink = makeOpenLinkAction(string: feed.link) {
      actions.append(openLink)
    }
    
    let copyFeedURL = makeCopyFeedURLAction(string: feed.url)
    actions.append(copyFeedURL)
    
    let cancel = makeCancelAction()
    actions.append(cancel)
    
    return actions
  }
  
  private func makeShareController() -> UIAlertController {
    guard let feed = self.feed else {
      fatalError("feed expected")
    }
    
    let alert = UIAlertController(
      title: nil, message: nil, preferredStyle: .actionSheet
    )
    
    let actions = ListViewController.makeSharingActionSheet(feed: feed)
    
    for action in actions {
      alert.addAction(action)
    }
    
    return alert
  }
  
}

// MARK: - Unsubscribe Action Sheet

extension ListViewController {
  
  private static func makeUnsubscribeAction(feed: Feed) -> UIAlertAction {
    let t = NSLocalizedString("Unsubscribe", comment: "Unsubscribe podcast")

    return UIAlertAction(title: t, style: .destructive) { action in
      Podest.userLibrary.unsubscribe(feed.url) { error in
        if let er = error {
          os_log("unsubscribing failed: %@", log: log, er as CVarArg)
        }
      }
    }
  }
  
  private static func makeUnsubscribeActions(feed: Feed) -> [UIAlertAction] {
    var actions =  [UIAlertAction]()
    
    let unsubscribe = makeUnsubscribeAction(feed: feed)
    let cancel = makeCancelAction()
    
    actions.append(unsubscribe)
    actions.append(cancel)
    
    return actions
  }
  
  private func makeRemoveController() -> UIAlertController {
    guard let feed = self.feed else {
      fatalError("feed expected")
    }
    
    let alert = UIAlertController(
      title: feed.title, message: nil, preferredStyle: .actionSheet
    )
    
    let actions = ListViewController.makeUnsubscribeActions(feed: feed)
    
    for action in actions {
      alert.addAction(action)
    }
    
    return alert
  }
  
}

// MARK: - Configure Navigation Item

extension ListViewController {
  
  // MARK: Action
  
  @objc func onAction(_ sender: Any) {
    let alert = makeShareController()

    self.present(alert, animated: true, completion: nil)
  }
  
  private func makeActionButton() -> UIBarButtonItem {
    return UIBarButtonItem(
      barButtonSystemItem: .action, target: self, action: #selector(onAction)
    )
  }

  @objc func onAdd(_ sender: UIBarButtonItem) {
    sender.isEnabled = false

    Podest.userLibrary.subscribe(feed!) { error in
      if let er = error {
        os_log("subscribing failed: %@", log: log, er as CVarArg)
      }

      DispatchQueue.main.async {
        sender.isEnabled = true
      }
    }
  }

  @objc func onRemove(_ sender: UIBarButtonItem) {
    let alert = makeRemoveController()

    if let presenter = alert.popoverPresentationController {
      presenter.barButtonItem = sender
    }

    self.present(alert, animated: true, completion: nil)
  }
  
  private func makeSubscribeButton(url: FeedURL) -> UIBarButtonItem {
    if isSubscribed {
      let t = NSLocalizedString("Unsubscribe", comment: "Unsubscribe podcast")

      return UIBarButtonItem(
        title: t, style: .done, target: self, action: #selector(onRemove)
      )
    }
    
    let t = NSLocalizedString("Subscribe", comment: "Subscribe podcast")

    return UIBarButtonItem(
      title: t, style: .done, target: self, action: #selector(onAdd)
    )
  }
  
  private func makeRightBarButtonItems(url: FeedURL) -> [UIBarButtonItem] {
    var items = isCompact ? [] : [makeActionButton()]

    items.append(makeSubscribeButton(url: url))

    return items
  }
  
  private func configureNavigationItem(url: FeedURL) {
    os_log("** configuring navigation item: %@",
           log: log, type: .debug, self)
    
    let items = makeRightBarButtonItems(url: url)

    navigationItem.setRightBarButtonItems(items, animated: true)
  }
  
}
