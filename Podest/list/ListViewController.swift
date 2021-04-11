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
import Podcasts

private let log = OSLog.disabled

final class ListViewController: UITableViewController, 
Navigator, EntryRowSelectable {

  /// The URL of the feed to display.
  var url: String?

  var isSubscribed: Bool = false {
    didSet {
      configureNavigationItem(url: url!)
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
    browser: Podcasts.browser,
    images: Podcasts.images,
    store: Podcasts.store
  )

  /// The current updating operation.
  weak var updating: Operation? {
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
  var isReady = false

  /// The previous trait collection influences if we should show or hide the
  /// the list header.
  private var previousTraitCollection: UITraitCollection?
  
  /// Set to `true` `shouldOverrideIsCompact` overrides the `isCompact` computed property 
  /// which folds the table view header when set to `false`.
  var shouldOverrideIsCompact: Bool = false
}

// MARK: - Managing the View

extension ListViewController {

  /// On iPad, displaying the table view header would be redundant for the main use case: 
  /// podcast primary, episode secondary.
  var isCompact: Bool {
    guard !shouldOverrideIsCompact else {
      return true
    }
    
    return navigationDelegate?.isCollapsed ?? 
      (traitCollection.horizontalSizeClass == .compact)
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    
    navigationItem.largeTitleDisplayMode = .never

    tableView?.refreshControl = UIRefreshControl()
    tableView.rowHeight = UITableView.automaticDimension
    tableView.estimatedRowHeight = 104
    tableView.dataSource = dataSource
    
    // Leaving off the last separator.
    tableView.tableFooterView = UIView(frame:
      CGRect(origin: .zero, size: CGSize(width: 0, height: 1))
    )
    
    installRefreshControl()
    ListDataSource.registerCells(with: tableView!)
  }

  override func viewWillAppear(_ animated: Bool) {
    let isDifferent = entry != navigationDelegate?.entry
    clearsSelectionOnViewWillAppear = isCompact || isDifferent

    updateIsSubscribed()
    super.viewWillAppear(animated)
  }

  override func viewWillDisappear(_ animated: Bool) {
    updating?.cancel()
    
    refreshControlTimer = nil
    
    changeBatches.removeAll()
    super.viewWillDisappear(animated)
  }
}

// MARK: - Layout Hooks

extension ListViewController {

  /// This property is `true` if traits requires an update. The vertical size
  /// class defines if we should show or hide the list header.
  private var shouldUpdate: Bool {
    return updating == nil &&
      traitCollection.verticalSizeClass != previousTraitCollection?.verticalSizeClass
  }

  override func viewWillLayoutSubviews() {
    super.viewWillLayoutSubviews()

    // Starting with iOS 13, UIKit predicts traits during initialization, thus
    // traitCollectionDidChange might not be called. Layout time is reliable.
    // Starting without previous trait collection, we do not miss the initial
    // call.

    guard traitCollection != previousTraitCollection else { return }

    resignFirstResponder()
    if shouldUpdate { update() }

    previousTraitCollection = traitCollection
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
  
  override func scrollViewShouldScrollToTop(
    _ scrollView: UIScrollView) -> Bool {
    return !(scrollView.refreshControl?.isRefreshing ?? false)
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
            os_log("refreshed: %i", log: log, type: .info, ok)
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

extension ListViewController: Unsubscribing {}

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

    Podcasts.userLibrary.subscribe(feed!) { error in
      if let er = error {
        os_log("subscribing failed: %@", log: log, er as CVarArg)
      }

      DispatchQueue.main.async {
        sender.isEnabled = true
      }
    }
  }

  @objc func onRemove(_ sender: UIBarButtonItem) {
     guard let feed = self.feed else {
      fatalError("feed expected")
    }
    
    unsubscribe(title: feed.title, url: feed.url, barButtonItem: sender)
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
    var items = !isCompact ? [] : [makeActionButton()]

    items.append(makeSubscribeButton(url: url))

    return items
  }

  private func configureNavigationItem(url: FeedURL) {
    os_log("** configuring navigation item: %@",
           log: log, type: .info, self)

    let items = makeRightBarButtonItems(url: url)

    navigationItem.setRightBarButtonItems(items, animated: true)
  }
}

/// Sets up a cancellable oneshot timer.
///
/// - Parameters:
///   - delay: The delay before `handler` is submitted to `queue`.
///   - queue: The target queue to which `handler` is submitted.
///   - handler: The block to execute after `delay`.
///
/// - Returns: The resumed oneshot timer dispatch source.
private func setTimeout(
  delay: DispatchTimeInterval,
  queue: DispatchQueue,
  handler: @escaping () -> Void
) -> DispatchSourceTimer {
  let leeway: DispatchTimeInterval = .nanoseconds(100)
  let timer = DispatchSource.makeTimerSource(queue: queue)

  timer.setEventHandler(handler: handler)
  timer.schedule(deadline: .now() + delay, leeway: leeway)
  timer.resume()

  return timer
}
