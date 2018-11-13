//
//  UserSyncing.swift
//  Podest
//
//  Created by Michael on 7/10/17.
//  Copyright © 2017 Michael Nisi. All rights reserved.
//

import CloudKit
import Foundation
import os.log

enum SyncError: Error {
  case notAvailable
  case missingOwner
  case subscriptionNotSaved
  case unexpectedChangeToken
  case recordZoneErrors([Error])
  case unknownZone(CKRecordZone.ID)
  case tooManyRequests(Int)
}

/// The private user database is sectionend into three zones, library for
/// subscriptions, queue for enqueued items, and log for history.
struct UserDB {
  static var containerIdentifier = "iCloud.ink.codes.podest"
  
  static var subscriptionID = "user-changes"
  static var subscriptionKey =
  "\(UserDB.containerIdentifier).\(UserDB.subscriptionID)"
  
  /// The server change token key of the database.
  static var privateCloudDatabaseChangeTokenKey
    = "\(UserDB.containerIdentifier).private"
  
  /// The, per database, client change token.
  static var privateClientChangeTokenKey =
  "\(UserDB.containerIdentifier).private.client"
  
  static var queueZoneID = CKRecordZone.ID(
    zoneName: "queueZone",
    ownerName: CKCurrentUserDefaultName
  )
  
  static var logZoneID = CKRecordZone.ID(
    zoneName: "logZone",
    ownerName: CKCurrentUserDefaultName
  )
  
  static var libraryZoneID = CKRecordZone.ID(
    zoneName: "libraryZone",
    ownerName: CKCurrentUserDefaultName
  )
  
  /// Returns server change token key for `zoneID`.
  static func ChangeTokenKey(zoneID: CKRecordZone.ID) -> String {
    return "\(UserDB.containerIdentifier).private.\(zoneID.zoneName)"
  }
}

/// Enumerates identifiers of known user zones.
enum UserZoneID: Equatable, Hashable {
  case queue(CKRecordZone.ID)
  case log(CKRecordZone.ID)
  case library(CKRecordZone.ID)

  /// Returns a new `UserZoneID` object if the `zoneID` is known.
  init?(zoneID: CKRecordZone.ID) {
    switch zoneID {
    case UserDB.libraryZoneID:
      self = .library(zoneID)
    case UserDB.logZoneID:
      self = .log(zoneID)
    case UserDB.queueZoneID:
      self = .queue(zoneID)
    default:
      return nil
    }
  }

  /// All known CloudKit record zone identifiers.
  static var all = [UserDB.libraryZoneID, UserDB.queueZoneID, UserDB.logZoneID]
}

/// Enumerates user record types.
enum UserRecordType: String {
  case queued = "Queued"
  case subscription = "Subscription"
}

/// Synchronizes user data with iCloud, encapsulating our `CloudKit` dependency.
protocol UserSyncing {
  
  /// Is `true` if we know our iCloud account status.
  var isAccountStatusKnown: Bool { get }

  /// Fetches latest changes from the iCloud database, merging them into the
  /// local cache.
  ///
  /// Initially, attempts subscribing to CloudKit push notifications. Pull might
  /// succeed, while subscriptions fail.
  ///
  /// - Parameters:
  ///   - completionHandler: The pull completion handler.
  ///   - newData: `true` if new data has been received.
  ///   - error: An error if something went wrong.
  func pull(completionHandler: @escaping (_ newData: Bool, _ error: Error?) -> Void)
  
  /// Update iCloud database with local data. Everything, not pushed yet, will
  /// be copied to iCloud.
  ///
  /// - Parameters:
  ///   - completionHandler: A block that has no return value and takes the
  /// following parameters:
  ///   - error: An error object or `nil` if data has been pushed successfully.
  func push(completionHandler: @escaping (_ error: Error?) -> Void)
  
  /// Resets the currently in-memory cached account status.
  func resetAccountStatus()
  
}
