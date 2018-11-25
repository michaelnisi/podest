//
//  RootViewController.swift
//  Podest
//
//  Created by Michael on 3/17/17.
//  Copyright © 2017 Michael Nisi. All rights reserved.
//

import FeedKit
import UIKit
import os.log
import AVKit
import Ola

private let log = OSLog.disabled

/// The root container view controller of this app, composing a split view
/// controller, with two navigation controllers, and a player view controller.
/// The `RootViewController` is mainly a proxy between components and, with its
/// overseeing vista, supervises naigation and layout.
///
/// This class should be simple and stable glue code. More complex and dynamic
/// things should be extracted, aiming for below 600 LOC.
final class RootViewController: UIViewController {

  @IBOutlet var miniPlayerTop: NSLayoutConstraint!
  @IBOutlet var miniPlayerBottom: NSLayoutConstraint!
  @IBOutlet var miniPlayerLeading: NSLayoutConstraint!

  private var svc: UISplitViewController!

  var minivc: MiniPlayerController!
  var playervc: PlayerViewController?

  private var pnc: UINavigationController!
  private var snc: UINavigationController!

  weak var getDefaultEntry: Operation?

  /// The singular queue view controller.
  private var qvc: QueueViewController {
    return pnc.viewControllers.first {
      return $0 is QueueViewController
    } as! QueueViewController
  }

  /// The singular episode view controller.
  var episodeViewController: EpisodeViewController? {
    guard let nc = svc.isCollapsed ? pnc : snc,
      let vc = nc.topViewController as? EpisodeViewController else {
        return nil
    }
    return vc
  }

  /// The singular podcast view controller.
  var listViewController: ListViewController? {
    return pnc?.topViewController as? ListViewController
  }

  /// Hides the mini-player once during the lifetime of this object.
  lazy var hideMiniPlayerOnce: () = hideMiniPlayer(false)

  var miniPlayerConstant: CGFloat = 0

  /// A reference to the current player transition delegate. Unfortunately, we
  /// need a place to hold on to it.
  var playerTransition: PlayerTransitionDelegate?

  struct SimplePlaybackState {
    let entry: Entry
    let isPlaying: Bool
  }

  /// An internal serial queue for synchronized access.
  private let sQueue = DispatchQueue(label: "ink.codes.podest.root.serial")

  private var _playbackState: SimplePlaybackState?

  var playbackControlProxy: SimplePlaybackState? {
    get {
      return sQueue.sync {
        if _playbackState == nil {
          guard let entry = minivc.entry else {
            return nil
          }
          _playbackState = SimplePlaybackState(entry: entry, isPlaying: false)
        }
        return _playbackState
      }
    }
    set {
      sQueue.sync {
        _playbackState = newValue

        var targets: [PlaybackControlDelegate] = [minivc]
        if let player = playervc {
          targets.append(player)
        }

        DispatchQueue.main.async {
          self.showMiniPlayer(true)
        }

        guard let now = _playbackState else {
          for t in targets {
            DispatchQueue.main.async {
              t.dismiss()
            }
          }
          return
        }

        for t in targets {
          if now.isPlaying {
            DispatchQueue.main.async {
              t.playing(entry: now.entry)
            }
          } else {
            DispatchQueue.main.async {
              t.pausing(entry: now.entry)
            }
          }
        }
      }
    }
  }

}

// MARK: - UIViewController

extension RootViewController {

  override func viewDidLoad() {
    super.viewDidLoad()

    svc = (children.first as! UISplitViewController)
    svc.delegate = self

    let ncs = svc.viewControllers as! [UINavigationController]

    pnc = ncs.first
    pnc.delegate = self
    pnc.view.backgroundColor = .white
    pnc.navigationBar.prefersLargeTitles = traitCollection.containsTraits(in:
      UITraitCollection(horizontalSizeClass: .compact))

    snc = ncs.last
    snc.delegate = self
    snc.view.backgroundColor = .white

    minivc = (children.last as! MiniPlayerController)
    minivc.navigationDelegate = self
    miniPlayerConstant = miniPlayerTop.constant

    qvc.navigationDelegate = self

    Podest.playback.delegate = self

    // Setting this last for a reason.
    svc.preferredDisplayMode = .allVisible
  }

  override func viewDidAppear(_ animated: Bool) {
    let _ = hideMiniPlayerOnce

    super.viewDidAppear(animated)
  }

