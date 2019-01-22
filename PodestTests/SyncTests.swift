//
//  SyncTests.swift
//  PodestTests
//
//  Created by Michael on 11/1/17.
//  Copyright © 2017 Michael Nisi. All rights reserved.
//

import XCTest
import CloudKit

@testable import FeedKit
@testable import Podest

class SyncTests: XCTestCase {}

// MARK: - Serializing Records

private func setITunes(record: CKRecord) -> (ITunesItem, CKRecord) {
  let iTunes = ITunesItem(
    url: "http://abc.de",
    iTunesID: 123,
    img100: "http://abc.de/img100",
    img30: "http://abc.de/img30",
    img60: "http://abc.de/img60",
    img600: "http://abc.de/img600"
  )
  
  record.setValue(iTunes.img100, forKey: "img100")
  record.setValue(iTunes.img30, forKey: "img30")
  record.setValue(iTunes.img60, forKey: "img60")
  record.setValue(iTunes.img600, forKey: "img600")
  record.setValue(iTunes.iTunesID, forKey: "iTunesID")
  
  return (iTunes, record)
}

extension SyncTests {

  func testSubtract() {
    do {
      let (renewed, obsolete) = UserClient.subtract([], from: [])
      XCTAssertEqual(renewed, [])
      XCTAssertEqual(obsolete, [])
    }

    let abc = EntryLocator(url: "http://abc.de", guid: "abc")
    let def = EntryLocator(url: "http://def.gh", guid: "def")
    let ghi = EntryLocator(url: "http://ghi.jk", guid: "ghi")

    let set: [Queued] = [
      .previous(abc, Date(timeIntervalSince1970: 3600)),
      .previous(def, Date(timeIntervalSince1970: 3000)),
      .previous(ghi, Date(timeIntervalSince1970: 2400))
    ]

    do {
      let current: [[Queued]] = [[], set]
      for c in current {
        let (renewed, obsolete) = UserClient.subtract(c, from: set)
        XCTAssertEqual(renewed, [])
        XCTAssertEqual(obsolete, [])
      }
    }

    let a = Queued.temporary(abc, Date(timeIntervalSince1970: 3000), nil)

    do {
      let (renewed, obsolete) = UserClient.subtract([a], from: set)
      XCTAssertEqual(renewed, [])
      XCTAssertEqual(obsolete, ["abc"])
    }

    let b = Queued.pinned(abc, Date(timeIntervalSince1970: 3000), nil)

    do {
      let (renewed, obsolete) = UserClient.subtract([a, b], from: set)
      XCTAssertEqual(renewed, [])
      XCTAssertEqual(obsolete, ["abc"])
    }

    let c = Queued.pinned(def, Date(timeIntervalSince1970: 2400), nil)

    do {
      let (renewed, obsolete) = UserClient.subtract([a, b, c], from: set)
      XCTAssertEqual(renewed, [])

      // Assuming ordering doesn’t matter.

      XCTAssertEqual(Set(obsolete), Set(["abc", "def"]))
    }
  }

}

extension SyncTests {
  
  func testSyncedFromRecords() {
    do {
      let types = [
        "Dog",
        UserRecordType.queued.rawValue,
        UserRecordType.subscription.rawValue
      ]
      for t in types {
        XCTAssertNil(UserClient.synced(from:
          CKRecord(recordType: t)))
      }
      
      for zoneID in UserZoneID.all {
        for t in types {
          let recordID = CKRecord.ID(zoneID: zoneID)
          let record = CKRecord(recordType: t, recordID: recordID)
          XCTAssertNil(UserClient.synced(from: record))
        }
      }
    }
  }
  
