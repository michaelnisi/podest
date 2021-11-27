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

import UIKit
import FeedKit
import FeedKit
import UIKit
import os.log
import Ola
import Podcasts
import Combine
import AVKit

private let log = OSLog(subsystem: "ink.codes.podest", category: "navigation")

// MARK: - ViewControllers

extension RootViewController: ViewControllers {
  var isCollapsed: Bool {
    guard svc.isCollapsed else {
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
    os_log("showing store", log: log, type: .info)
    let vc = svc.storyboard?.instantiateViewController(withIdentifier:
      "StoreReferenceID") as! UINavigationController
    present(vc, animated: true)
  }
  
  func showQueue() {
    pnc.popToRootViewController(animated: true)
  }
  
  var isQueueVisible: Bool {
    pnc.topViewController == qvc
  }

  func viewController(_ viewController: UIViewController, error: Error) {
    os_log("error: %{public}@, from: %{public}@", log: log, error as CVarArg, viewController)

    switch viewController {
    case minivc:
      hideMiniPlayer(animated: true)
      
    default:
      break
    }
  }

  func resignSearch() {
    os_log("resigning search", log: log, type: .info)
    qvc.resignFirstResponder()
  }

  var feed: Feed? {
    pnc.feed
  }
  
  func show(feed: Feed) {
    show(feed: feed, animated: true)
  }

  func show(feed: Feed, animated: Bool) {
    guard feed != self.feed else {
      return
    }

    os_log("initiating ListViewController", log: log, type: .info)
    
    let vc = svc.storyboard?.instantiateViewController(
      withIdentifier: "EpisodesID") as! ListViewController
    
    vc.feed = feed
    vc.navigationDelegate = self
    
    pnc.pushViewController(vc, animated: animated)
  }

  /// The currently selected entry. **Note** the distinction between displayed
  /// `entry` and `selectedEntry`.
  fileprivate var selectedEntry: Entry? {
    let vcs = pnc.viewControllers.reversed()
    let entries: [Entry] = vcs.compactMap {
      guard let ep = $0 as? EntryProvider else {
        return nil
      }
      
      return ep.entry
    }
    
    return entries.first
  }
  
  var entry: Entry? {
    (isCollapsed ? pnc : snc).entry
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

  func show(entry: Entry) {
    show(entry: entry, animated: svc.isCollapsed)
  }
  
  func show(entry: Entry, animated: Bool) {
    os_log("showing entry: %{public}@", log: log, type: .info, entry.description)

    func go() {
      guard entry != self.entry else {
        return
      }
      
      let evc = MakeEpisode.viewController(item: entry, navigationDelegate: self)

      if isCollapsed {
        os_log("pushing view controller: %{public}@", log: log, type: .info, evc)
        self.pnc.pushViewController(evc, animated: animated)
      } else {
        let vcs = [evc]
        os_log("setting view controllers: %{public}@", log: log, type: .info, vcs)
        self.snc.setViewControllers(vcs, animated: animated)
      }
    }

    guard isPresentingNowPlaying else {
      return go()
    }

    hideNowPlaying(animated: true) {
      go()
    }
  }

  func openFeed(url: String, animated: Bool) {
    guard url != feed?.url else {
      return
    }

    let browser = Podcasts.browser

    var potentialFeed: Feed?

    browser.feeds([url], ttl: .forever, feedsBlock: { error, feeds in
      guard error == nil else {
        fatalError()
      }
      potentialFeed = feeds.first
    }) { [unowned self] error in
      guard error == nil else {
        fatalError()
      }
      
      guard let feed = potentialFeed else {
        os_log("not a feed: %@", log: log, url)
        return
      }
      
      DispatchQueue.main.async {
        show(feed: feed, animated: animated)
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
    os_log("opening: %{public}@", log: log, type: .info, url as CVarArg)

    switch url.host {
    case "feed":
      let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
      let queryItems = comps?.queryItems

      guard let url = queryItems?.first?.value else {
        return false
      }

      openFeed(url: url, animated: true)

      return true
      
    case "restore":
      Podcasts.store.restore()
      
      return true
      
    default:
      return false
    }
  }
}

// MARK: - Accessing User Library and Queue

extension RootViewController: UserProxy {
  func updateIsSubscribed(using urls: Set<FeedURL>) {
    os_log("updating is subscribed", log: log, type: .info)

    for child in pnc.children + snc.children {
      guard let vc = child as? ListViewController else {
        continue
      }

      vc.updateIsSubscribed(using: urls)
    }
  }

  func updateIsEnqueued(using guids: Set<EntryGUID>) {
    os_log("updating is enqueued", log: log, type: .info)

    for child in pnc.children + snc.children {
      guard let vc = child as? EpisodeViewController else {
        continue
      }
      
      vc.updateIsEnqueued(using: guids)
    }
  }

  func update(
    considering error: Error? = nil,
    animated: Bool = true,
    completionHandler: @escaping ((_ newData: Bool, _ error: Error?) -> Void)) {
    os_log("updating queue", log: log, type: .info)
    qvc.update(considering: error, animated: animated, completionHandler: completionHandler)
  }

  func reload(completionBlock: ((Error?) -> Void)? = nil) {
    os_log("reloading queue", log: log, type: .info)
    qvc.reload { error in
      dispatchPrecondition(condition: .onQueue(.main))

      if let er = error {
        os_log("reloading queue completed with error: %{public}@", log: log, er as CVarArg)
      }

      os_log("updating views", log: log, type: .info)

      guard let evc = self.episodeViewController, let entry = evc.entry else {
        completionBlock?(error)
        return
      }

      evc.isEnqueued = Podcasts.userQueue.contains(entry: entry)
      
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
      if #available(iOS 14.0, *) {
        // NOP
      } else {
        os_log("setting left bar button item", log: log, type: .info)
        vc.navigationItem.leftBarButtonItem = svc.displayModeButtonItem

        if vc.isEmpty {
          os_log("no episode selected", log: log)
        }
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
    os_log("navigationController: willShow: %{public}@", log: log, type: .info, viewController)
    getDefaultEntry?.cancel()

    if let vc = viewController as? Navigator {
      vc.navigationDelegate = self
    }

    if navigationController == pnc {
      switch viewController {
      case let vc as EpisodeViewController:
        if vc.isEmpty {
          os_log("empty episode view controller", log: log, type: .error)
        }
        
      default:
        break
      }
    }

    if navigationController == snc {
      configureDetails(showing: viewController)
    }
  }
}

// MARK: - UINavigationController

extension UINavigationController {
  var queueViewController: QueueViewController? {
    viewControllers.first {
      $0 is QueueViewController
    } as? QueueViewController
  }
  
  var episodeViewController: EpisodeViewController? {
    topViewController as? EpisodeViewController
  }

  var feed: Feed? {
    (topViewController as? ListViewController)?.feed
  }
  
  var entry: Entry? {
    episodeViewController?.entry
  }
}
