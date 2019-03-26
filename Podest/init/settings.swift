//
//  settings.swift
//  Podest
//
//  Created by Michael Nisi on 16.03.19.
//  Copyright © 2019 Michael Nisi. All rights reserved.
//

import Foundation

/// Extending user defaults with our settings.
///
/// For preventing key collisions, all user defaults keys should be listed here,
/// which they aren’t at the moment. I’m looking at you, sync.
extension UserDefaults {

  static var automaticDownloadsKey = "automaticDownloads"
  static var mobileDataStreamingKey = "mobileDataStreaming"
  static var mobileDataDownloadsKey = "mobileDataDownloads"

  static var lastUpdateTimeKey = "ink.codes.podest.last-update"
  static var lastVersionPromptedForReviewKey = "ink.codes.podest.lastVersionPromptedForReview"

  var automaticDownloads: Bool {
    return bool(forKey: UserDefaults.automaticDownloadsKey)
  }

  var mobileDataStreaming: Bool {
    return bool(forKey: UserDefaults.mobileDataStreamingKey)
  }

  var mobileDataDownloads: Bool {
    return bool(forKey: UserDefaults.mobileDataDownloadsKey)
  }

  var lastUpdateTime: Double {
    return double(forKey: UserDefaults.lastUpdateTimeKey)
  }

  var lastVersionPromptedForReview: String? {
    return string(forKey: UserDefaults.lastVersionPromptedForReviewKey)
  }

}

extension UserDefaults {
  static var statusKey = "ink.codes.podest.status"
  static var expirationKey = "ink.codes.podest.expiration"
}

/// Additional **development** settings may override user defaults.
struct Settings {

  /// Despite disabling iCloud in Settings.app makes the better, more realistic,
  /// environment, this argument can be used during development. Passing `true`
  /// produces a NOP iCloud client at initialization time.
  ///
  /// Disabling sync also disables preloading media files.
  let noSync: Bool

  /// Removes local caches for starting over.
  let flush: Bool

  /// Prevents automatic downloading of media files. Good for quick sessions in
  /// simulators, where background downloads may be pointless.
  let noDownloading: Bool

  /// Overrides allowed interface orientations, allowing all but upside down.
  let allButUpsideDown: Bool

  /// Removes IAP receipts.
  let removeReceipts: Bool

  /// Creates new settings from process info arguments.
  init (arguments: [String]) {
    noSync = arguments.contains("-ink.codes.podest.noSync")
    flush = arguments.contains("-ink.codes.podest.flush")
    noDownloading = arguments.contains("-ink.codes.podest.noDownloading")
      || arguments.contains("-ink.codes.podest.noSync")
    allButUpsideDown = arguments.contains("-ink.codes.podest.allButUpsideDown")
    removeReceipts = arguments.contains("-ink.codes.podest.removeReceipts")
  }

}
