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

private let log = OSLog(subsystem: "ink.codes.podest", category: "root")

/// The root container view controller of this app, composing a split view
/// controller, with two navigation controllers, and a mini-player view 
/// controller, a custom toolbar. The `RootViewController` is mainly a proxy 
/// between components and, with its overseeing vista, supervises navigation 
/// and layout.
///
/// This class should be simple and stable glue code. More complex and dynamic
/// things should be extracted, aiming for below 600 LOC.
final class RootViewController: UIViewController, Routing {

  @IBOutlet var miniPlayerTop: NSLayoutConstraint!
  @IBOutlet var miniPlayerBottom: NSLayoutConstraint!
  @IBOutlet var miniPlayerLeading: NSLayoutConstraint!

  private var svc: UISplitViewController!

  var minivc: MiniPlayerController!
  
  /// The presented player view controller if any.
  weak var playervc: PlaybackControlDelegate? 

  private var pnc: UINavigationController!
  private var snc: UINavigationController!
  
  weak var getDefaultEntry: Operation?

  /// The singular queue view controller.
  var qvc: QueueViewController {
    return pnc.viewControllers.first {
      return $0 is QueueViewController
    } as! QueueViewController
  }
  
  /// The singular episode view controller.
  var episodeViewController: EpisodeViewController? {
    guard let nc = isCollapsed ? pnc : snc,
      let vc = nc.topViewController as? EpisodeViewController else {
      return nil
    }

    return vc
  }

  /// The singular podcast view controller.
  var listViewController: ListViewController? {
    return pnc?.topViewController as? ListViewController
  }

  /// This one-shot block installs the mini-player initially.
  lazy var installMiniPlayer: () = hideMiniPlayer(animated: false)

  /// The width or height of the mini-player, taken from the storyboard.
  var miniPlayerConstant: CGFloat = 0

  /// A reference to the current player transition delegate. Unfortunately, we
  /// need a place to hold on to it.
  var playerTransition: UIViewControllerTransitioningDelegate?
}

// MARK: - UIViewController

extension RootViewController {
  
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    
    for vc in [
      pnc.topViewController,
      pnc.navigationItem.searchController?.searchResultsController,
      snc.topViewController
    ] {
      vc?.viewLayoutMarginsDidChange()
    }
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()

    svc = (children.first as! UISplitViewController)
    svc.delegate = self

    let ncs = svc.viewControllers as! [UINavigationController]

    for nc in ncs {
      if #available(iOS 13.0, *) {
        nc.view.backgroundColor = .systemBackground
      } else {
        nc.view.backgroundColor = .white
      }
      
