//
//  UserClient.swift
//  Podest
//
//  Created by Michael Nisi on 26.12.17.
//  Copyright © 2017 Michael Nisi. All rights reserved.
//

import CloudKit
import FeedKit
import Foundation
import Ola
import os.log

private let log = OSLog.disabled

/// CloudKit client to synchronize user data: queue and subscriptions.
public class UserClient {
  
  private let cache: UserCacheSyncing
  private let probe: Ola
  private let queue: OperationQueue

  /// Creates and returns a new iCloud user client.
  ///
  /// - Parameters:
  ///   - cache: The local cache.
  ///   - probe: A reachability probe to use.
  ///   - queue: A **serial** operation queue.
  init(cache: UserCacheSyncing, probe: Ola, queue: OperationQueue) {
    dispatchPrecondition(condition: .onQueue(.main))
    precondition(queue.maxConcurrentOperationCount == 1)

    self.cache = cache
    self.probe = probe
    self.queue = queue
  }
  
  private let userChangesSubscriptionKey = UserDB.subscriptionKey
  
  private let container = CKContainer(identifier: UserDB.containerIdentifier)
  
  /// Merges data, `modified` and `deleted` records, received from the zone
  /// matching `zoneID` into the local cache.
  ///
  /// - Parameters:
  ///   - records: The records to integrate into the local cache.
  ///   - recordIDs: The identifiers of deleted records.
  ///   - zoneID: The zone identifier of the respective zone.
  private func merge(
    modified records: [CKRecord],
    deleted recordIDs: [CKRecord.ID],
    from zoneID: CKRecordZone.ID
  ) throws {
    os_log("merging: %@", log: log, type: .debug, zoneID)
    
    guard !records.isEmpty || !recordIDs.isEmpty else {
      os_log("already up-to-date", log: log, type: .info)
      return
    }

    // Clearly expressing our intentions.
    for record in records { precondition(record.recordID.zoneID == zoneID) }
    for recordID in recordIDs { precondition(recordID.zoneID == zoneID) }
    
    try update(records: records)
    try delete(recordIDs: recordIDs)
  }

  /// Returns GUIDs of items that should remain in the queue and GUIDs that
  /// should be removed from the queue, as tuple `(renewed, obsolete)`.
  ///
  /// - Parameters:
  ///   - current: Current items in the queue.
  ///   - previous: Previous items from the queue.
  ///
  /// - Returns: Returns a tuple containing GUIDs of renewed and obsolete items.
  static func subtract(_ current: [Queued], from previous: [Queued]
  ) -> ([EntryGUID], [EntryGUID]) {
    os_log("subtracting lists counting: (%i, %i)",
           log: log, type: .debug, current.count, previous.count)

    // Inspecting the number of previously enqueued, I’m surprised how quickly
    // these go into the hundreds, even now, limited to one per feed. To check
    // on this kind of stuff, it would be helpful if CloudKit Dashboard would
    // allow more complex queries, for example, listing all records where a
    // specific field isn’t unique, which would be evidence in this case.

    guard !current.isEmpty else {
      os_log("skipping loop: empty list", log: log, type: .debug)
      return ([], [])
    }

    // Applying a simple loop to segregate renewed and obsolete identifiers.

    var renewed = Set<EntryGUID>()
    var obsolete = Set<EntryGUID>()

    for p in previous {
      switch p {
      case .previous(let prevLoc, let prevTs):
        let prevGuid = prevLoc.guid!

        for c in current {
          switch c {
          case .pinned(let loc, let ts, _):
            guard loc.guid == prevGuid else {
              continue
            }

            let isNewer = ts > prevTs

            // If, on this device, users enqueued an item after it had been
            // removed on another device, we keep it.

            if isNewer {
              renewed.insert(prevGuid)
            } else {
              obsolete.insert(prevGuid)
            }

          case .temporary(let loc, _, _):
            guard loc.guid == prevGuid else {
              continue
            }

            // Automatically enqueued items are always removed.

            obsolete.insert(prevGuid)

          case .previous:
            continue
          }
        }
      default:
        continue
      }
    }

    return (Array(renewed), Array(obsolete))
  }

  /// Dequeues items that have been previously dequeued, but are still in the
  /// queue locally.
  private func dequeuePrevious() throws {
    os_log("dequeuing previous", log: log, type: .debug)

    let prev = try cache.previous()
    let current = try cache.locallyQueued()

    // TODO: Review dequeuing of previous items

    // Assuming the full history here would be overkill, so we have limited
    // the log of previously queued items to the latest per feed, which has
    // changed our assumptions.

    let (renewed, obsolete) = UserClient.subtract(current, from: prev)

    try cache.removePrevious(matching: renewed)
    try cache.removeQueued(obsolete)
  }
  
  @available(iOS 12.0, *)
  private static func makeZoneConfigurations(zoneIDs: [CKRecordZone.ID]
  ) -> [CKRecordZone.ID : CKFetchRecordZoneChangesOperation.ZoneConfiguration] {
    var r = [CKRecordZone.ID : CKFetchRecordZoneChangesOperation.ZoneConfiguration]()

    for zoneID in zoneIDs {
      let zoneKey = UserDB.ChangeTokenKey(zoneID: zoneID)
      let token = serverChangeToken(for: zoneKey)

      let conf = CKFetchRecordZoneChangesOperation.ZoneConfiguration(
        previousServerChangeToken: token)

      r[zoneID] = conf
    }

    return r
  }
  