  override func encodeRestorableState(with coder: NSCoder) {
    super.encodeRestorableState(with: coder)

    coder.encode(svc, forKey: "SplitID")
    coder.encode(minivc, forKey: "MiniPlayerID")
  }

  override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
    switch presentedViewController {
    case is AVPlayerViewController:
      Podest.playback.reclaim()
    default:
      break
    }

    super.dismiss(animated: flag, completion: completion)
  }

  override func present(
    _ viewControllerToPresent: UIViewController,
    animated flag: Bool,
    completion: (() -> Void)? = nil
  ) {
    switch viewControllerToPresent {
    case var vc as Navigator:
      vc.navigationDelegate = self
    default:
      break
    }

    super.present(
      viewControllerToPresent, animated: flag, completion: completion)
  }
}

// MARK: - ViewControllers

/// There’s no dedicated presentation model, consider the view controller tree
/// as DOM, not a document object model, but an application object model. We
/// derive state from ’ViewControllers’ or more *privately* from
/// `RootViewController`.
extension RootViewController: ViewControllers {

  func showStore() {
    os_log("showing store", log: log, type: .debug)
    let vc = svc.storyboard?.instantiateViewController(withIdentifier:
      "StoreReferenceID") as! UINavigationController
    present(vc, animated: true)
  }

  func viewController(_ viewController: UIViewController, error: Error) {
    os_log("error: %{public}@, from: %{public}@", log: log,
           error as CVarArg, viewController)

    switch viewController {
    case minivc:
      hideMiniPlayer(true)
    default:
      break
    }
  }

  func resignSearch() {
    os_log("resigning search", log: log, type: .debug)
    qvc.resignFirstResponder()
  }

  var feed: Feed? {
    get {
      guard let vc = pnc.topViewController as? ListViewController else {
        return nil
      }
      return vc.feed
    }
  }

  func show(feed: Feed) {
    guard feed != self.feed else {
      return
    }

    os_log("initiating ListViewController", log: log, type: .debug)
    let vc = svc.storyboard?.instantiateViewController(withIdentifier:
      "EpisodesID") as! ListViewController
    vc.feed = feed

    pnc.pushViewController(vc, animated: true)
  }

  /// The currently selected entry. **Note** the distinction between displayed
  /// `entry` and `selectedEntry`.
  fileprivate var selectedEntry: Entry? {
    get {
      let vcs = pnc.viewControllers.reversed()
      let entries: [Entry] = vcs.compactMap {
        guard let ep = $0 as? EntryProvider else { return nil }
        return ep.entry
      }
      return entries.first
    }
  }

  var entry: Entry? {
    get {
      guard
        let nc = svc.isCollapsed ? pnc : snc,
        let vc = nc.topViewController as? EpisodeViewController else {
        return nil
      }
      return vc.entry
    }
  }

  /// During state restoration, it is necessary to access via entry locators,
  /// because entries might not be retrieved yet.
  private var locator: EntryLocator? {
    get {
      if let vc = snc.topViewController as? EpisodeViewController,
        let locator = vc.locator {
        return locator
      }
      let vcs = pnc.viewControllers.reversed()
      guard
        let i = vcs.index(where: { $0 is EpisodeViewController }),
        let vc = vcs[i] as? EpisodeViewController else {
        return nil
      }
      return vc.locator
    }
  }

  private func initiateEpisodeViewController() -> EpisodeViewController {
    let storyboard = UIStoryboard(name: "Episode", bundle: Bundle.main)
    return storyboard.instantiateViewController(withIdentifier: "EpisodeID")
      as! EpisodeViewController
  }

  private func makeEpisodeViewController(entry: Entry) -> EpisodeViewController {
    let evc = initiateEpisodeViewController()
    evc.navigationDelegate = self
    evc.entry = entry
    return evc
  }

  private func makeEpisodeViewController(
    locator: EntryLocator) -> EpisodeViewController {
    let evc = initiateEpisodeViewController()
    evc.navigationDelegate = self
    evc.locator = locator
    return evc
  }

  private static func selectRow<T: EntryRowSelectable>(
    matching entry: Entry, viewController: T?) {
    viewController?.selectRow(with: entry, animated: false, scrollPosition: .middle)
  }

