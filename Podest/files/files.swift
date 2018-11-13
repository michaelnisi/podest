//
//  files.swift
//  Podest
//
//  Created by Michael Nisi on 27.02.18.
//  Copyright © 2018 Michael Nisi. All rights reserved.
//

import Foundation

/// `Downloading` provides file facilities. For the most part, this API should
/// not be used from the main queue, it might trap.
protocol Downloading: FileProxyDelegate {
  
  /// Requests opportunistic background download of `url` if necessary.
  func preload(url: URL)

  /// Cancels background downloading of `url`.
  func cancel(url: URL)
  
  /// Cancels background downloading of `url` and removes matching local file.
  func remove(url: URL)
  
  /// Requests opportunistic background downloads of queued enclosures. It’s
  /// safe to call this ignorantly, it doesn’t produce redundant downloads.
  /// Furthermore, this method should keep the cache of downloaded files at a
  /// reasonable size.
  ///
  /// - Parameters:
  ///   - removingFiles: Pass `true` to remove stale files.
  ///   - completionHandler: The block to execute when preloading requests have
  /// been forwarded.
  func preloadQueue(removingFiles: Bool, completionHandler: ((Error?) -> Void)?)
  
  /// Handles events for the background URL session matching the `identifier`.
  func handleEventsForBackgroundURLSession(
    identifier: String,
    completionHandler: @escaping () -> Void
  )

  /// Minimizes activity for background mode, flushing volatile caches,
  /// releasing resources, uninstalling reachability probes, etc.
  func flush()

  /// Returns a file URL matching `url` if the resource has been downloaded or
  /// a remote URL if not, initiating an opportunistic background download. The
  /// returned URL might be used for AV streaming, the purpose of this API.
  ///
  /// - Parameter url: The URL to access locally or remotely.
  ///
  /// - Returns: A URL for `AVPlayer`.
  ///
  /// - Throws: Throws `FileRepository.MobileData` if user defaults prevent
  /// streaming over mobile data and `url` isn’t available locally or over
  /// Wi-Fi.
  func url(for url: URL) throws -> URL
  
}