  private static func makeFetchZoneChangesOptions(zoneIDs: [CKRecordZone.ID]
  ) -> [CKRecordZone.ID : CKFetchRecordZoneChangesOperation.ZoneOptions] {
    var r = [CKRecordZone.ID : CKFetchRecordZoneChangesOperation.ZoneOptions]()

    for zoneID in zoneIDs {
      let opts = CKFetchRecordZoneChangesOperation.ZoneOptions()

      let zoneKey = UserDB.ChangeTokenKey(zoneID: zoneID)
      let prev = serverChangeToken(for: zoneKey)
      opts.previousServerChangeToken = prev

      r[zoneID] = opts
    }

    return r
  }

  private func makeFetchRecordZoneChangesOperation(
    zoneIDs: [CKRecordZone.ID]
  ) -> CKFetchRecordZoneChangesOperation {
    if #available(iOS 12.0, *) {
      let confs = UserClient.makeZoneConfigurations(zoneIDs: zoneIDs)
      let op = CKFetchRecordZoneChangesOperation(
        recordZoneIDs: zoneIDs, configurationsByRecordZoneID: confs)
      op.fetchAllChanges = true
      return op
    } else {
      let opts = UserClient.makeFetchZoneChangesOptions(zoneIDs: zoneIDs)
      let op = CKFetchRecordZoneChangesOperation(
        recordZoneIDs: zoneIDs, optionsByRecordZoneID: opts)
      op.fetchAllChanges = true
      return op
    }
  }

  /// Our default database is the private cloud database.
  private var db: CKDatabase {
    return container.privateCloudDatabase
  }
  
  /// Fetches the changes in zones matching `zoneIDs`.
  ///
  /// If a zone has been deleted by users, we reset its local cache and
  /// re-enter this method, fetching zone change again.
  ///
  /// - Parameters:
  ///   - zoneIDs: Identifies zones to fetch changes from.
  ///   - retrying: For certain errors this operation can retry itself.
  ///   - completionBlock: The completion block to execute when ready.
  ///   - error: A conclusive error if something went wrong.
  private func fetchZoneChanges(
    _ zoneIDs: [CKRecordZone.ID],
    retrying: Bool = false,
    completionBlock: @escaping (_ error: Error?) -> Void) {
    guard !zoneIDs.isEmpty else {
      os_log("not fetching zone changes without identifiers", log: log)
      return completionBlock(nil)
    }

    os_log("fetching changes for zones: %@", log: log, type: .debug, zoneIDs)

    let op = makeFetchRecordZoneChangesOperation(zoneIDs: zoneIDs)

    // Accumulating deletions and changes per zone.
    var changesByZone = [CKRecordZone.ID: ([CKRecord.ID], [CKRecord])]()

    op.recordChangedBlock = { record in
      let zoneID = record.recordID.zoneID
      guard let (deleted, changed) = changesByZone[zoneID] else {
        changesByZone[zoneID] = ([], [record])
        return
      }
      changesByZone[zoneID] = (deleted, changed + [record])
    }

    op.recordWithIDWasDeletedBlock = { recordID, _ in
      let zoneID = recordID.zoneID
      guard let (deleted, changed) = changesByZone[zoneID] else {
        changesByZone[zoneID] = ([recordID], [])
        return
      }
      changesByZone[zoneID] = (deleted + [recordID], changed)
    }

    // Accumlating all zone errors for conclusive handling, when fetching
    // record zone changes completes, in the final block of this scope.
    var zoneErrors = [Error]()
    
    op.recordZoneFetchCompletionBlock = { recordZoneID, serverChangeToken,
      clientChangeTokenData, _, recordZoneError in

      guard recordZoneError == nil else {
        os_log("zone fetch error: %{public}@",
               log: log, recordZoneError! as CVarArg)

        // Possibly, we still have received changes.
        if let (deletions, changes) = changesByZone[recordZoneID] {
          os_log("dismissing retrieved changes: ( %i, %i )",
                 log: log, deletions.count, changes.count)
        }

        zoneErrors.append(recordZoneError!)

        if let er = recordZoneError as? CKError {
          switch er.code {
          case .userDeletedZone, .changeTokenExpired:
            do {
              try self.resetLocalCache(representing: [recordZoneID])
            } catch {
              zoneErrors.append(error)
            }
          default:
            break
          }
        }

        return
      }
      
      guard let token = serverChangeToken else {
        zoneErrors.append(SyncError.unexpectedChangeToken)
        return
      }
      
      let clientChangeToken = UserClient.makeUUID(
        data: clientChangeTokenData)

      let info = [
        "recordZoneID: \(recordZoneID)",
        "serverChangeToken: \(String(describing: serverChangeToken))",
        "clientChangeToken: \(String(describing: clientChangeToken))"
      ]
      os_log("zone fetch complete: %@", log: log, type: .debug, info)
      
      if let previousClientChangeToken = UserClient.clientChangeToken(
        for: UserDB.privateClientChangeTokenKey) {
        if previousClientChangeToken == clientChangeToken {
          os_log("previous push succeeded for zone: %@",
                 log: log, type: .debug, recordZoneID)
        } else {
          os_log("""
            previous push failed: differing client token for zone: {
              zone: %@
              theirs: %@,
              ours: %@
            """, log: log,
                 recordZoneID,
                 String(describing: clientChangeToken),
                 String(describing: previousClientChangeToken)
          )
        }
      }

      guard let (deleted, changed) = changesByZone[recordZoneID] else {
        return
      }

      do {
        try self.merge(modified: changed, deleted: deleted, from: recordZoneID)
      } catch {
        zoneErrors.append(error)
        return
      }
      
      // Saving the latest server change token if merging succeeded.
      let zoneKey = UserDB.ChangeTokenKey(zoneID: recordZoneID)
      UserClient.save(token: token, for: zoneKey)
    }
    
    // finally
    op.fetchRecordZoneChangesCompletionBlock = { operationError in
      os_log("fetching zone changes complete", log: log, type: .debug)

      guard operationError == nil, zoneErrors.isEmpty else {
        if let opErr = operationError {
          os_log("operation error: %{public}@", log: log, opErr as CVarArg)
        }

        for zoneError in zoneErrors {
          os_log("zone error: %{public}@", log: log, zoneError as CVarArg)
        }

        // Retrying once if we got zone errors.
        if retrying, !zoneErrors.isEmpty {
          os_log("retrying after zone errors", log: log)
          self.fetchZoneChanges(zoneIDs, completionBlock: completionBlock)
          return
        }

        let er = operationError ?? SyncError.recordZoneErrors(zoneErrors)
        return completionBlock(er)
      }

      let error: Error? = {
        do { try self.dequeuePrevious() } catch { return error }
        return nil
      }()

      completionBlock(error)
    }

    db.add(op)
  }

  /// Removes local data representing `zoneIDs`, but keeps the records table if
  /// not all our zones have been purged.
  private func resetLocalCache(representing zoneIDs: [CKRecordZone.ID]) throws {
    guard !zoneIDs.isEmpty else {
      return
    }

    // Putting the log zone identifier last to prevent re-pushing of dequeued
    // items if queue and log zone are being purged at the same time.
    let sorted = zoneIDs.sorted { $1 == UserDB.logZoneID }

    for zoneID in sorted {
      let zoneName = zoneID.zoneName

      os_log("** purging zone: %@", log: log, zoneName)

      try cache.purgeZone(named: zoneName)

      if zoneName == UserDB.queueZoneID.zoneName {
        try cache.removeStalePrevious()
      }

      UserClient.resetServerChangeToken(matching: zoneID)
    }
  }
  
  /// Fetches all database changes since the last fetch, might retry for
  /// resilience.
  ///
  /// - Parameters:
  ///   - retrying: Pass `true` to retry once under certain circumstances, like
  /// `CKError.changeTokenExpired`, for example.
  ///   - completionHandler: The block to execute with the result.
  ///   - changed: The zone identifiers of the changed zones.
  ///   - deleted: The zone identifier of deleted zones.
  ///   - error: An error if something went wrong.
  private func fetchDatabaseChanges(
    retrying: Bool,
    completionHandler: @escaping (
    _ changed: [CKRecordZone.ID],
    _ deleted: [CKRecordZone.ID],
    _ error: Error?) -> Void
  ) {
    let prev = UserClient.serverChangeToken(
      for: UserDB.privateCloudDatabaseChangeTokenKey)
    let op = CKFetchDatabaseChangesOperation(previousServerChangeToken: prev)
    op.fetchAllChanges = true
    
    var changedZoneIDs = [CKRecordZone.ID]()
    op.recordZoneWithIDChangedBlock = { zoneID in
      os_log("zone changed: %{public}@", log: log, type: .debug, zoneID)
      changedZoneIDs.append(zoneID)
    }
    
    var deletedZoneIDs = [CKRecordZone.ID]()
    op.recordZoneWithIDWasDeletedBlock = { zoneID in
      os_log("zone was deleted: %{public}@", log: log, type: .debug, zoneID)
      deletedZoneIDs.append(zoneID)
    }
    
    op.fetchDatabaseChangesCompletionBlock = { serverChangeToken, _, error in
      guard error == nil else {
        switch error! {
        case CKError.changeTokenExpired:
          os_log("change token expired", log: log)
          do {
            // Tossing local cache, starting from scratch.
            try self.resetLocalCache(representing: UserZoneID.all)
          } catch {
            // Additional logging before giving up with .changeTokenExpired.
            os_log("resetting cache failed: %{public}@",
                   log: log, type: .error, String(describing: error))
            break
          }
          
          os_log("retrying to fetch database changes", log: log)
          return self.fetchDatabaseChanges(
            retrying: false, completionHandler: completionHandler)
        default:
          break
        }
        
        return completionHandler([], [], error)
      }
      
      guard let now = serverChangeToken else {
        return completionHandler([], [], SyncError.unexpectedChangeToken)
      }

      if !deletedZoneIDs.isEmpty {
        do {
          try self.resetLocalCache(representing: deletedZoneIDs)
        } catch {
          os_log("resetting cache failed: %{public}@",
                 log: log, type: .error, String(describing: error))
          return completionHandler([], [], error)
        }
      }
      
      UserClient.save(token: now, for: UserDB.privateCloudDatabaseChangeTokenKey)
      completionHandler(changedZoneIDs, deletedZoneIDs, nil)
    }
    
    os_log("fetching database changes: %@", log: log, type: .debug,
           String(describing: prev))

    db.add(op)
  }
  
  private func createZones(
    with zoneIDs: [CKRecordZone.ID],
    cb: @escaping (Error?) -> Void) {
    
    let zones = zoneIDs.map { CKRecordZone(zoneID: $0) }
    let op = CKModifyRecordZonesOperation(
      recordZonesToSave: zones, recordZoneIDsToDelete: nil)
    
    op.modifyRecordZonesCompletionBlock = {
      savedRecordZones, deletedRecordZoneIDs, operationError in
      guard operationError == nil else {
        return cb(operationError)
      }
      
      cb(nil)
    }

    db.add(op)
  }
  
  /// An internal serial queue, mainly to serialize access.
  private let serialQueue = DispatchQueue(label: "ink.codes.podest.sync")
  
  private var _accountStatus: CKAccountStatus?

  private var accountStatus: CKAccountStatus? {
    get {
      return serialQueue.sync {
        return _accountStatus
      }
    }
    
    set {
      serialQueue.sync {
        _accountStatus = newValue
      }
    }
  }
  
  /// Checks and caches the user‘s iCloud account status.
  ///
  /// - Parameters:
  ///   - currentStatus: Optionally, the assumed current account status,
  /// overriding and replacing the cached status.
  ///   - cb: The callback, taking an optional error.
  private func checkAccount(
    assuming currentStatus: CKAccountStatus?, cb: @escaping (Error?) -> Void) {
    os_log("checking account", log: log, type: .debug)
    
    self.accountStatus = currentStatus
    
    guard self.accountStatus != .noAccount else {
      return cb(SyncError.notAvailable)
    }
    
    guard self.accountStatus != .available else {
      return cb(nil)
    }
    
    container.accountStatus { accountStatus, error in
      guard error == nil else {
        return cb(error)
      }
      
      self.accountStatus = accountStatus
      
      switch accountStatus {
      case .available:
        os_log("account status: %@", log: log, type: .debug, "available")
        cb(nil)
      case .couldNotDetermine:
        os_log("account status: %@", log: log, type: .debug, "could not determine")
        cb(SyncError.notAvailable)
        break
      case .noAccount:
        // THAT guy would ask the user to log in. Silently handling sync, once
        // hey are logged is more elegant, but requires a deeper solution.
        os_log("account status: %@", log: log, type: .debug, "no account")
        cb(SyncError.notAvailable)
        break
      case .restricted:
        os_log("account status: %@", log: log, type: .debug, "restricted")
        cb(SyncError.notAvailable)
        break
      }
    }
  }
  
}

