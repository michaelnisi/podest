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

private let log = OSLog.disabled

final class ListViewController: UITableViewController,
Navigator, EntryRowSelectable {

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

  /// Internal to meet EntryRowSelectable, not good.
  var dataSource = ListDataSource(browser: Podest.browser)

  private weak var updating: Operation? {
    willSet {
      updating?.cancel()
    }
  }

  var navigationDelegate: ViewControllers?

}

// MARK: - Fetching Feed and Entries

extension ListViewController {

  private func update(forcing: Bool = false, completionBlock: (() -> Void)? = nil) {
    guard let url = self.url else {
      fatalError("cannot refresh without URL")
    }

    let op = ListDataSource.UpdateOperation(url: url, originalFeed: feed, isCompact: isCompact)

    op.feedBlock = { [weak self] feed, error in
      self?.feed = feed
    }

    op.updatesBlock = { [weak self] sections, changes, error in
      guard let tv = self?.tableView else {
        return
      }

      self?.dataSource.commit(changes, performingWith: .table(tv)) { _ in
        guard let entry = self?.navigationDelegate?.entry else {
          return
        }

        self?.selectRow(representing: entry, animated: true)
      }

    }

    op.completionBlock = completionBlock

    updating = op

    dataSource.update(op)
  }
  
}

// MARK: - Managing the View

extension ListViewController {

  override func viewDidLoad() {
    super.viewDidLoad()
    
    ListDataSource.registerCells(with: tableView!)

    navigationItem.largeTitleDisplayMode = .never
    
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

    super.viewWillAppear(animated)
  }
  
  override func viewWillLayoutSubviews() {
    defer {
      super.viewWillLayoutSubviews()
    }

    guard tableView.refreshControl?.isHidden ?? true else {
      return
    }

    let insets = navigationDelegate?.miniPlayerEdgeInsets ?? .zero

    tableView.scrollIndicatorInsets = insets
    tableView.contentInset = insets
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)

    updating?.cancel()
  }

}

// MARK: - Responding to a Change in the Interface Environment

extension ListViewController {

  private var isCompact: Bool {
    return !(splitViewController?.isCollapsed ?? false)
  }

  override func traitCollectionDidChange(
    _ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)

    resignFirstResponder()

    update()
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

//extension ListViewController {
//
//  @objc func refreshControlValueChanged(_ sender:AnyObject) {
//    guard sender.isRefreshing else {
//      return
//    }
//
//    // TODO: Update
//  }
//
//  private func makeRefreshControl() -> UIRefreshControl {
//    let rc = UIRefreshControl()
//    let action = #selector(refreshControlValueChanged)
//
//    rc.addTarget(self, action: action, for: .valueChanged)
//
//    return rc
//  }
//
//  override func scrollViewDidEndDragging(
//    _ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
//    guard let rc = tableView.refreshControl, rc.isRefreshing else {
//      return
//    }
//
//    DispatchQueue.main.async {
//      rc.endRefreshing()
//    }
//
//    // TODO: Refresh
//
//  }
//
//  override func scrollViewDidScroll(_ scrollView: UIScrollView) {
//    let y = scrollView.contentOffset.y
//
//    if lastContentOffset < y {
//      DispatchQueue.main.async {
//        self.refreshControl?.endRefreshing()
//      }
//    }
//
//    lastContentOffset = y
//
//
//
//  }
//
//}

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
