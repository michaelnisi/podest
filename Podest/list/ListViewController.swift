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

/// The `ListViewController` maintains a feed and its entries in a table view.
/// Its API takes a feed itself or its URL. Asynchronous fetching of feed and/or
/// entries is configured by `url` or `feed`, triggered during `viewWillAppear`.
/// If the feed could not be fetched, an error message is displayed.
final class ListViewController: UITableViewController, Navigator {
  
  @IBOutlet weak var summaryTextView: UITextView?
  @IBOutlet weak var heroImage: UIImageView?
  @IBOutlet weak var titleLabel: UILabel?
  @IBOutlet weak var subtitleLabel: UILabel?
  
  /// A place to stash the table view header.
  private var header: UIView?
  
  private var traitsChanged = false
  
  /// If the header should be hidden, because height is compact, this is `true`.
  var isCompact: Bool = false {
    didSet {
      guard let url = self.url else {
        fatalError("missing URL")
      }
      
      guard isCompact != oldValue else {
        if navigationItem.rightBarButtonItems == nil {
          configureNavigationItem(url: url)
        }
        return
      }
      
      configureNavigationItem(url: url)
      
      if isCompact {
        header = tableView.tableHeaderView
        tableView.tableHeaderView = nil
      } else {
        tableView.tableHeaderView = header
        header = nil
      }

      tableView.layoutTableHeaderView()
      selectCurrentRow(animated: false)
    }
  }
  
  /// The URL of the feed to display.
  var _url: String?
  var url: String? {
    get {
      return _url
    }
    set {
      _url = newValue
      // Waiting, without feed we cannot do much.
    }
  }
  
  var isSubscribed: Bool = false {
    didSet {
      guard isSubscribed != oldValue else {
        return
      }
      configureNavigationItem(url: url!)
    }
  }
  
  private var isRefreshing: Bool {
    guard let rc = refreshControl, rc.isRefreshing else {
      return false
    }
    return true
  }
  
  private var feedChanged = false
  
  /// The feed to display. If we start from `url`, `feed` will be updated after
  /// it has been fetched. Setting this to `nil` is a mistake.
  var feed: Feed? {
    didSet {
      guard let f = feed else {
        fatalError("ListViewController: feed cannot be nil")
      }
      
      _url = feed?.url
      isSubscribed = Podest.userLibrary.has(subscription: f.url)

      feedChanged = f != oldValue || f.summary != oldValue?.summary
    }
  }
  
  /// The last time the feed object has been forcefully reloaded.
  private var forcedFeed = TimeInterval(0)

  // MARK: - Data Source

  /// Temporarily cached updates to apply later.
  private var deferred: Updates? {
    didSet {
      guard deferred != nil else {
        os_log("** deferred reset", log: log, type: .debug)
        return
      }
      os_log("** deferring", log: log, type: .debug)
    }
  }
  
  private func makeUpdatesCompletionBlock() -> ((Updates) -> Void) {
    return { [weak self] updates in
      DispatchQueue.main.async { [weak self] in
        guard !updates.isEmpty else {
          os_log("** aborting: empty updates", log: log, type: .debug)
          self?.deferred = nil
          return
        }
        
        guard let me = self, !me.isRefreshing else {
          self?.deferred = updates
          return
        }

        guard self?.deferred == nil else {
          guard let t = me.tableView else {
            return
          }
          
          os_log("** performing batch updates", log: log, type: .debug)
          
          t.performBatchUpdates({
            t.deleteRows(at: updates.rowsToDelete, with: .automatic)
            t.insertRows(at: updates.rowsToInsert, with: .automatic)
            t.reloadRows(at: updates.rowsToReload, with: .automatic)
            
            t.deleteSections(updates.sectionsToDelete, with: .automatic)
            t.insertSections(updates.sectionsToInsert, with: .automatic)
            t.reloadSections(updates.sectionsToReload, with: .automatic)
          }) { finished in
            self?.selectCurrentRow(animated: true)
            self?.deferred = nil
          }
          
          return
        }
        
        os_log("** reloading data", log: log, type: .debug)
        
        self?.tableView.reloadData()
        self?.selectCurrentRow(animated: false)
      }
    }
  }

  private func makeFeedCompletionBlock() -> ((Feed) -> Void) {
    return { [weak self] feed in
      DispatchQueue.main.async { [weak self] in
        self?.feed = feed
      }
    }
  }
  