// MARK: - Subscriptions

extension UserClient {
  
  private var subscribed: Bool {
    get {
      return UserDefaults.standard.bool(forKey: userChangesSubscriptionKey)
    }
    set {
      UserDefaults.standard.set(newValue, forKey: userChangesSubscriptionKey)
    }
  }
  
  private static func makeSubscriptions() -> [CKSubscription] {
    let info = CKSubscription.NotificationInfo()
    info.shouldSendContentAvailable = true
    
    let databaseSubscription = CKDatabaseSubscription(
      subscriptionID: UserDB.subscriptionID)
    databaseSubscription.notificationInfo = info
    
    return [databaseSubscription]
  }
  
  /// Subscribes for background fetching.
  private func subscribe(cb: @escaping ((Error?) -> Void)) {
    let subscriptions = UserClient.makeSubscriptions()
    let op = CKModifySubscriptionsOperation(
      subscriptionsToSave: subscriptions, subscriptionIDsToDelete: nil)
    
    op.modifySubscriptionsCompletionBlock = { savedSubscriptions,
      deletedSubscriptionIDs, operationError in
      guard operationError == nil else {
        self.subscribed = false
        return cb(operationError)
      }
      self.subscribed = true
      cb(operationError)
    }
    
    // Just a reminder, .utility is the default anyway.
    op.qualityOfService = .utility

    db.add(op)
  }
  
}

