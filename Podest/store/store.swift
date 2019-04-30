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

/// Plain Strings to identify products for flexibility.
typealias ProductIdentifier = String

/// A locally known product, stored in the local JSON file `products.json`.
struct LocalProduct: Codable {
  let productIdentifier: ProductIdentifier
}

/// A receipt for a product purchase stored in iCloud.
struct PodestReceipt: Codable {
  let productIdentifier: String
  let transactionIdentifier: String
  let transactionDate: Date

  init?(transaction: SKPaymentTransaction) {
    guard
      let transactionIdentifier = transaction.transactionIdentifier,
      let transactionDate = transaction.transactionDate else {
      return nil
    }
    self.productIdentifier = transaction.payment.productIdentifier
    self.transactionIdentifier = transactionIdentifier
    self.transactionDate = transactionDate
  }

  init(
    productIdentifier: String,
    transactionIdentifier: String,
    transactionDate: Date
    ) {
    self.productIdentifier = productIdentifier
    self.transactionIdentifier = transactionIdentifier
    self.transactionDate = transactionDate
  }

}

/// Trade representative contact information.
struct Contact: Decodable {
  let email: String
  let github: String
  let privacy: String
  let review: String
}

/// The payment queue proxy allows swapping out the queue for testing.
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

// MARK: - API

/// Enumerates possible presentation layer error types, grouping StoreKit and
/// other errors into five simplified buckets.
enum ShoppingError: Error {
  case invalidProduct(String?)
  case offline
  case serviceUnavailable
  case cancelled
  case failed

  init(underlyingError: Error, productIdentifier: String? = nil, restoring: Bool = false) {
    switch underlyingError {
    case let skError as SKError:
      switch skError.code {
      case .clientInvalid,
           .unknown,
           .paymentInvalid,
           .paymentNotAllowed,
           .privacyAcknowledgementRequired,
           .unauthorizedRequestData:
        self = .failed
        
      case .cloudServicePermissionDenied,
           .cloudServiceRevoked:
        self = .serviceUnavailable
        
      case .cloudServiceNetworkConnectionFailed:
        self = .offline
        
      case .paymentCancelled:
        self = .cancelled
        
      case .storeProductNotAvailable,
           .invalidOfferIdentifier,
           .invalidOfferPrice,
           .missingOfferParams,
           .invalidSignature:
        self = .invalidProduct(productIdentifier)
        
      @unknown default:
        fatalError("unknown case in switch: \(skError.code)")
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

  /// Pinged if the store should be shown or hidden.
  func store(_ store: Shopping, isAccessible: Bool)
  
  /// The delegate is responsible for checking if the App Store is reachable.
  /// This method should return `true` if the App Store is reachable. If the
  /// App Store is not reachable, it should return `false` and begin probing
  /// reachability, so it can notify the store via `Shopping.online()` once the
  /// App Store can be reached again.
  func reach() -> Bool

  /// Receives expiration updates.
  func store(_ store: Shopping, isExpired: Bool)

}

/// Receives shopping events.
protocol StoreDelegate: class {

  /// After fetching available IAPs, this callback receives products or error.
  func store(
    _ store: Shopping,
    offers products: [SKProduct],
    error: ShoppingError?
  )

  /// The identifier of the product currently being purchased.
  func store(_ store: Shopping, purchasing productIdentifier: String)

  /// The identifier of a successfully purchased product.
  func store(_ store: Shopping, purchased productIdentifier: String)

  /// Display an error message after this callback.
  func store(_ store: Shopping, error: ShoppingError)
  
}

/// Ask users for rating and reviews.
protocol Rating {

  /// Requests user to rate the app if appropriate.
  func requestReview()

  /// Cancels previous review request, `resetting` the cycle to defer the next.
  ///
  /// For example, just after becoming active again is probably not a good time
  /// to ask for a rating. Prevent this by `resetting` before going into the
  /// background.
  func cancelReview(resetting: Bool)

  /// Cancels previous review request.
  func cancelReview()

}

/// Checking user status.
protocol Expiring {

  /// Returns `true` if the trial period has been exceeded, `false` is returned
  /// within the trial period or if a valid subscription receipt is present.
  ///
  /// Might modify internal state or call delegates.
  func isExpired() -> Bool

}

/// A set of methods to offer in-app purchases.
protocol Shopping: SKPaymentTransactionObserver, Rating, Expiring {

  /// Clients use this delegate to receive callbacks from the store.
  var delegate: StoreDelegate? { get set }

  /// The store isn’t always accessible. The subscriber delegate get notified
  /// about that.
  var subscriberDelegate: StoreAccessDelegate? { get set }
  
  /// Requests App Store for payment of the product matching `productIdentifier`.
  func payProduct(matching productIdentifier: String)

  /// Is `true` if users can make payments.
  var canMakePayments: Bool { get }
  
  /// Synchronizes pending transactions with the Apple App Store, observing the
  /// payment queue for transaction updates.
  ///
  /// There’s no use case for `pause`.
  func resume()
  
  /// Updates the store state.
  func update()
  
  /// Notifies the store that the App Store is reachable.
  func online()
  
}

