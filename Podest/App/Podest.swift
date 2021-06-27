//
//  Podest.swift
//  Podest
//
//  The core API of the Podest podcast app.
//
//  Created by Michael on 4/17/17.
//  Copyright © 2017 Michael Nisi. All rights reserved.
//

import Foundation
import FeedKit
import AVFoundation.AVPlayer
import UIKit
import Playback

// MARK: - Accessing Entries

/// Often we are only interested in the entry represented by participants.
protocol EntryProvider {

  /// Provides an entry that makes sense in this context.
  var entry: Entry? { get }
}

/// Maps entries to index paths.
protocol EntryIndexPathMapping {

  /// Returns the first index path matching `entry`.
  func indexPath(matching entry: Entry) -> IndexPath?
}

// MARK: - Navigation

/// The global controller API, the **root** view controller. This is the **Truth**.
/// Instead of reaching deep into the controller hierarchy, things that need
/// to be accessed from  outside should be exposed here.
protocol ViewControllers {

  // MARK: Browsing

  /// The currently shown feed.
  var feed: Feed? { get }

  /// The currently shown entry.
  var entry: Entry? { get }

  /// Shows this entry.
  func show(entry: Entry)

  /// Shows this feed listing its entries.
  func show(feed: Feed, animated: Bool)
  
  /// `true` if the Queue is currently visible.
  var isQueueVisible: Bool { get }
  
  /// Shows the Queue if it’s not visible.
  func showQueue()

  // MARK: Shopping

  /// Shows the in-app store.
  func showStore()

  // MARK: Errors

  /// A general error callback for errors that should be handled centrally.
  func viewController(_ viewController: UIViewController, error: Error)

  // MARK: External, lower level API

  /// Tries to route and open any `url`.
  func open(url: URL) -> Bool

  /// Show the feed matching the feed `url`.
  func openFeed(url: String, animated: Bool)
  
  // MARK: UI

  /// An additional property to check wether the main split view controller, to
  /// which some participants might not have access, is collapsed or not.
  ///
  /// Shun using `UISplitViewController.isCollapsed` directly, it might not be
  /// up-to-date in all use cases.
  var isCollapsed: Bool { get }
}

/// Adopt `Navigator` to receive access to the navigation delegate.
protocol Navigator: AnyObject {

  /// Use this API for navigation.
  var navigationDelegate: ViewControllers? { get set }
}

// MARK: - Accessing User Library and Queue

/// Defines a callback interface to the user library and queue.
protocol UserProxy {

  /// Updates children with `urls` of currently subscribed podcasts.
  func updateIsSubscribed(using urls: Set<FeedURL>)

  /// Updates children with `guids` of currently enqueued episodes.
  func updateIsEnqueued(using guids: Set<EntryGUID>)

  /// Updates the user’s queue, requesting downloads included, encapsulated
  /// into a stand-alone operation with a callback block, designed for
  /// background fetching.
  ///
  /// - Parameters:
  ///   - error: An upstream error to consider while updating.
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
    considering error: Error?,
    animated: Bool,
    completionHandler: @escaping ((_ newData: Bool, _ error: Error?) -> Void))

  /// Reloads queue, missing items might get fetched remotely, but saving time
  /// the queue doesn’t get updated.
  ///
  /// Use `update(completionHandler:)` to update, which includes reloading.
  func reload(completionBlock: ((Error?) -> Void)?)
}

enum Podest {
  static let gateway = AppGateway()
}