// MARK: - Serializing Records

extension UserClient {
  
  private static func makeQueued(
    locator: EntryLocator,
    timestamp: Date,
    record: CKRecord
  ) -> Queued {
    let iTunes = iTunesItem(from: record, url: locator.url)
    guard
      let v = record.value(forKey: "queuedOwner") as? Int,
      let owner = QueuedOwner.init(rawValue: v) else {
      os_log("unexpected owner: %@", log: log, record)
      return .temporary(locator, timestamp, iTunes)
    }
    switch owner {
    case .nobody, .subscriber:
      return .temporary(locator, timestamp, iTunes)
    case .user:
      return .pinned(locator, timestamp, iTunes)
    }
  }

  private static func makeEntryLocator(record: CKRecord) -> EntryLocator? {
    guard
      let guid = record.value(forKey: "guid") as? String,
      let url = record.value(forKey: "url") as? String,
      let since = record.value(forKey: "since") as? Date
      else {
      return nil
    }
    return EntryLocator(url: url, since: since, guid: guid)
  }
  
  private static func iTunesItem(
    from record: CKRecord, url: FeedURL) -> ITunesItem? {
    guard
      let img100 = record.value(forKey: "img100") as? String,
      let img30 = record.value(forKey: "img30") as? String,
      let img60 = record.value(forKey: "img60") as? String,
      let img600 = record.value(forKey: "img600") as? String,
      let iTunesID = record.value(forKey: "iTunesID") as? Int
      else {
      return nil
    }
    return ITunesItem(
      url: url,
      iTunesID: iTunesID,
      img100: img100,
      img30: img30,
      img60: img60,
      img600: img600
    )
  }
  
