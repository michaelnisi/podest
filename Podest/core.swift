//
//  core.swift
//  Podest
//
//  Global application protocols and extensions
//
//  Created by Michael on 4/17/17.
//  Copyright © 2017 Michael Nisi. All rights reserved.
//

import Foundation
import FeedKit
import AVFoundation

// MARK: - Controller

/// Playback section of the `ViewControllers` protocol.
protocol Players {
  
  // MARK: Essentials

  /// Starts playing `entry`.
  func play(_ entry: Entry)

  /// Pause playback.
  func pause()

  /// Returns `true` if `entry` is playing.
  func isPlaying(_ entry: Entry) -> Bool
  
  // MARK: Mini Player

  /// The mini-player edge insets, updated for device orientation.
  var miniPlayerEdgeInsets: UIEdgeInsets { get }

  /// Shows the mini-player or does nothing.
  func showMiniPlayer(_ animated: Bool)

  /// Hides the mini-player and/or resets values. Should be used to install
  /// the mini-player initially.
  func hideMiniPlayer(_ animated: Bool)
  
  // MARK: Now Playing

  /// Presents the main player with `entry`.
  func showNowPlaying(entry: Entry)

  /// Dismisses the main player.
  func hideNowPlaying(animated flag: Bool, completion: (() -> Void)?)

  /// `true` if the main player, audio or video, is visible at the moment.
  var isPlayerPresented: Bool { get }
  
  // MARK: Video

  /// Presents video `player`.
  func showVideo(player: AVPlayer)

  /// Hides video player.
  func hideVideoPlayer()
  
}

/// Regularly entries need to be passed around.
protocol EntryProvider {
  
  /// Provides an entry that makes sense in this context.
  var entry: Entry? { get }
  
}

/// Maps entries to index paths.
protocol EntryIndexPathMapping {
  
  /// Returns the first index path matching `entry`.
  func indexPath(matching entry: Entry) -> IndexPath?
  
}

/// Selects and deselects table view rows.
protocol EntryRowSelectable {
  
  associatedtype DataSource: EntryIndexPathMapping
  
  var dataSource: DataSource { get }
  
  @discardableResult func selectRow(
    representing entry: Entry?,
    animated: Bool,
    scrollPosition: UITableView.ScrollPosition
  ) -> Bool

  func clearSelection(_ animated: Bool)
  
}

extension EntryRowSelectable where Self: UITableViewController {

  @discardableResult func selectRow(
    representing entry: Entry?,
    animated: Bool,
    scrollPosition: UITableView.ScrollPosition = .none
  ) -> Bool {
    guard viewIfLoaded?.window != nil,
      let e = entry,
      let ip = dataSource.indexPath(matching: e) else {
      if let indexPathForSelectedRow = tableView.indexPathForSelectedRow {
        tableView.deselectRow(at: indexPathForSelectedRow, animated: animated)
      }
      return false
    }
    
    tableView.selectRow(at: ip, animated: animated, scrollPosition: scrollPosition)

    return true
  }

  func clearSelection(_ animated: Bool) {
    selectRow(representing: nil, animated: animated)
  }
}

/// Useful default action sheet things.
protocol ActionSheetPresenting {}

extension ActionSheetPresenting where Self: UIViewController {
  
  static func makeCancelAction(
    handler: ((UIAlertAction) -> Void)? = nil
    ) -> UIAlertAction {
    let t = NSLocalizedString("Cancel", comment: "Cancel by default")
    
    return UIAlertAction(title: t, style: .cancel, handler: handler)
  }
  
  static func makeOpenLinkAction(string: String?) -> UIAlertAction? {
    guard let link = string, let linkURL = URL(string: link) else {
      return nil
    }
    
    let t =  NSLocalizedString("Open Link", comment: "Open browser link")
    
    return UIAlertAction(title: t, style: .default) { action in
      UIApplication.shared.open(linkURL)
    }
  }
  
  static func makeCopyFeedURLAction(string: String) -> UIAlertAction {
    let t = NSLocalizedString("Copy Feed URL", comment: "Copy non-browser link")
    
    return UIAlertAction(title: t, style: .default) { action in
      UIPasteboard.general.string = string
    }
  }
  
}

/// The global controller API, the **root** view controller. This is the **Truth**.
/// Instead of reaching deep into the controller hierarchy, things that need
/// to be accessed from the outside should be exposed here.
protocol ViewControllers: Players {
  
  // MARK: Browsing
  
  var feed: Feed? { get }
  
  var entry: Entry? { get }
  
  func show(entry: Entry)
  
  func show(feed: Feed)
  
  // MARK: Shopping
  
  func showStore()
  
  // MARK: Errors
  
  /// A general error callback for errors that should be handled centrally.
  func viewController(_ viewController: UIViewController, error: Error)
  
  // MARK: External, lower level API
  
  func open(url: URL) -> Bool
  
  func openFeed(url: String)
  
  // MARK: UI
  
  /// Resigns search from being first responder.
  func resignSearch()

  /// `true` if the main split view controller is collapsed. Default is `true`.
  var isCollapsed: Bool { get }

}

/// Defines a callback interface to the user library and queue.
protocol UserProxy {

  /// Updates children with `urls` of currently subscribed podcasts.
  func updateIsSubscribed(using urls: Set<FeedURL>)

  /// Updates children with `guids` of currently enqueued episodes.
  func updateIsEnqueued(using guids: Set<EntryGUID>)

  /// Updates the user’s queue including downloading, encapsulated into a
  /// stand-alone operation with a callback block, designed for background
  /// fetching.
  ///
  /// - Parameters:
  ///   - completionHandler: The block to execute when the queue has
  /// been updated AND the view has been refreshed.
  ///   - newData: `true` if new data has been received.
  ///   - error: An error if something went wrong.
  ///
  /// Use this for background fetching, when this completion handler executes,
  /// we are ready for a new snapshot of the UI. This method is allowed 30
  /// seconds of wall-clock time before getting terminated with `0x8badf00d`.
  ///
  /// [QA](https://developer.apple.com/library/content/qa/qa1693/_index.html)
  func update(
    completionHandler: @escaping ((_ newData: Bool, _ error: Error?) -> Void))

  /// Reloads queue, missing items might get fetched remotely, but saving time
  /// the queue doesn’t get updated.
  ///
  /// Use `update(completionHandler:)` to update, which includes reloading.
  func reload(completionBlock: ((Error?) -> Void)?)

}

/// Defines `ViewControllers` users.
protocol Navigator {
  var navigationDelegate: ViewControllers? { get set }
}

// MARK: - Operation

/// A simple abstract operation super class, implementing KVO of mandatory
/// properties: `isExecuting` and `isFinished`.
class PodestOperation: Operation {
  
  fileprivate var _executing: Bool = false

  override final var isExecuting: Bool {
    get { return _executing }
    set {
      guard newValue != _executing else {
        fatalError("FeedKitOperation: already executing")
      }
      willChangeValue(forKey: "isExecuting")
      _executing = newValue
      didChangeValue(forKey: "isExecuting")
    }
  }
  
  fileprivate var _finished: Bool = false
  
  override final var isFinished: Bool {
    get { return _finished }
    set {
      guard newValue != _finished else {
        // Just to be extra annoying.
        fatalError("FeedKitOperation: already finished")
      }
      willChangeValue(forKey: "isFinished")
      _finished = newValue
      didChangeValue(forKey: "isFinished")
    }
  }
  
}