  func show(entry: Entry) {
    os_log("showing entry: %{public}@", log: log, type: .debug, entry.description)

    func go() {
      guard entry != self.entry else {
        return
      }

      let evc = self.makeEpisodeViewController(entry: entry)

      if self.svc.isCollapsed {
        self.pnc.pushViewController(evc, animated: true)
      } else {
        self.snc.setViewControllers([evc], animated: false)
      }
    }

    guard isPresentingNowPlaying else {
      return go()
    }

    switch pnc.topViewController {
    case let tvc as ListViewController:
      RootViewController.selectRow(matching: entry, viewController: tvc)
    case let tvc as QueueViewController:
      RootViewController.selectRow(matching: entry, viewController: tvc)
    default:
      break
    }

    hideNowPlaying(animated: true) {
      go()
    }
  }

  func openFeed(url: String) {
    guard url != feed?.url else {
      return
    }

    let browser = Podest.browser

    var potentialFeed: Feed?

    browser.feeds([url], ttl: .forever, feedsBlock: { error, feeds in
      guard error == nil else {
        fatalError()
      }
      potentialFeed = feeds.first
    }) { [weak self] error in
      guard error == nil else {
        fatalError()
      }
      guard let feed = potentialFeed else {
        os_log("not a feed: %@", log: log, url)
        return
      }
      DispatchQueue.main.async {
        self?.show(feed: feed)
      }
    }
  }

  /// Returns `true` if opening `url` has been succesful.
  ///
  /// - Opening a feed `"podest://feed?url=https://rss.art19.com/the-daily"`
  ///
  /// - Parameter url: The URL to open.
  ///
  /// - Returns: Returns `true` if the URL has been successfully interpreted.
  func open(url: URL) -> Bool {
    os_log("opening: %{public}@", log: log, type: .debug, url as CVarArg)

    switch url.host {
    case "feed":
      let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
      let queryItems = comps?.queryItems

      guard let url = queryItems?.first?.value else {
        return false
      }

      openFeed(url: url)

      return true
    default:
      return false
    }
  }
}

// MARK: - Accessing User Library and Queue

extension RootViewController: UserProxy {

  func updateIsSubscribed(using urls: Set<FeedURL>) {
    os_log("updating is subscribed", log: log, type: .debug)

    for child in pnc.children + snc.children {
      guard let vc = child as? ListViewController else {
        continue
      }
      vc.updateIsSubscribed(using: urls)
    }
  }

  func updateIsEnqueued(using guids: Set<EntryGUID>) {
    os_log("updating is enqueued", log: log, type: .debug)

    for child in pnc.children + snc.children {
      guard let vc = child as? EpisodeViewController else {
        continue
      }
      vc.updateIsEnqueued(using: guids)
    }
  }

  func update(
    completionHandler: @escaping ((_ newData: Bool, _ error: Error?) -> Void)) {
    os_log("updating queue", log: log, type: .debug)
    qvc.update(completionHandler: completionHandler)
  }

  func reload(completionBlock: ((Error?) -> Void)? = nil) {
    os_log("reloading queue", log: log, type: .debug)
    qvc.reload { error in
      if let er = error {
        os_log("reloading queue completed with error: %{public}@",
               log: log, er as CVarArg)
      }

      os_log("updating views", log: log, type: .debug)

      // View controllers should communicate clearly if they require their
      // APIs to be called on the main queue. Here, we don’t know.

      DispatchQueue.main.async {
        self.playervc?.isForwardable = Podest.userQueue.isForwardable
        self.playervc?.isBackwardable = Podest.userQueue.isBackwardable

        guard let evc = self.episodeViewController, let entry = evc.entry else {
          completionBlock?(error)
          return
        }

        evc.isEnqueued = Podest.userQueue.contains(entry: entry)
        completionBlock?(error)
      }
    }
  }

}

// MARK: - UINavigationControllerDelegate

extension RootViewController: UINavigationControllerDelegate {

  /// This method is called before one of our main navigation controllers,
  /// primary or secondary, shows a view controller, a good place for final
  /// adjustments.
  func navigationController(
    _ navigationController: UINavigationController,
    willShow viewController: UIViewController,
    animated: Bool
  ) {
    os_log("navigationController willShow: %{public}@",
           log: log, type: .debug, viewController)

    getDefaultEntry?.cancel()

    if var vc = viewController as? Navigator {
      vc.navigationDelegate = self
    }

    if navigationController == pnc {
      switch viewController {
      case let vc as EpisodeViewController:
        if vc.isEmpty {
          os_log("empty episode view controller", log: log, type: .error)
        }
        break
      case is QueueViewController:
        break
      case is ListViewController:
        break
      default:
        break
      }
    }

    if navigationController == snc {
      switch viewController {
      case let vc as EpisodeViewController:
        vc.navigationItem.leftBarButtonItem = svc.displayModeButtonItem

        if vc.isEmpty {
          os_log("no episode selected", log: log)
        }
      default:
        fatalError("\(viewController): restricted to episodes")
      }
    }
  }

}