  /// `Synced` from `record`.
  static func synced(from record: CKRecord) -> Synced? {
    let recordID = record.recordID

    guard let zoneID = UserZoneID(zoneID: recordID.zoneID) else {
      os_log("unknown zone: %{public}@", log: log, recordID)
      return nil
    }
    
    guard let recordType = UserRecordType(rawValue: record.recordType) else {
      os_log("unknown record type: %@", log: log, record.recordType)
      return nil
    }
    
    switch zoneID {
    case .library:
      switch recordType {
      case .subscription:
        guard
          let url = record.value(forKey: "url") as? String,
          let ts = record.value(forKey: "ts") as? Date
          else {
          os_log("unexpected record: %{public}@", log: log, record)
          return nil
        }
        
        let iTunes = iTunesItem(from: record, url: url)
        let s = Subscription(url: url, ts: ts, iTunes: iTunes)
        
        let r = RecordMetadata(
          zoneName: recordID.zoneID.zoneName,
          recordName: recordID.recordName,
          changeTag: record.recordChangeTag
        )
        
        return .subscription(s, r)
      default:
        os_log("unexpected record for library zone", log: log)
        return nil
      }
    case .queue:
      switch recordType {
      case .queued:
        guard
          let loc = makeEntryLocator(record: record),
          let ts = record.value(forKey: "ts") as? Date
          else {
          os_log("unexpected record: %{public}@", log: log, record)
          return nil
        }
        
        let queued = makeQueued(locator: loc, timestamp: ts, record: record)
   
        let r = RecordMetadata(
          zoneName: recordID.zoneID.zoneName,
          recordName: recordID.recordName,
          changeTag: record.recordChangeTag
        )
        
        return .queued(queued, r)
      default:
        os_log("unexpected record for queue zone", log: log)
        return nil
      }
    case .log:
      switch recordType {
      case .queued:
        guard
          let loc = makeEntryLocator(record: record),
          let ts = record.value(forKey: "ts") as? Date
          else {
          os_log("unexpected record: %{public}@", log: log, record)
          return nil
        }
        
        let queued = Queued.previous(loc, ts)
        
        let r = RecordMetadata(
          zoneName: recordID.zoneID.zoneName,
          recordName: recordID.recordName,
          changeTag: record.recordChangeTag
        )
        
        return .queued(queued, r)
      default:
        os_log("unexpected record for log zone", log: log)
        return nil
      }
    }
  }
  
  /// Returns `record` after setting key-values of `iTunes` on it.
  private static func record(with iTunes: ITunesItem?, record: CKRecord) -> CKRecord {
    if let it = iTunes {
      record.setValue(it.img100, forKey: "img100")
      record.setValue(it.img30, forKey: "img30")
      record.setValue(it.img60, forKey: "img60")
      record.setValue(it.img600, forKey: "img600")
      record.setValue(it.iTunesID, forKey: "iTunesID")
    }
    return record
  }
  
  private static func makeQueuedRecord(
    zoneID: CKRecordZone.ID,
    locator: EntryLocator,
    timestamp: Date,
    owner: QueuedOwner,
    iTunes: ITunesItem? = nil
  ) -> CKRecord {
    let id = CKRecord.ID(zoneID: zoneID)
    let rec = CKRecord(recordType: "Queued", recordID: id)
    
    rec.setValue(locator.guid, forKey: "guid")
    rec.setValue(locator.since, forKey: "since")
    rec.setValue(locator.url, forKey: "url")
    rec.setValue(timestamp, forKey: "ts")
    rec.setValue(owner.rawValue, forKey: "queuedOwner")
    
    return record(with: iTunes, record: rec)
  }
  
  /// Returns `queued` record.
  static func record(from queued: Queued) -> CKRecord {
    switch queued {
    case .temporary(let loc, let ts, let iTunes):
      return UserClient.makeQueuedRecord(
        zoneID: UserDB.queueZoneID, locator: loc, timestamp: ts, owner: .nobody,
        iTunes: iTunes)
    case .pinned(let loc, let ts, let iTunes):
      return UserClient.makeQueuedRecord(
        zoneID: UserDB.queueZoneID, locator: loc, timestamp: ts, owner: .user,
        iTunes: iTunes)
    case .previous(let loc, let ts):
      // Historically, owners are irrelevant.
      return UserClient.makeQueuedRecord(
        zoneID: UserDB.logZoneID, locator: loc, timestamp: ts, owner: .nobody)
    }
  }
  
  /// CloudKit record from `subscription`.
  static func record(from subscription: Subscription) -> CKRecord {
    let id = CKRecord.ID(zoneID: UserDB.libraryZoneID)
    let rec = CKRecord(recordType: "Subscription", recordID: id)
    
    rec.setValue(subscription.url, forKey: "url")
    rec.setValue(subscription.ts, forKey: "ts")
    
    return record(with: subscription.iTunes, record: rec)
  }
  
}

// MARK: - Pushing Data to CloudKit

extension UserClient {
  
