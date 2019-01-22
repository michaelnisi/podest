//
//  store.swift
//  Podest
//
//  Created by Michael Nisi on 13.04.18.
//  Copyright © 2018 Michael Nisi. All rights reserved.
//

import Foundation
import StoreKit

// MARK: - Dependencies

/// Trade representative contact information.
struct Contact: Decodable {
  let email: String
  let github: String
  let privacy: String
}

/// So we can use a different payment queue while testing.
protocol Paying {
  func add(_ payment: SKPayment)
  func restoreCompletedTransactions()
  func finishTransaction(_ transaction: SKPaymentTransaction)
  func add(_ observer: SKPaymentTransactionObserver)
  func remove(_ observer: SKPaymentTransactionObserver)
}

extension Paying {
  
  func add(_ payment: SKPayment) {
    SKPaymentQueue.default().add(payment)
  }
  
  func restoreCompletedTransactions() {
    SKPaymentQueue.default().restoreCompletedTransactions()
  }
  
  func finishTransaction(_ transaction: SKPaymentTransaction) {
    SKPaymentQueue.default().finishTransaction(transaction)
  }
  
  func add(_ observer: SKPaymentTransactionObserver) {
    SKPaymentQueue.default().add(observer)
  }
  
  func remove(_ observer: SKPaymentTransactionObserver) {
    SKPaymentQueue.default().remove(observer)
  }
  
}

protocol Storing {
  func set(_ aData: Data?, forKey aKey: String)
  func removeObject(forKey aKey: String)
  func data(forKey aKey: String) -> Data?
  
  /// The notification sender.
  var sender: Any { get }
}

extension Storing {
  
  func removeObject(forKey aKey: String) {
    NSUbiquitousKeyValueStore.default.removeObject(forKey: aKey)
  }
  
  func set(_ aData: Data?, forKey aKey: String) {
    NSUbiquitousKeyValueStore.default.set(aData, forKey: aKey)
  }
  
  func data(forKey aKey: String) -> Data? {
    return NSUbiquitousKeyValueStore.default.data(forKey: aKey)
  }
  
  var sender: Any {
    return NSUbiquitousKeyValueStore.default
  }
  
}

protocol NetworkActivityIndicating {
  func increase()
  func decrease()
  func reset()
}

extension NetworkActivityIndicating {
  func increase() {}
  func decrease() {}
  func reset() {}
}

// MARK: - API

/// Enumerates possible presentation layer error types, grouping StoreKit and
/// other errors into five simplified buckets.
enum ShoppingError: Error {
   case invalidProduct(String?)
   case offline
   case serviceUnavailable
   case cancelled
   case failed
   case notRestored
  
  init(underlyingError: Error, productIdentifier: String? = nil, restoring: Bool = false) {
    switch underlyingError {
    case let skError as SKError:
      switch skError.code {
      case .clientInvalid, .unknown, .paymentInvalid, .paymentNotAllowed:
        guard !restoring else {
          self = .notRestored
          return
        }
        self = .failed
        
      case .cloudServicePermissionDenied, .cloudServiceRevoked:
        self = .serviceUnavailable
        
      case .cloudServiceNetworkConnectionFailed:
        self = .offline
        
      case .paymentCancelled:
        self = .cancelled
        
      case .storeProductNotAvailable:
        self = .invalidProduct(productIdentifier)
      }
      
    default:
      let nsError = underlyingError as NSError
      
      let domain = nsError.domain
      let code = nsError.code
      
      switch  (domain, code) {
      case (NSURLErrorDomain, -1001), (NSURLErrorDomain, -1005):
        self = .serviceUnavailable
        
      default:
        self = .failed
      }
    }
  }

}

/// Get notified when accessiblity to the store changes.
protocol StoreAccessDelegate: class {
  func store(_ store: Shopping, isAccessible: Bool)
  
  /// The delegate is responsible for checking if the App Store is reachable.
  /// This method should return `true` if the App Store is reachable. If the
  /// App Store is not reachable, it should return `false` and begin probing
  /// reachability, so it can notify the store via `Shopping.online()` once the
  /// App Store can be reached again.
  func reach() -> Bool
}

/// Receive updates about products, purchasing, and restoring.
protocol StoreDelegate: class {
  
  func store(
    _ store: Shopping,
    offers products: [SKProduct],
    error: ShoppingError?
  )
  
  func store(_ store: Shopping, purchasing productIdentifier: String)
  
  func store(_ store: Shopping, purchased productIdentifier: String)
  
  func storeRestoring(_ store: Shopping)
  
  func storeRestored(_ store: Shopping, productIdentifiers: [String])
  
  func store(_ store: Shopping, error: ShoppingError)
  
}

/// A set of methods to offer in-app purchases.
protocol Shopping: SKPaymentTransactionObserver {
  
  /// The maximum number of allowed podcast subscriptions is only limited when
  /// we are sure about the status.
  var maxSubscriptionCount: Int { get }

  /// Clients use this delegate to receive callbacks from the store.
  var delegate: StoreDelegate? { get set }
  
  var subscriberDelegate: StoreAccessDelegate? { get set }
  
  /// Requests App Store for payment of the product matching `productIdentifier`.
  func payProduct(matching productIdentifier: String)

  var canMakePayments: Bool { get }
  
  /// Synchronizes pending transactions with the Apple App Store, observing the
  /// payment queue for transaction updates.
  ///
  /// StoreKit documenation suggests to do this during application
  /// initialization, providing no clues for when to remove the observer. So I
  /// guess, we just keep it around and never `deactivate()`, hoping this does
  /// not lead to problems while we are in the background.
  func activate()
  
  /// Deactivates the store, removing the observer from the payment queue.
  func deactivate()
  
  /// Restores previous purchases.
  func restore()
  
  /// Updates the store state.
  func update()
  
  /// Notifies the store that the App Store is reachable.
  func online()
  
}