  func testSyncedFromQueuedRecord() {
    let url = "http://abc.de"
    let guid = "123"
    let ts = Date()
    let since = Date.init(timeIntervalSince1970: 0)
    let recordName = UUID().uuidString
    
    func makeQueuedRecord(zoneID: CKRecordZone.ID, owner: QueuedOwner = .nobody) -> CKRecord {
      let recordID = CKRecord.ID(recordName: recordName, zoneID: zoneID)
      let r = CKRecord(recordType: "Queued", recordID: recordID)
      r.setValue(url, forKey: "url")
      r.setValue(guid, forKey: "guid")
      r.setValue(ts, forKey: "ts")
      r.setValue(since, forKey: "since")
      r.setValue(owner.rawValue, forKey: "queuedOwner")
      return r
    }
    
    func isTemporary(_ synced: Synced?, zoneName: String, iTunes: ITunesItem? = nil) -> Bool {
      let loc = EntryLocator(url: url, since: since, guid: guid)
      let queued = Queued.temporary(loc, ts, nil)
      let rec = RecordMetadata(zoneName: zoneName, recordName: recordName)
      let wanted = Synced.queued(queued, rec)
      
      guard case Synced.queued(
        let foundQueued, let foundRec) = synced! else {
        fatalError()
      }
      
      XCTAssertEqual(foundQueued, queued)
      XCTAssertEqual(foundRec, rec)
      
      guard case Queued.temporary(
        let foundLoc, let foundTs, let foundITunes) = foundQueued else {
        fatalError()
      }
      
      XCTAssertEqual(foundTs, ts)
      XCTAssertEqual(foundLoc, loc)
      XCTAssertEqual(foundITunes, iTunes)
      
      return synced == wanted
    }
    
    func isPinned(_ synced: Synced?, zoneName: String, iTunes: ITunesItem? = nil) -> Bool {
      let loc = EntryLocator(url: url, since: since, guid: guid)
      let queued = Queued.pinned(loc, ts, nil)
      let rec = RecordMetadata(zoneName: zoneName, recordName: recordName)
      let wanted = Synced.queued(queued, rec)
      
      guard case Synced.queued(
        let foundQueued, let foundRec) = synced! else {
          fatalError()
      }
      
      XCTAssertEqual(foundQueued, queued)
      XCTAssertEqual(foundRec, rec)
      
      guard case Queued.pinned(
        let foundLoc, let foundTs, let foundITunes) = foundQueued else {
          fatalError()
      }
      
      XCTAssertEqual(foundTs, ts)
      XCTAssertEqual(foundLoc, loc)
      XCTAssertEqual(foundITunes, iTunes)
      
      return synced == wanted
    }
    
    func isPrevious(_ synced: Synced?, zoneName: String) -> Bool {
      let loc = EntryLocator(url: url, since: since, guid: guid)
      let queued = Queued.previous(loc, ts)
      let rec = RecordMetadata(zoneName: zoneName, recordName: recordName)
      let wanted = Synced.queued(queued, rec)
      
      guard case .queued(
        let foundQueued, let foundRec) = synced! else {
          fatalError()
      }
      
      XCTAssertEqual(foundQueued, queued)
      XCTAssertEqual(foundRec, rec)
      
      guard case .previous(let foundLoc, let foundTs) = foundQueued else {
        fatalError()
      }
      
      XCTAssertEqual(foundTs, ts)
      XCTAssertEqual(foundLoc, loc)
      
      return synced == wanted
    }
    
    do {
      let r = makeQueuedRecord(zoneID: UserDB.queueZoneID)
      let found = UserClient.synced(from: r)
      
      XCTAssert(isTemporary(found, zoneName: "queueZone"))
    }
    
    do {
      let base = makeQueuedRecord(zoneID: UserDB.queueZoneID)
      let (iTunes, r) = setITunes(record: base)
      let found = UserClient.synced(from: r)
      
      XCTAssert(isTemporary(found, zoneName: "queueZone", iTunes: iTunes))
    }
    
    do {
      let r = makeQueuedRecord(zoneID: UserDB.queueZoneID, owner: .user)
      let found = UserClient.synced(from: r)
      
      XCTAssert(isPinned(found, zoneName: "queueZone"))
    }
    
    do {
      let base = makeQueuedRecord(zoneID: UserDB.queueZoneID, owner: .user)
      let (iTunes, r) = setITunes(record: base)
      let found = UserClient.synced(from: r)
      
      XCTAssert(isPinned(found, zoneName: "queueZone", iTunes: iTunes))
    }
    
    do {
      let r = makeQueuedRecord(zoneID: UserDB.logZoneID)
      let found = UserClient.synced(from: r)
      
      XCTAssert(isPrevious(found, zoneName: "logZone"))
    }
    
    do {
      let base = makeQueuedRecord(zoneID: UserDB.logZoneID)
      let (_, r) = setITunes(record: base)
      let found = UserClient.synced(from: r)
      
      XCTAssert(isPrevious(found, zoneName: "logZone"))
    }
    
    do {
      let r = makeQueuedRecord(zoneID: UserDB.logZoneID, owner: .user)
      let found = UserClient.synced(from: r)
      
      XCTAssert(isPrevious(found, zoneName: "logZone"))
    }
    
    do {
      let base = makeQueuedRecord(zoneID: UserDB.logZoneID, owner: .user)
      let (_, r) = setITunes(record: base)
      let found = UserClient.synced(from: r)
      
      XCTAssert(isPrevious(found, zoneName: "logZone"))
    }
  }
  