  /// Saves modifications to the private iCloud database, modifying and deleting
  /// records, creating specified zones, not just zones not found, but also user
  /// deleted zones, assuming users could always disable iCloud for this app.
  ///
  /// - Parameters:
  ///   - modifications: The modifications to save.
  ///   - retrying: Some errors can be compensated by retrying.
  ///   - modifyCompletionBlock: The block to handle completion.
  ///   - error: The error if something went wrong.
  private func save(
    modifications m: Modifications,
    retrying: Bool = false,
    modifyCompletionBlock cb: @escaping (_ error: Error?) -> Void) {
    guard !m.isEmpty else {
      os_log("everything up-to-date", log: log, type: .info)
      return cb(nil)
    }

    os_log("saving modifications: %i", log: log, type: .debug, m.count)

    if m.count > 400 {
      os_log("ink.codes.podest.sync: too many requests: %i", type: .error, m.count)
//      cb(SyncError.tooManyRequests(m.count))
      // TODO: Handle too many requests
    }

    let clientChangeToken = UUID()
    let op = m.makeOperation(uuid: clientChangeToken)

    // Accumulating records that haven’t been saved because they’re respective
    // zones do not exist.
    var notFound = Set<CKRecord>()
    var userDeleted = Set<CKRecord>()
    
    op.perRecordCompletionBlock = { record, error in
      if let er = error {
        os_log("per record error: (%{public}@, %{public}@)",
               log: log, record, er as CVarArg)

        switch er {
        case CKError.zoneNotFound:
          notFound.insert(record)
        case CKError.userDeletedZone:
          userDeleted.insert(record)
        default:
          break
        }
      }
    }
    
    op.modifyRecordsCompletionBlock = {
      savedRecords, deletedRecordIDs, operationError in
      guard operationError == nil else {
        os_log("operation error: %{public}@", log: log, operationError! as CVarArg)

        // Checking missing zones.

        let notFoundZoneIDs = notFound.compactMap { $0.recordID.zoneID }
        let userDeletedZoneIDs = userDeleted.compactMap { $0.recordID.zoneID }
        
        if !userDeletedZoneIDs.isEmpty {
          os_log("user deleted zones: %@", log: log, Set(userDeletedZoneIDs))
        }

        let missingZoneIDs = Set(notFoundZoneIDs + userDeletedZoneIDs)

        if missingZoneIDs.isEmpty {
          guard let er = operationError as? CKError,
            let partials = er.partialErrorsByItemID else {
            os_log("giving up: could not compensate operation error", log: log)
            return cb(operationError)
          }

          // Attempts to delete records in zones that have been purged by the
          // user aren’t reported per record, in the per record completion
          // block above.

          if partials.contains(where: { key, value in
            guard let er = value as? CKError else {
              return false
            }
            return er.code == .userDeletedZone
          }) {
            do {
              os_log("** deleting zombies", log: log, type: .debug)
              try self.cache.deleteZombies()
            } catch {
              os_log("could not delete zombies: %{public}@",
                     log: log, error as CVarArg)
            }
          }

          os_log("giving up: zombies deleted", log: log)
          return cb(operationError)
        }
        
        os_log("creating missing zones: %@",
               log: log, type: .debug, missingZoneIDs)
        
        return self.createZones(with: Array(missingZoneIDs)) { error in
          guard error == nil else {
            os_log("error creating zones: %{public}@", log: log, error! as CVarArg)
            return cb(error)
          }

          let s = notFound.union(userDeleted)
          let d = Set(m.recordIDsToDelete).subtracting(Set(deletedRecordIDs ?? []))
          let rest = Modifications(recordsToSave: s, recordIDsToDelete: d)

          self.save(modifications: rest, modifyCompletionBlock: cb)
        }
      }

      // The End
      
      UserClient.save(token: clientChangeToken, for: UserDB.privateClientChangeTokenKey)
      
      if let sr = savedRecords {
        os_log("saved records: %i", log: log, type: .debug, sr.count)
        do {
          let items = sr.compactMap { UserClient.synced(from: $0) }
          try self.cache.add(synced: items)
        } catch {
          return cb(error)
        }
      }
      
      if let dr = deletedRecordIDs {
        // Deleted records are including non-existent records.
        os_log("deleted records: %i", log: log, type: .debug, dr.count)
        do {
          let names = dr.map { $0.recordName }
          try self.cache.remove(recordNames: names )
        } catch {
          return cb(error)
        }
      }

      let savedCount = savedRecords?.count ?? 0
      let deletedCount = deletedRecordIDs?.count ?? 0
      let diff = m.count - savedCount - deletedCount
      if  diff > 0 {
        os_log("** %i modifications not saved", log: log, type: .debug, diff)
      } else {
        os_log("all modifications saved", log: log, type: .debug)
      }

      do {
        os_log("deleting zombies", log: log, type: .debug)
        try self.cache.deleteZombies()
      } catch {
        cb(error)
      }
      
      cb(nil)
    }

    db.add(op)
  }
  
}

// MARK: - Integrating Data from CloudKit

extension UserClient {
  
  private func delete(recordIDs: [CKRecord.ID]) throws {
    os_log("deleting: %i", log: log, type: .debug, recordIDs.count)
    
    try cache.remove(recordNames: recordIDs.map { $0.recordName })
  }
  
  private func update(records: [CKRecord]) throws {
    os_log("updating: %i", log: log, type: .debug, records.count)
    
    let items = records.compactMap { UserClient.synced(from: $0) }
    
    try cache.add(synced: items)
  }
  
}

// MARK: - UserSyncing

