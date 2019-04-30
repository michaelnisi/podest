//
//  StoreTests.swift
//  PodKitTests
//
//  Created by Michael Nisi on 20.07.18.
//  Copyright © 2018 Michael Nisi. All rights reserved.
//

import XCTest
import StoreKit
@testable import PodKit

extension StoreDelegate {
  func store(_ store: Shopping, offers products: [SKProduct], error: ShoppingError?) {}
  func store(_ store: Shopping, purchasing productIdentifier: String) {}
  func store(_ store: Shopping, purchased productIdentifier: String) {}
  func storeRestoring(_ store: Shopping) {}
  func storeRestored(_ store: Shopping, productIdentifiers: [String]) {}
  func store(_ store: Shopping, error: ShoppingError) {}
}

extension Paying {
  func add(_ payment: SKPayment) {}
  func restoreCompletedTransactions() {}
  func finishTransaction(_ transaction: SKPaymentTransaction) {}
  func add(_ observer: SKPaymentTransactionObserver) {}
  func remove(_ observer: SKPaymentTransactionObserver) {}
}

private class TestPaymentQueue: Paying {}

class StoreTests: XCTestCase {
  
  class Accessor: StoreAccessDelegate {
    
    func reach() -> Bool {
      return true
    }
    
    var isAccessible = false
    
    func store(_ store: Shopping, isAccessible: Bool) {
      self.isAccessible = isAccessible
    }
    
    var isExpired = false
    
    func store(_ store: Shopping, isExpired: Bool) {
      self.isExpired = isExpired
    }
  }
  
  class StoreController: StoreDelegate {
    
    var products: [SKProduct]?
    
    func store(
      _ store: Shopping,
      offers products: [SKProduct],
      error: ShoppingError?
    ) {
      self.products = products
    }
  }
  
  var store: StoreFSM!
  var db: NSUbiquitousKeyValueStore!
  
  override func setUp() {
    super.setUp()

    let bundle = Bundle.init(for: StoreTests.self)
    let url = bundle.url(forResource: "products", withExtension: "json")!
    let v = BuildVersion(bundle: bundle)

    XCTAssertEqual(v.env, .simulator)

    let q = TestPaymentQueue()
    
    db = NSUbiquitousKeyValueStore()
    store = StoreFSM(url: url, paymentQueue: q, db: db, version: v)
    
    XCTAssertEqual(store.state, .initialized)
  }
  
  override func tearDown() {
    super.tearDown()
  }
  
  func testResuming() {
    let subscriberDelegate = Accessor()
    store.subscriberDelegate = subscriberDelegate
    let delegate = StoreController()
    store.delegate = delegate
    
    store.resume()
    
    let exp = expectation(description: "resuming")
    let q = DispatchQueue.main
    
    q.asyncAfter(deadline: .now() + .milliseconds(15)) {
      XCTAssertEqual(self.store.state, .fetchingProducts)
      q.asyncAfter(deadline: .now() + .milliseconds(15)) {
        let ids = Set(["abc", "def", "ghi"])
        let req = SKProductsRequest(productIdentifiers: ids)
        let res = SKProductsResponse()
        
        // The end, unfortunately I cannot mock a products response.
        
        self.store.productsRequest(req, didReceive: res)

        q.asyncAfter(deadline: .now() + .milliseconds(15)) {
          XCTAssertEqual(self.store.state, .interested(true))
          XCTAssertEqual(delegate.products, [])
          XCTAssertTrue(subscriberDelegate.isAccessible)
          XCTAssertFalse(subscriberDelegate.isExpired)
          exp.fulfill()
        }
      }
    }
    
    waitForExpectations(timeout: 5)
  }
  
  func testResumingWithoutDelegate() {
    let exp = expectation(description: "resuming")

    store.resume()
    
    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(15)) {
      XCTAssertEqual(self.store.state, .offline(true))
      exp.fulfill()
    }
    
    waitForExpectations(timeout: 5)
  }
}

// MARK: - Expiring

extension StoreTests {
  
  func testExpiredTrial() {
    db.set(Date.distantPast.timeIntervalSince1970, forKey: StoreFSM.unsealedKey)
    
    let subscriberDelegate = Accessor()
    store.subscriberDelegate = subscriberDelegate
    let delegate = StoreController()
    store.delegate = delegate
    let exp = expectation(description: "fetching products")
    
    store.resume()
    
    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(15)) {
      XCTAssertEqual(self.store.state, .fetchingProducts)
      
      let req = SKProductsRequest(productIdentifiers: Set())
      let res = SKProductsResponse()
      
      self.store.productsRequest(req, didReceive: res)
      
      DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(15)) {
        XCTAssertEqual(self.store.state, .interested(false))
        XCTAssertEqual(delegate.products, [])
        XCTAssertTrue(subscriberDelegate.isAccessible)
        
        XCTAssertFalse(
          subscriberDelegate.isExpired,
          "should not have been called yet"
        )
        
        XCTAssertTrue(self.store!.isExpired())
        
        DispatchQueue.main.async {
          XCTAssertTrue(
            subscriberDelegate.isExpired,
            "should be updated with isExpired method"
          )
          exp.fulfill()
        }
      }
    }
    
    waitForExpectations(timeout: 5) { er in }
  }
  
  func testMakeExpiration() {
    let zero = Date(timeIntervalSince1970: 0)
    let fixtures: [(Date, StoreFSM.Period, Date)] = [
      (zero, .always, zero),
      (zero, .subscription, zero.addingTimeInterval(3.154e7)),
      (zero, .trial, zero.addingTimeInterval(2.419e6))
    ]
    
    for (date, period, wanted) in fixtures {
      XCTAssertEqual(StoreFSM.makeExpiration(date: date, period: period), wanted)
    }
  }

  func testExpiration() {
    do {
      let expirations: [StoreFSM.Period] = [.trial, .subscription]

      for x in expirations {
        XCTAssertFalse(x.isExpired(date: Date.distantFuture))
        XCTAssertTrue(x.isExpired(date: Date.distantPast))
        XCTAssertFalse(x.isExpired(date: Date()))
      }
    }

    do {
      let always = StoreFSM.Period.always
      let dates = [Date(), Date.distantPast]

      for date in dates {
        XCTAssertTrue(always.isExpired(date: date))
      }

      XCTAssertFalse(always.isExpired(date: Date.distantFuture))
    }

    do {
      XCTAssertFalse(StoreFSM.Period.trial.isExpired(
        date: Date(timeIntervalSinceNow: -StoreFSM.Period.trial.rawValue + 1)))
      XCTAssertTrue(StoreFSM.Period.trial.isExpired(
        date: Date(timeIntervalSinceNow: -StoreFSM.Period.trial.rawValue)))

      XCTAssertFalse(StoreFSM.Period.subscription.isExpired(
        date: Date(timeIntervalSinceNow: -StoreFSM.Period.subscription.rawValue + 1)))
      XCTAssertTrue(StoreFSM.Period.subscription.isExpired(
        date: Date(timeIntervalSinceNow: -StoreFSM.Period.subscription.rawValue)))
    }
  }
}
