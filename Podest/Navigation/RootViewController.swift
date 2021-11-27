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
import Podcasts
import Combine
import AVKit

private let log = OSLog(subsystem: "ink.codes.podest", category: "root")

final class RootViewController: UIViewController, Routing {
  @IBOutlet var miniPlayerTop: NSLayoutConstraint!
  @IBOutlet var miniPlayerBottom: NSLayoutConstraint!
  @IBOutlet var miniPlayerLeading: NSLayoutConstraint!
  
  private (set) var svc: UISplitViewController!
  var minivc: MiniPlayerViewController!
  var subscriptions = Set<AnyCancellable>()
  weak var getDefaultEntry: Operation?
  
  /// The singular queue view controller.
  var qvc: QueueViewController {
    let vc = pnc.queueViewController!
    vc.navigationDelegate = self
    
    return vc
  }
  
  /// The singular episode view controller.
  var episodeViewController: EpisodeViewController? {
    let vc = (isCollapsed ? pnc : snc).episodeViewController
    vc?.navigationDelegate = self
    
    return vc
  }

  /// The singular podcast view controller.
  var listViewController: ListViewController? {
    pnc.topViewController as? ListViewController
  }

  /// This one-shot block installs the mini-player initially.
  lazy var installMiniPlayer: () = hideMiniPlayer(animated: false)

  /// The width or height of the mini-player, taken from the storyboard.
  var miniPlayerConstant: CGFloat = 0
  
  weak var pictureInPicture: AVPlayerViewController?
  
  var pnc: UINavigationController {
    svc.viewController(for: svc.isCollapsed ? .compact : .primary) as! UINavigationController
  }
  
  var snc: UINavigationController {
    svc.viewController(for: .secondary) as! UINavigationController
  }
}

// MARK: - Setup

private extension RootViewController {
  func setupMiniPlayer() {
    minivc = (children.last as! MiniPlayerViewController)
    minivc.navigationDelegate = self
    miniPlayerConstant = miniPlayerTop.constant
  }
  
  func setupSplitViewController() {
    svc = (children.first as! UISplitViewController)
    svc.delegate = self
  }
  
  func setupNavigation() {
    let ncs = svc.viewControllers as! [UINavigationController]

    for nc in ncs {
      nc.view.backgroundColor = .systemBackground
      nc.delegate = self
    }
  }
}

// MARK: - UISplitViewControllerDelegate

extension RootViewController: UISplitViewControllerDelegate {
  func splitViewController(_ svc: UISplitViewController, willShow column: UISplitViewController.Column) {
    switch svc.viewController(for: column) {
    case let vc as Navigator:
      vc.navigationDelegate = self
      
    default:
      break
    }
  }
}

// MARK: - UIViewController

extension RootViewController {
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    
    pnc.additionalSafeAreaInsets = miniPlayerEdgeInsets
    snc.additionalSafeAreaInsets = miniPlayerEdgeInsets
  }
    
  override func viewDidLoad() {
    super.viewDidLoad()
    subscribe()
    setupSplitViewController()
    setupNavigation()
    setupMiniPlayer()
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
      Podcasts.playback.reclaim()
      
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
    case let vc as Navigator:
      vc.navigationDelegate = self
      
    default:
      break
    }

    super.present(viewControllerToPresent, animated: flag, completion: completion)
  }
}