extension UserClient: UserSyncing {
  
  var isAccountStatusKnown: Bool {
    return accountStatus != nil
  }
  
  private struct Modifications {
    let recordsToSave: Set<CKRecord>
    let recordIDsToDelete: Set<CKRecord.ID>

    init(recordsToSave: Set<CKRecord>, recordIDsToDelete: Set<CKRecord.ID>) {
      self.recordsToSave = recordsToSave
      self.recordIDsToDelete = recordIDsToDelete
    }

    func makeOperation(uuid: UUID) -> CKModifyRecordsOperation {
      let op = CKModifyRecordsOperation(
        recordsToSave: Array(recordsToSave),
        recordIDsToDelete: Array(recordIDsToDelete)
      )
      op.clientChangeTokenData = uuid.uuidString.data(using: .utf8)!
      return op
    }

    init?(
      queued: [Queued],
      subscriptions: [Subscription],
      zombieRecords: [(String, String)]
    ) {
      os_log("""
      initializing modifications: (
        queued: %@,
        subscriptions: %@,
        zombies: %@
      )
      """, log: log, type: .debug, queued, subscriptions, zombieRecords)

      let a = queued.compactMap { UserClient.record(from: $0) }
      let b = subscriptions.compactMap { UserClient.record(from: $0) }
      
      self.recordsToSave = Set(a + b)
      
      self.recordIDsToDelete = Set(zombieRecords.map {
        let (zoneName, recordName) = $0
        let zoneID = CKRecordZone.ID(
          zoneName: zoneName,
          ownerName: CKCurrentUserDefaultName
        )
        return CKRecord.ID(recordName: recordName, zoneID: zoneID)
      })
      
      guard !isEmpty else {
        return nil
      }
    }
    
    var isEmpty: Bool {
      return recordsToSave.isEmpty && recordIDsToDelete.isEmpty
    }

    var count: Int {
      return recordsToSave.count + recordIDsToDelete.count
    }
  }

  func push(completionHandler: @escaping (_ error: Error?) -> Void) {
    queue.addOperation {
      os_log("pushing to iCloud", log: log, type: .debug)
      
      let status = self.reach()
      guard status == .reachable || status == .cellular else {
        return completionHandler(FeedKitError.offline)
      }
      
      self.checkAccount(assuming: self.accountStatus) { error in
        guard error == nil else {
          return completionHandler(error)
        }
        
        do {
          os_log("** removing stale previously queued", log: log, type: .debug)
          try self.cache.removeStalePrevious()
          
          let queued = try self.cache.locallyQueued()
          let dequeued = try self.cache.locallyDequeued()
          
          let a = Set(queued)
          let b = Set(dequeued)
          assert(a.intersection(b).isEmpty)
          
          // In this context, type is sufficient.
          let items = queued + dequeued

          // Discarding redundant metadata, already getting synced within
          // subscriptions.
          let optimized: [Queued] = try items.map {
            let url = $0.entryLocator.url
            guard try !self.cache.isSubscribed(url) else {
              return $0.dropITunes()
            }
            return $0
          }
          
          let locallySubscribed = try self.cache.locallySubscribed()
          let zombieRecords = try self.cache.zombieRecords()
          
          guard let m = UserClient.Modifications(
            queued: optimized,
            subscriptions: locallySubscribed,
            zombieRecords: zombieRecords
          ) else {
            os_log("everything up-to-date", log: log, type: .debug)
            return completionHandler(nil)
          }

          self.save(modifications: m, retrying: true) { error in
            completionHandler(error)
          }
        } catch {
          completionHandler(error)
        }
      }
    }
  }
  
  /// **Synchronously** probes iCloud reachability.
  private func reach() -> OlaStatus {
    return probe.reach()
  }

  /// After modifying the database under the radar—that’s how `pull` works—
  /// we must synchronize ephemeral user state manually. Somewhat out of scope,
  /// after reloading the queue to re-synchronize user state, we aren’t handling
  /// errors here, but just casually log them.
  private func synchronizeUserLibrary(completionBlock: (() -> Void)?) {
    Podest.userLibrary.synchronize { _, _, error in
      guard error == nil else {
        switch error! {
        case QueueingError.outOfSync:
          os_log("fetching queue: out of sync", log: log)

          Podest.userQueue.populate(entriesBlock: nil) { error in
            if let er = error {
              os_log("fetching queued failed: %@", log: log, er as CVarArg)
            } else {
              os_log("fetching queued succeeded", log: log, type: .debug)
            }

            completionBlock?()
          }
        default:
          completionBlock?()
        }
        return
      }

      completionBlock?()
    }
  }
  
