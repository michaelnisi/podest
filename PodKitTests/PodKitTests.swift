//
//  PodKitTests.swift
//  PodKitTests
//
//  Created by Michael Nisi on 20.07.18.
//  Copyright © 2018 Michael Nisi. All rights reserved.
//

import XCTest
import StoreKit
@testable import PodKit

private extension StoreDelegate {
  func store(_ store: Shopping, offers products: [SKProduct], error: ShoppingError?) {}
  func store(_ store: Shopping, purchasing productIdentifier: String) {}
  func store(_ store: Shopping, purchased productIdentifier: String) {}
  func storeRestoring(_ store: Shopping) {}
  func storeRestored(_ store: Shopping, productIdentifiers: [String]) {}
  func store(_ store: Shopping, error: ShoppingError) {}
}

private extension Paying {
  func add(_ payment: SKPayment) {}
  func restoreCompletedTransactions() {}
  func finishTransaction(_ transaction: SKPaymentTransaction) {}
  func add(_ observer: SKPaymentTransactionObserver) {}
  func remove(_ observer: SKPaymentTransactionObserver) {}
}

private class TestPaymentQueue: Paying {}

class PodKitTests: XCTestCase {
  
  var store: StoreFSM!
  
  override func setUp() {
    super.setUp()

    let bundle = Bundle.init(identifier: "ink.codes.PodKitTests")!
    let url = bundle.url(forResource: "products", withExtension: "json")!

    store = StoreFSM(url: url, paymentQueue: TestPaymentQueue())
  }
  
  override func tearDown() {
    super.tearDown()
  }
  
  func testActivateWithoutSubscriptionDelegate() {
    let exp = expectation(description: "waiting")
    store.resume()
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
      XCTAssertEqual(self.store.state, .offline)
      exp.fulfill()
      
    }
    waitForExpectations(timeout: 5) { er in }
  }
  
  func testActivateWithSubscriptionDelegate() {
    let exp = expectation(description: "waiting")
    
    class MainController: StoreAccessDelegate {
      
      func reach() -> Bool {
        return true
      }
      
      var isAccessible = false
      
      func store(_ store: Shopping, isAccessible: Bool) {
        DispatchQueue.main.async {
          self.isAccessible = isAccessible
        }
      }
    }
    
    class StoreController: StoreDelegate {
      var products: [SKProduct]?
      func store(
        _ store: Shopping,
        offers products: [SKProduct],
        error: ShoppingError?
      ) {
        DispatchQueue.main.async {
          self.products = products
        }
      }
    }
    
    let subscriberDelegate = MainController()
    store.subscriberDelegate = subscriberDelegate
    
    let delegate = StoreController()
    store.delegate = delegate
    
    store.resume()
    
    DispatchQueue.main.asyncAfter(deadline: .now() + 1 / 10) {
      XCTAssertEqual(self.store.state, .fetchingProducts)
      
      let req = SKProductsRequest(productIdentifiers: Set([
        "ink.codes.podest.sponsor",
        "ink.codes.podest.help",
        "ink.codes.podest.love"
      ]))
      
      // Unfortunately, StoreKit lacks proper testability.
      let res = SKProductsResponse()
      
      self.store.productsRequest(req, didReceive: res)
      
      DispatchQueue.main.asyncAfter(deadline: .now() + 1 / 10) {
        XCTAssertEqual(self.store.state, .interested)
        XCTAssertEqual(delegate.products, [])
        XCTAssertTrue(subscriberDelegate.isAccessible)
        XCTAssertEqual(self.store.maxSubscriptionCount, 5)
        exp.fulfill()
      }
    }
    
    waitForExpectations(timeout: 5) { er in }
  }
  
}