  func testSyncedFromSubscriptionRecord() {
    let url = "http://abc.de"
    let guid = "123"
    let ts = Date()
    let since = Date.init(timeIntervalSince1970: 0)
    let recordName = UUID().uuidString
    
    func makeSubscriptionRecord() -> CKRecord {
      let zoneID = UserDB.libraryZoneID
      let recordID = CKRecord.ID(recordName: recordName, zoneID: zoneID)
      let r = CKRecord(recordType: "Subscription", recordID: recordID)
      r.setValue(url, forKey: "url")
      r.setValue(ts, forKey: "ts")
      return r
    }
    
    do {
      let record = makeSubscriptionRecord()
      let found = UserClient.synced(from: record)
      
      let s = Subscription(url: url)
      let r = RecordMetadata(zoneName: "libraryZone", recordName: recordName)
      let wanted = Synced.subscription(s, r)
      
      XCTAssertEqual(found, wanted)
    }
    
    do {
      let base = makeSubscriptionRecord()
      let (iTunes, record) = setITunes(record: base)
      let found = UserClient.synced(from: record)!
      
      let subscription = Subscription(url: url, ts: ts, iTunes: iTunes)
      let rec = RecordMetadata(zoneName: "libraryZone", recordName: recordName)
      let wanted = Synced.subscription(subscription, rec)
      
      XCTAssertEqual(found, wanted)
      
      switch found {
      case .subscription(let foundSubscription, let foundRec):
        XCTAssertEqual(foundSubscription.ts, ts)
        XCTAssertEqual(foundSubscription.iTunes, subscription.iTunes)
        XCTAssertEqual(foundRec, rec)
      default:
        XCTFail("should be subscription")
      }
    }
  }
  