// MARK: - UISplitViewControllerDelegate

extension RootViewController: UISplitViewControllerDelegate {

  /// Resigns first responder on all view controllers in this tree.
  private func resignFirstResponders() {
    os_log("resigning first responders", log: log, type: .debug)

    for nc in svc.viewControllers {
      for vc in nc.children {
        vc.resignFirstResponder()
      }
    }
  }

  // MARK: Responding to Display Mode Changes

  func splitViewController(
    _ svc: UISplitViewController,
    willChangeTo displayMode: UISplitViewController.DisplayMode
  ) {
    resignFirstResponders()
  }

  // MARK: Collapsing and Expanding the Interface

  /// Returns view controllers of the collapsed primary view controller,
  /// embezzling episodes, and making sure every list gets an URL and no two
  /// consecutive lists have the same URL.
  ///
  /// - Parameter vcs: The source view controllers to choose from.
  ///
  /// - Returns: The resulting children of the primary view controller.
  private func viewControllers(
    forPrimaryCollapsed vcs: [UIViewController]
  ) -> [UIViewController] {
    let (_, vcs) = vcs.reduce(("", [UIViewController]())) { acc, vc in
      let (url, vcs) = acc
      switch vc {
      case let ls as ListViewController:
        ls.url = ls.url ?? locator?.url
        guard ls.url != url else {
          return acc
        }
        return (ls.url!, vcs + [vc])
      case is EpisodeViewController:
        return acc
      default:
        return (url, vcs + [vc])
      }
    }

    return vcs
  }

  func primaryViewController(
    forCollapsing splitViewController: UISplitViewController
  ) -> UIViewController? {
    os_log("primaryViewController forCollapsing",
           log: log, type: .debug)

    assert(snc.topViewController is EpisodeViewController)

    if let qvc = pnc.visibleViewController as? QueueViewController,
      !qvc.isDismissed {
      // Don’t interrupt searching, stick with the queue, don’t flip to the
      // current episode.
      return pnc
    }

    let vcs = viewControllers(forPrimaryCollapsed: pnc.viewControllers)

    if let entry = self.entry ?? self.selectedEntry {
      let evc = makeEpisodeViewController(entry: entry)
      pnc.setViewControllers(vcs + [evc], animated: false)
    } else if let locator = self.locator { // restoring state
      os_log("restoring: %{public}@",
             log: log, type: .debug, String(describing: locator))
    } else {
      pnc.setViewControllers(vcs, animated: false)
    }

    return pnc
  }

  func splitViewController(
    _ splitViewController: UISplitViewController,
    collapseSecondary secondaryViewController: UIViewController,
    onto primaryViewController: UIViewController
  ) -> Bool {
    os_log("splitViewController collapseSecondary onto primaryViewController",
           log: log, type: .debug)

    return true
  }

  func splitViewController(
    _ splitViewController: UISplitViewController,
    separateSecondaryFrom primaryViewController: UIViewController
  ) -> UIViewController? {
    os_log("splitViewController separateSecondaryFrom primaryViewController",
           log: log, type: .debug)

    if let entry = self.selectedEntry {
      let evc = makeEpisodeViewController(entry: entry)
      snc.setViewControllers([evc], animated: false)
    } else if let locator = self.locator { // Restoring state
      let evc = makeEpisodeViewController(locator: locator)
      snc.setViewControllers([evc], animated: false)
    } else {
      os_log("separating without entry", log: log, type: .error)
    }

    let vcs = viewControllers(forPrimaryCollapsed: pnc.viewControllers)
    pnc.setViewControllers(vcs, animated: false)

    return snc
  }

  // MARK: Overriding the Presentation Behavior

  func splitViewController(
    _ splitViewController: UISplitViewController,
    show vc: UIViewController,
    sender: Any?
  ) -> Bool {
    fatalError("unexpected splitViewController: show")
  }

  func splitViewController(
    _ splitViewController: UISplitViewController,
    showDetail vc: UIViewController,
    sender: Any?
  ) -> Bool {
    fatalError("unexpected splitViewController: showDetail")
  }
}