  func pull(completionHandler:
    @escaping (_ newData: Bool, _ error: Error?) -> Void) {
    queue.addOperation {
      os_log("pulling from iCloud", log: log, type: .debug)
      
      let status = self.reach()
      guard status == .reachable || status == .cellular else {
        return completionHandler(false, FeedKitError.offline)
      }
      
      self.checkAccount(assuming: self.accountStatus) { error in
        guard error == nil else {
          return completionHandler(false, error)
        }
        
        func next() {
          self.fetchDatabaseChanges(retrying: true) { changed, deleted, error in
            guard error == nil else {
              return completionHandler(false, error)
            }

            let ours = deleted.filter { $0.zoneName != CKRecordZone.ID.defaultZoneName }
            if !ours.isEmpty {
              os_log("merging deleted zone identifiers", log: log)
            }

            // Fetching deleted zones too, except default zone: AppDefaultZone
            // does not support getChanges call. Not sure if fetching changes
            // for deleted zones still applies, since fetchDatabaseChanges is
            // already resetting local caches for deleted zones.

            let zoneIDs = Set(changed + ours)

            guard !zoneIDs.isEmpty else {
              os_log("already up-to-date", log: log, type: .info)
              return completionHandler(false, nil)
            }

            self.fetchZoneChanges(Array(zoneIDs), retrying: true) { error in
              self.synchronizeUserLibrary {
                // Reaching this block, `newData` is always `true`
                completionHandler(true, error)
              }
            }
          }
        }
        
        if !self.subscribed {
          self.subscribe { error in
            if let er = error {
              os_log("subscription failed: %{public}@", log: log, er as CVarArg)
            } else {
              os_log("subscribed to iCloud", log: log, type: .info)
            }
            next()
          }
        } else {
          next()
        }
      }
    }
  }
  
  func resetAccountStatus() {
    accountStatus = nil
  }
}

// MARK: - Storing and Accessing Change Tokens

fileprivate extension UserDefaults {

  fileprivate func setUUID(_ uuid: UUID, using key: String) {
    self.set(uuid.uuidString, forKey: key)
  }

  fileprivate func uuid(matching key: String) -> UUID? {
    guard let str = UserDefaults.standard.string(forKey: key) else {
      os_log("** UUID not found: %@", log: log, key)
      return nil
    }

    guard let uuid = UUID(uuidString: str) else {
      os_log("** decoding UUID failed: %@",log: log, key)
      return nil
    }

    return uuid
  }

  fileprivate func setServerChangeToken(
    _ token: CKServerChangeToken, using key: String) {
    let coder = NSKeyedArchiver(requiringSecureCoding: true)
    token.encode(with: coder)
    self.set(coder.encodedData, forKey: key)
  }

  fileprivate func serverChangeToken(
    matching key: String) -> CKServerChangeToken? {
    guard let data = UserDefaults.standard.object(forKey: key) as? Data else {
      os_log("** server change token not found: %@", log: log, key)
      return nil
    }

    do {
      let coder = try NSKeyedUnarchiver(forReadingFrom: data)
      coder.requiresSecureCoding = true
      return CKServerChangeToken(coder: coder)
    } catch {
      os_log("** decoding server change token failed: ( %@, %@ )",
             log: log, key, error as CVarArg)
      return nil
    }
  }

}

extension UserClient {

  private static func makeUUID(data: Data?) -> UUID? {
    guard let d = data, let str = String(data: d, encoding: .utf8) else {
      return nil
    }

    return UUID(uuidString: str)
  }

  /// Saves or removes change `token` for `key`, where `token` can be `UUID` or
  /// `CKServerChangeToken` locally. Pass `nil` to remove the change token for
  /// `key`.
  ///
  /// - Parameters:
  ///   - token: The change token to save or `nil` to remove said token.
  ///   - key: The key to associate the change token with.
  private static func save(token: Any?, for key: String) {
    switch token {
    case let t as CKServerChangeToken:
      os_log("saving server change token: ( %@, %@ )",
             log: log, type: .debug, t, key)
      UserDefaults.standard.setServerChangeToken(t, using: key)
    case let uuid as UUID:
      os_log("saving UUID: ( %@, %@ )",
             log: log, type: .debug, uuid as CVarArg, key)
      UserDefaults.standard.setUUID(uuid, using: key)
    case nil:
      os_log("** removing object: %@",
             log: log, type: .debug, key)
      UserDefaults.standard.removeObject(forKey: key)
    default:
      fatalError("invalid type for change token")
    }
  }

  private static func clientChangeToken(for key: String) -> UUID? {
    return UserDefaults.standard.uuid(matching: key)
  }

  private static func serverChangeToken(for key: String) -> CKServerChangeToken? {
    return UserDefaults.standard.serverChangeToken(matching: key)
  }
  
  private static func resetServerChangeToken(matching zoneID: CKRecordZone.ID) {
    save(token: nil, for: UserDB.ChangeTokenKey(zoneID: zoneID))
  }
  
  /// Resets local state, except database. **Only use for maintenance during
  /// development.**
  public func flush() {
    UserClient.save(token: nil, for: UserDB.privateCloudDatabaseChangeTokenKey)
    UserClient.save(token: nil, for: UserDB.privateClientChangeTokenKey)

    for zoneID in UserZoneID.all {
      UserClient.resetServerChangeToken(matching: zoneID)
    }
    
    self.subscribed = false
    
    resetAccountStatus()
  }

}

// MARK: - NOP

/// A user client that does nothing.
class NoUserClient: UserSyncing {

  var isAccountStatusKnown: Bool {
    os_log("claiming account status: no sync", log: log)
    return true
  }

  func pull(completionHandler: @escaping (
    _ newData: Bool, _ error: Error?) -> Void) {
    os_log("not pulling: no sync", log: log)
    completionHandler(false, nil)
  }

  func push(completionHandler: @escaping (_ error: Error?) -> Void) {
    os_log("not pushing: no sync", log: log)
    completionHandler(nil)
  }

  func resetAccountStatus() {
    os_log("not resetting account status: no sync", log: log)
  }

}