  func testRecordFromQueued() {
    let url = "http://abc.de"
    let guid = "abc"
    let ts = Date()
    
    let loc = EntryLocator(url: url, since: nil, guid: guid, title: nil)
    
    let iTunes = ITunesItem(
      url: url,
      iTunesID: 123,
      img100: "http://abc.de/img100",
      img30: "http://abc.de/img30",
      img60: "http://abc.de/img60",
      img600: "http://abc.de/img600"
    )
    
    func hasITunes(_ record: CKRecord) -> Bool {
      assert(record.value(forKey: "img30") as! String == iTunes.img30)
      assert(record.value(forKey: "img60") as! String == iTunes.img60)
      assert(record.value(forKey: "img100") as! String == iTunes.img100)
      assert(record.value(forKey: "img600") as! String == iTunes.img600)
      assert(record.value(forKey: "iTunesID") as! Int == iTunes.iTunesID)
      return true
    }
    
    func hasNoITunes(_ record: CKRecord) -> Bool {
      for k in ["img30", "img60", "img100", "img600", "iTunesID"] {
        assert(record.value(forKey: k) == nil)
      }
      return true
    }
    
    func isInQueueZone(_ record: CKRecord) -> Bool {
      let zoneID = CKRecordZone.ID(
        zoneName: "queueZone",
        ownerName: CKCurrentUserDefaultName
      )
      return record.recordID.zoneID == zoneID
    }
    
    func isInLogZone(_ record: CKRecord) -> Bool {
      let zoneID = CKRecordZone.ID(
        zoneName: "logZone",
        ownerName: CKCurrentUserDefaultName
      )
      return record.recordID.zoneID == zoneID
    }
    
    func isTemporary(_ record: CKRecord) -> Bool {
      assert(record.value(forKey: "url") as! String == url)
      assert(record.value(forKey: "guid") as! String == guid)
      assert(record.value(forKey: "ts") as! Date == ts)
      assert(record.value(forKey: "since") as! Date == loc.since)
      assert(record.value(forKey: "queuedOwner") as! Int == 0)
      return true
    }
    
    func isPinned(_ record: CKRecord) -> Bool {
      assert(record.value(forKey: "url") as! String == url)
      assert(record.value(forKey: "guid") as! String == guid)
      assert(record.value(forKey: "ts") as! Date == ts)
      assert(record.value(forKey: "since") as! Date == loc.since)
      assert(record.value(forKey: "queuedOwner") as! Int == 1)
      return true
    }
    
    func isQueued(_ record: CKRecord, queued: Queued) -> Bool {
      guard case .queued(let q, let r) = UserClient.synced(from: record)! else {
        fatalError()
      }
      assert(q == queued)
      assert(r.zoneName == "queueZone")
      return true
    }
    
    func isPrevious(_ record: CKRecord, queued: Queued) -> Bool {
      guard case .queued(let q, let r) = UserClient.synced(from: record)! else {
        fatalError()
      }
      assert(q == queued)
      assert(r.zoneName == "logZone")
      return true
    }
    
    do {
      let queued = Queued.temporary(loc, ts, nil)
      let found = UserClient.record(from: queued)
      
      XCTAssert(isInQueueZone(found))
      XCTAssert(isTemporary(found))
      XCTAssert(hasNoITunes(found))
      XCTAssert(isQueued(found, queued: queued))
    }
    
    do {
      let queued = Queued.temporary(loc, ts, iTunes)
      let found = UserClient.record(from: queued)
      
      XCTAssert(isInQueueZone(found))
      XCTAssert(isTemporary(found))
      XCTAssert(hasITunes(found))
      XCTAssert(isQueued(found, queued: queued))
    }
    
    do {
      let queued = Queued.pinned(loc, ts, nil)
      let found = UserClient.record(from: queued)
      
      XCTAssert(isInQueueZone(found))
      XCTAssert(isPinned(found))
      XCTAssert(hasNoITunes(found))
      XCTAssert(isQueued(found, queued: queued))
    }
    
    do {
      let queued = Queued.pinned(loc, ts, iTunes)
      let found = UserClient.record(from: queued)
      
      XCTAssert(isInQueueZone(found))
      XCTAssert(isPinned(found))
      XCTAssert(hasITunes(found))
      XCTAssert(isQueued(found, queued: queued))
    }
    
    do {
      let queued = Queued.previous(loc, ts)
      let found = UserClient.record(from: queued)
      
      XCTAssert(isInLogZone(found))
      XCTAssert(isTemporary(found))
      XCTAssert(hasNoITunes(found))
      XCTAssert(isPrevious(found, queued: queued))
    }
  }
  
  func testRecordFromSubscription() {
    let url = "http://abc.de"
    
    do {
      let subscription = Subscription(url: url)
      
      let found = UserClient.record(from: subscription)
      let zoneID = CKRecordZone.ID(
        zoneName: "libraryZone", ownerName: CKCurrentUserDefaultName)
      XCTAssertEqual(found.recordID.zoneID, zoneID)
      
      XCTAssertEqual(found.value(forKey: "url") as! String, url)
      
      for k in ["img100", "img30", "img60", "img600", "iTunedID"] {
        XCTAssertNil(found.value(forKey: k))
      }
    }
    
    do {
      let iTunes = ITunesItem(
        url: url,
        iTunesID: 123,
        img100: "http://abc.de/img100",
        img30: "http://abc.de/img30",
        img60: "http://abc.de/img60",
        img600: "http://abc.de/img600"
      )
      let ts = Date()
      let subscription = Subscription(url: url, ts: ts, iTunes: iTunes)
      
      let found = UserClient.record(from: subscription)
      let zoneID = CKRecordZone.ID(
        zoneName: "libraryZone", ownerName: CKCurrentUserDefaultName)
      XCTAssertEqual(found.recordID.zoneID, zoneID)
      
      XCTAssertEqual(found.value(forKey: "url") as! String, url)
      
      XCTAssertEqual(found.value(forKey: "ts") as! Date, ts)
      XCTAssertEqual(found.value(forKey: "img100") as! String, iTunes.img100)
      XCTAssertEqual(found.value(forKey: "img30") as! String, iTunes.img30)
      XCTAssertEqual(found.value(forKey: "img60") as! String, iTunes.img60)
      XCTAssertEqual(found.value(forKey: "img600") as! String, iTunes.img600)
      XCTAssertEqual(found.value(forKey: "iTunesID") as! Int, iTunes.iTunesID)
    }
    
  }
  
}