  /// Our table view data source, providing feed and entries.
  lazy var dataSource: ListDataSource = {
    dispatchPrecondition(condition: .onQueue(.main))
    let ds = ListDataSource(browser: Podest.browser)
    ds.feedCompletionBlock = makeFeedCompletionBlock()
    ds.updatesCompletionBlock = makeUpdatesCompletionBlock()
    return ds
  }()
  
  var navigationDelegate: ViewControllers?

  /// Synchronizes selection with the navigation delegate.
  private func selectCurrentRow(animated: Bool) {
    guard let entry = navigationDelegate?.entry else {
      return
    }

    selectRow(with: entry, animated: animated)
  }
  
  // MARK: - Notification Callbacks

  private func updateIsSubscribed() {
    guard let subscribedURL = url else {
      return
    }

    isSubscribed = Podest.userLibrary.has(subscription: subscribedURL)
  }
  
}

// MARK: - UIViewController

extension ListViewController {

  private var canForceFeed: Bool {
    let now = Date().timeIntervalSince1970
    guard now - forcedFeed > 3600 else {
      return false
    }
    forcedFeed = now
    return true
  }
  
  private func update(forcing: Bool = false) {
    guard let url = self.url else {
      fatalError("cannot refresh without URL")
    }
    
    let request = ListDataSource.UpdateRequest(
      url: url, feed: feed, forcing: forcing)
    
    dataSource.update(request) { error, message in
      if let er = error {
        os_log("update error: %@",
               log: log, type: .error, er as CVarArg)
      }
      
      DispatchQueue.main.async { [weak self] in
        guard let msg = message else {
          self?.hideMessage()
          return
        }
        
        self?.showMessage(msg)
      }
    }
  }

  @objc func refreshControlValueChanged(_ sender:AnyObject) {
    os_log("** updating - refresh control changed", log: log, type: .debug)
    update(forcing: true)
    heroImage?.tag = 0
  }
  
  private func makeRefreshControl() -> UIRefreshControl {
    let rc = UIRefreshControl()
    let action = #selector(refreshControlValueChanged)
    rc.addTarget(self, action: action, for: .valueChanged)
    return rc
  }
  
  /// Resets the view, removing IB placeholders.
  private func resetView() {
    titleLabel?.text = nil
    subtitleLabel?.text = nil
    summaryTextView?.attributedText = nil
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    Cells.registerFKTextCell(with: tableView)
    
    navigationItem.largeTitleDisplayMode = .never
    
    tableView.dataSource = dataSource
    refreshControl = makeRefreshControl()
    
    // We cannot allow selection before resolving the indicator issue.
    summaryTextView?.isSelectable = false
    
    resetView()

    NotificationCenter.default.addObserver(
      forName: .FKSubscriptionsDidChange,
      object: Podest.userLibrary,
      queue: .main) { [weak self] notification in
      self?.updateIsSubscribed()
    }
  }
  
  private func updateIsCompact() {
    isCompact = {
      guard let svc = splitViewController else {
        return false
      }
      return
        !svc.isCollapsed &&
          svc.traitCollection.horizontalSizeClass == .regular
    }()
  }
  
  override func traitCollectionDidChange(
    _ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    resignFirstResponder()
    updateIsCompact()
    traitsChanged = true
  }
  
  override func viewWillAppear(_ animated: Bool) {
    let isCollapsed = (splitViewController?.isCollapsed)!
    let isDifferent = entry != navigationDelegate?.entry
    
    clearsSelectionOnViewWillAppear = isCollapsed || isDifferent

    updateIsCompact()
    
    if let feed = self.feed {
      isSubscribed = Podest.userLibrary.has(subscription: feed.url)
    } else {
      // At launch, during state restoration, the user library might not be
      // completely synchronized yet, so we sync and wait before configuring
      // the navigation item.

      Podest.userLibrary.synchronize { error in
        if let er = error {
          switch er {
          case QueueingError.outOfSync(let queue, let guids):
            os_log("** out of sync: ( queue: %i, guids: %i )",
                   log: log, type: .debug, queue, guids)
          default:
            fatalError("probably a database error: \(er)")
          }
        }
        
        DispatchQueue.main.async { [weak self] in
          guard let url = self?.url else {
            return
          }
          self?.isSubscribed = Podest.userLibrary.has(subscription: url)
        }
      }
    }
    
    update()

    super.viewWillAppear(animated)
  }
  