      nc.delegate = self
    }

    pnc = ncs.first
    pnc.navigationBar.prefersLargeTitles = true
    
    snc = ncs.last

    minivc = (children.last as! MiniPlayerController)
    minivc.navigationDelegate = self
    miniPlayerConstant = miniPlayerTop.constant

    qvc.navigationDelegate = self

    Podest.playback.delegate = self
    
    // Setting this last for a reason.
    svc.preferredDisplayMode = .allVisible
  }

  override func viewDidAppear(_ animated: Bool) {
    let _ = installMiniPlayer

    super.viewDidAppear(animated)
  }

  override func encodeRestorableState(with coder: NSCoder) {
    super.encodeRestorableState(with: coder)
    
    coder.encode(minivc, forKey: "MiniPlayerID")
    coder.encode(svc, forKey: "SplitID")
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

extension RootViewController: ViewControllers {
  
  var isCollapsed: Bool {    
    guard svc.isCollapsed else {
      os_log("** scrutinizing uncollapsed for ui-idiom: %{public}i", 
             log: log, traitCollection.userInterfaceIdiom.rawValue)

      return snc.children.isEmpty
    }
    
    return svc.isCollapsed
  }
  
  var isPresentingStore: Bool {
    guard let c = presentedViewController as? UINavigationController else {
      return false
    }
    
    return c.topViewController is ProductsViewController
  }

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
      hideMiniPlayer(animated: true)
    default:
      break
    }
  }

  func resignSearch() {
    os_log("resigning search", log: log, type: .debug)
    qvc.resignFirstResponder()
  }

  var feed: Feed? {
    guard let vc = pnc.topViewController as? ListViewController else {
      return nil
    }
    
    return vc.feed
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
    let vcs = pnc.viewControllers.reversed()
    let entries: [Entry] = vcs.compactMap {
      guard let ep = $0 as? EntryProvider else { return nil }
      return ep.entry
    }
    
    return entries.first
  }
  
  var entry: Entry? {
    guard
      let nc = isCollapsed ? pnc : snc,
      let vc = nc.topViewController as? EpisodeViewController else {
      return nil
    }
    
    return vc.entry
  }
  
  /// During state restoration, it is necessary to access via entry locators,
  /// because entries might not be retrieved yet.
  private var locator: EntryLocator? {
    if let vc = snc.topViewController as? EpisodeViewController,
      let locator = vc.locator {
      return locator
    }
    
    let vcs = pnc.viewControllers.reversed()
    
    guard
      let i = vcs.firstIndex(where: { $0 is EpisodeViewController }),
      let vc = vcs[i] as? EpisodeViewController else {
      return nil
    }
    
    return vc.locator
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

  func show(entry: Entry) {
    os_log("showing entry: %{public}@", log: log, type: .debug, entry.description)

    func go() {
      guard entry != self.entry else {
        return
      }

      let evc = self.makeEpisodeViewController(entry: entry)

      if isCollapsed {
        os_log("pushing view controller: %{public}@",
               log: log, type: .debug, evc)
        self.pnc.pushViewController(evc, animated: true)
      } else {
        let vcs = [evc]
        os_log("setting view controllers: %{public}@",
               log: log, type: .debug, vcs)
        self.snc.setViewControllers(vcs, animated: false)
      }
    }

    guard isPresentingNowPlaying else {
      return go()
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
  /// - Opening a feed `"podest://feed?url=https://rss.art1varom/the-daily"`
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
    considering error: Error? = nil,
    completionHandler: @escaping ((_ newData: Bool, _ error: Error?) -> Void)) {
    os_log("updating queue", log: log, type: .debug)
    qvc.update(considering: error, completionHandler: completionHandler)
  }

  func reload(completionBlock: ((Error?) -> Void)? = nil) {
    os_log("reloading queue", log: log, type: .debug)

    qvc.reload { error in
      dispatchPrecondition(condition: .onQueue(.main))

      if let er = error {
        os_log("reloading queue completed with error: %{public}@",
               log: log, er as CVarArg)
      }

      os_log("updating views", log: log, type: .debug)

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

// MARK: - UINavigationControllerDelegate

extension RootViewController: UINavigationControllerDelegate {

  /// Configures `viewController` for the secondary navigation controller,
  /// the details view.
  private func configureDetails(showing viewController: UIViewController) {
    switch viewController {
    case let vc as EpisodeViewController:
      os_log("setting left bar button item", log: log, type: .debug)
      vc.navigationItem.leftBarButtonItem = svc.displayModeButtonItem

      if vc.isEmpty {
        os_log("no episode selected", log: log)
      }
    default:
      fatalError("\(viewController): restricted to episodes")
    }
  }

  /// This method is called before one of our main navigation controllers,
  /// primary or secondary, shows a view controller, a good place for final
  /// adjustments.
  func navigationController(
    _ navigationController: UINavigationController,
    willShow viewController: UIViewController,
    animated: Bool
  ) {
    os_log("navigationController: willShow: %{public}@",
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
      configureDetails(showing: viewController)
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
    os_log("splitViewController: willChangeTo: %{public}@",
           log: log, type: .debug, String(describing: displayMode))

    resignFirstResponders()
  }

  // MARK: Collapsing and Expanding the Interface

  /// Returns view controllers for the primary view controller, embezzling
  /// episodes, making sure every list has a URL, and no two consecutive lists
  /// have the same URL.
  ///
  /// - Parameter source: The source view controllers to choose from.
  ///
  /// - Returns: The resulting children of the primary view controller.
  private func viewControllersForPrimary(
    reducing source: [UIViewController])-> [UIViewController] {
    os_log("reducing for primary: %{public}@",
           log: log, type: .debug, source)

    let (_, vcs) = source.reduce(("", [UIViewController]())) { acc, vc in
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

    os_log("reduced for primary: %{public}@",
           log: log, type: .debug, vcs)

    return vcs
  }

  func primaryViewController(
    forCollapsing splitViewController: UISplitViewController
  ) -> UIViewController? {
    os_log("primaryViewController: forCollapsing: %{public}@",
           log: log, type: .debug, splitViewController)
    
    guard traitCollection.userInterfaceIdiom != .phone else {
      os_log("** choosing primary view controller on phone", log: log, type: .debug)
      return nil
    }

    let vcs = viewControllersForPrimary(reducing: pnc.viewControllers)

    os_log("search dismissed: %i", log: log, type: .debug, qvc.isSearchDismissed)

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
    os_log("splitViewController: collapseSecondary: onto: %{public}@",
           log: log, type: .debug, primaryViewController)
    
    guard traitCollection.userInterfaceIdiom != .phone else {
      os_log("** not collapsing on phone", log: log, type: .debug)
      return true
    }

    guard
      let nc = secondaryViewController as? UINavigationController,
      nc == snc else {
      os_log("not collapsible: unexpected secondary: %{public}@",
             log: log, type: .error, secondaryViewController)
      fatalError()
    }

    nc.setViewControllers([], animated: false)

    return true
  }

  /// Tries to create and return an episode view controller representing our
  /// current entry or locator if we got one.
  private func makeEpisodeViewController() -> EpisodeViewController? {
    if let entry = self.selectedEntry {
      return makeEpisodeViewController(entry: entry)
    } else if let locator = self.locator {
      os_log("probably restoring state", log: log, type: .debug)
      return makeEpisodeViewController(locator: locator)
    } else {
      return nil
    }
  }

  func splitViewController(
    _ splitViewController: UISplitViewController,
    separateSecondaryFrom primaryViewController: UIViewController
  ) -> UIViewController? {        
    os_log("splitViewController: separateSecondaryFrom: %{public}@",
           log: log, type: .debug, primaryViewController)
    
    guard traitCollection.userInterfaceIdiom != .phone else {
      os_log("** not separating on phone", log: log, type: .debug)
      snc.setViewControllers([], animated: false)
      
      return snc
    }

    if let evc = makeEpisodeViewController() {
      configureDetails(showing: evc)
      snc.setViewControllers([evc], animated: false)
    } else {
      os_log("separating without entry", log: log, type: .error)
    }

    let vcs = viewControllersForPrimary(reducing: pnc.viewControllers)
    
    pnc.setViewControllers(vcs, animated: false)

    return snc
  }

  // MARK: Overriding the Presentation Behavior

  func splitViewController(
    _ splitViewController: UISplitViewController,
    show vc: UIViewController,
    sender: Any?
  ) -> Bool {
    fatalError("unexpected delegation")
  }

  func splitViewController(
    _ splitViewController: UISplitViewController,
    showDetail vc: UIViewController,
    sender: Any?
  ) -> Bool {
    fatalError("unexpected delegation")
  }
}

// MARK: - HeroProviding

extension RootViewController: HeroProviding {

  var hero: UIView? {
    guard !isMiniPlayerHidden else {
      return nil
    }
    
    return minivc.hero
  }
}