  override func viewWillLayoutSubviews() {
    defer {
      super.viewWillLayoutSubviews()
    }

    guard refreshControl?.isHidden ?? true else {
      return
    }

    let insets = navigationDelegate?.miniPlayerEdgeInsets ?? .zero
    tableView.scrollIndicatorInsets = insets
    tableView.contentInset = insets

    if !isCompact, let f = feed, let hero = heroImage, hero.tag != f.hashValue {
      os_log("** loading image", log: log, type: .debug)
      hero.image = nil
      hero.tag = f.hashValue
      
      Podest.images.loadImage(for: f, into: hero)
    }

    var tableHeaderViewChanged = traitsChanged
    
    if feedChanged, let f = feed {
      os_log("** updating header", log: log, type: .debug)
      titleLabel?.text = f.title
      subtitleLabel?.text = f.author
      
      if let s = f.summary {
        // Turns out, formatting the summary on the main queue is snappiest.
        summaryTextView?.attributedText = StringRepository.attribute(summary: s)
        tableHeaderViewChanged = true
      }
      
      feedChanged = false
    }
    
    if tableHeaderViewChanged {
      os_log("** laying out header", log: log, type: .debug)
      tableView.layoutTableHeaderView()
      traitsChanged = false
    }
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    dataSource.cancel()
    super.viewWillDisappear(animated)
  }

  // MARK: State Preservation and Restoration
  
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

// MARK: - UIResponder

extension ListViewController {
  
  @discardableResult override func resignFirstResponder() -> Bool {
    if let header = tableView.tableHeaderView ?? self.header {
      for view in header.subviews {
        view.resignFirstResponder()
      }
    }

    return super.resignFirstResponder()
  }
  
}

// MARK: - UIScrollViewDelegate

extension ListViewController {
  
  override func scrollViewDidEndDragging(
    _ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
    DispatchQueue.main.async { [weak self ] in
      guard let rc = self?.refreshControl, rc.isRefreshing else {
        return
      }
      
      rc.endRefreshing()
      
      // The refresh control hiding animation takes about half a second.
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
        guard let updates = self?.deferred else {
          return
        }
        
        self?.dataSource.updatesCompletionBlock?(updates)
      }
    }
  }
  
}

// MARK: - UITableViewDelegate

extension ListViewController {
  
  override func tableView(
    _ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    guard let entry = dataSource.entry(at: indexPath) else {
      fatalError("cannot select row without entries")
    }
    navigationDelegate?.show(entry: entry)
  }
  
}

// MARK: - EntryProvider

extension ListViewController: EntryProvider {
  
  var entry: Entry? {
    let ip = tableView.indexPathForSelectedRow ?? IndexPath(row: 0, section: 0)
    return dataSource.entry(at: ip)
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

// MARK: - EntryRowSelectable

extension ListViewController: EntryRowSelectable {}

// MARK: - Header Hack

extension UITableView {
  
  /// Applies temporary constraints to work around tableHeaderView’s AutoLayout
  /// [issue](https://github.com/daveanderson/TableViewHeader).
  /// I cannot believe that all this resetting is necessary.
  func layoutTableHeaderView() {
    guard let headerView = self.tableHeaderView else {
      return
    }
    
    headerView.translatesAutoresizingMaskIntoConstraints = false
    
    let headerWidth = headerView.bounds.size.width
    
    let temporaryWidthConstraints = NSLayoutConstraint.constraints(
      withVisualFormat: "[headerView(width)]",
      options: NSLayoutConstraint.FormatOptions(rawValue: UInt(0)),
      metrics: ["width": headerWidth],
      views: ["headerView": headerView]
    )
    
    headerView.addConstraints(temporaryWidthConstraints)
    
    headerView.setNeedsLayout()
    headerView.layoutIfNeeded()
    
    let headerSize = headerView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
    let height = headerSize.height
    var frame = headerView.frame
    
    frame.size.height = height
    headerView.frame = frame
    
    self.tableHeaderView = headerView
    
    headerView.removeConstraints(temporaryWidthConstraints)
    headerView.translatesAutoresizingMaskIntoConstraints = true
  }
  
}




