//
//  StoreFSM.swift
//  Podest
//
//  Created by Michael Nisi on 21.04.18.
//  Copyright © 2018 Michael Nisi. All rights reserved.
//

import UIKit
import StoreKit
import os.log

private let log = OSLog(subsystem: "ink.codes.podest", category: "store")

/// A locally known product, stored in the local JSON file `products.json`.
struct LocalProduct: Codable {
  let productIdentifier: String
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

/// Plain Strings to identify products for flexibility.
typealias ProductIdentifier = String

/// Enumerates known product identifiers.
private enum KnownProductIdentifier {
  case help(ProductIdentifier)
  case love(ProductIdentifier)
  case sponsor(ProductIdentifier)

  init?(string: String) {
    switch string {
    case "ink.codes.podest.help":
      self = .help(string)
    case "ink.codes.podest.love":
      self = .love(string)
    case "ink.codes:podest.sponsor":
      self = .sponsor(string)
    default:
      return nil
    }
  }
}

/// Possible events handled by this store. For easier usage delegate changes
/// are events too.
private enum StoreEvent {
  case activate
  case failed(ShoppingError)
  case online
  case pay(ProductIdentifier)
  case productsReceived([SKProduct], ShoppingError?)
  case purchased(ProductIdentifier)
  case purchasing(ProductIdentifier)
  case receiptsChanged
  case restore
  case restored
  case update
}

extension StoreEvent: CustomStringConvertible {
  
  var description: String {
    switch self {
    case .activate:
      return "StoreEvent: activate"
    case .failed(let error):
      return "StoreEvent: failed: \(error)"
    case .online:
      return "StoreEvent: online"
    case .pay(let productIdentifier):
      return "StoreEvent: pay: \(productIdentifier)"
    case .productsReceived(let products, let error):
      return """
      StoreEvent: productsReceived: (
        products: \(products),
        error: \(error.debugDescription)
      )
      """
    case .purchased(let productIdentifier):
      return "StoreEvent: purchased: \(productIdentifier)"
    case .purchasing(let productIdentifier):
      return "StoreEvent: purchasing: \(productIdentifier)"
    case .receiptsChanged:
      return "StoreEvent: receiptsChanged"
    case .restore:
      return "StoreEvent: restore"
    case .restored:
      return "StoreEvent: restored"
    case .update:
      return "StoreEvent: update"
    }
  }
  
}

/// Enumerates possible states of the finite state machine (FSM), implementing
/// our in-app store, with following states.
///
/// - initialized
/// - interested
/// - subscribed
/// - fetchingProducts
/// - offline
/// - purchasing
/// - restoring
///
/// The specifics of each state are described inline.
enum StoreState: Equatable {
  
  /// The store starts passively in `initialized` awaiting activation.
  ///
  /// ## activate
  ///
  /// Begins observing payment queue for changed transactions and ubiquitous
  /// key value store for changed receipts. Fetches available products from the
  /// App Store and validates receipts, ideally resulting in one of the two
  /// user states, `interested` or `subscribed`. Of course, we might as well
  /// end up being `offline`, not only if the App Store is not reachable, but
  /// also if the subscriber delegate has not been set yet.
  case initialized
  
  /// No valid receipts have been found. Meaning, no subscription has been
  /// purchased yet, subscriptions are expired, or receipts have been deleted.
  ///
  /// ## receiptsChanged
  /// Validates receipts, resulting in `interested` or `subscribed`.
  ///
  /// ## purchased
  /// Validates receipts, very likely transferring to `subscribed`.
  ///
  /// ## purchasing
  /// Moving to `purchasing`.
  ///
  /// ## failed
  /// Processes error ending up `offline` or `interested`.
  ///
  /// ## pay
  /// Adds payment to queue entering `purchasing`.
  ///
  /// ## restore
  /// Requests restoring of completed transactions entering `restoring`.
  ///
  /// ## update
  /// Fetches products from App Store and validates receipts entering one of the
  /// three elemental states, `interested`, `subscribed`, or `offline`.
  case interested
  
  /// In `subscribed` state the store currently doesn’t handle any events, the
  /// user is a customer, has purchased a subscription. Ignores all events and
  /// stays `subscribed`.
  case subscribed(ProductIdentifier)
  
  /// Fetching products from the App Store.
  ///
  /// ## productsReceived([SKProduct], ShoppingError?)
  /// The product list has been received from the payment queue and the
  /// products will be forwarded to the shopping delegate for display.
  ///
  /// ## receiptsChanged
  /// We might receive receipts from `NSUbiquitousKeyValueStore` in the mean
  /// time. In that case we keep waiting for the products. After they have been
  /// received, receipts always get validated, error or not.
  ///
  /// ## update
  /// The `update` event is ignored, we keep `fetchingProducts`.
  ///
  /// ## online
  /// Keep waiting in  to receive the products with `productsReceived`, which
  /// is probably the next event.
  case fetchingProducts
  
  /// Cannot reach the App Store.
  ///
  /// ## online | receiptsChanged | update
  /// Releases probe and updates products, after validating receipts transfers
  /// to `interested` or `subscribed`. A `receiptsChanged` is unlikely here,
  /// but produces the same result.
  case offline
  
  /// The user is purchasing a subscription.
  ///
  /// ## purchased
  /// Validates receipts resulting in `interested` or `subscribed`.
  ///
  /// ## failed
  /// Processes error ending up `offline`, `interested`, `subscribed`.
  ///
  /// ## purchasing | receiptsChanged | update
  /// These events are ignored staying in `purchasing`.
  indirect case purchasing(ProductIdentifier, StoreState)
  
  /// The user is trying to restore previous purchases.
  ///
  /// ## failed
  /// Processes error ending up `offline` or `interested`
  ///
  /// ## restored
  /// Validates receipts resulting in `interested` or `subscribed`.
  ///
  /// ## update | receiptsChanged
  /// Does nothing awaiting completion of restoring.
  indirect case restoring(StoreState)
}

extension StoreState: CustomStringConvertible {

  var description: String {
    switch self {
    case .initialized:
      return "StoreState: initialized"
    case .interested:
      return "StoreState: interested"
    case .subscribed(let pid):
      return "StoreState: subscribed: ( productIdentifier: \(pid) )"
    case .fetchingProducts:
      return "StoreState: fetchingProducts"
    case .offline:
      return "StoreState: offline"
    case .restoring(let nextState):
      return "StoreState: restoring: ( nextState: \(nextState) )"
    case .purchasing(let pid, let nextState):
      return """
      StoreState: purchasing (
        productIdentifier: \(pid),
        nextState: \(nextState)
      )
      """
    }
  }

}

// Some default implementations to isolate store.swift and StoreFSM.swift.

private class DefaultPaymentQueue: Paying {}
private class DefaultKVStore: Storing {}
private class DefaultNetworkActivityIndicator: NetworkActivityIndicating {}

/// StoreFSM is a store for in-app purchases, offering a single non-renewing
/// subscription at three flexible prices. After a successful purchase the store
/// is not available any longer. The store returns after one year, when this
/// subscription expires.
class StoreFSM: NSObject {

  /// The file URL of where to find the product identifiers.
  private let url: URL

  /// The maximum age of cached products should be kept relatively short, not
  /// existing products cannot be sold. However, products don’t change often.
  private let ttl: TimeInterval
  
  /// A queue of payment transactions to be processed by the App Store.
  private let paymentQueue: Paying
  
  /// A central key-value store for receipts.
  private let store: Storing
  
  /// Means to indicate network activity.
  private let indicator: NetworkActivityIndicating

  /// Creates a new store with minimal dependencies. **Protocol dependencies**
  /// for easier testing.
  ///
  /// - Parameters:
  ///   - url: The file URL of a JSON file containing product identifiers.
  ///   - ttl: The maximum age, 10 minutes, of cached products in seconds.
  ///   - paymentQueue: The App Store payment queue.
  ///   - store: The ubiquitous key-value store.
  ///   - indicator: The network activity indicator.
  init(
    url: URL,
    ttl: TimeInterval = 600,
    paymentQueue: Paying = DefaultPaymentQueue(),
    store: Storing = DefaultKVStore(),
    indicator: NetworkActivityIndicating = DefaultNetworkActivityIndicator()
  ) {
    self.url = url
    self.ttl = ttl
    self.paymentQueue = paymentQueue
    self.store = store
    self.indicator = indicator
  }
  
  /// Flag for asserts, `true` if we are observing the payment queue.
  private var isObserving = false
  
  private var count = 0
  
  /// The currently available products.
  private (set) var products: [SKProduct]?

  weak var delegate: StoreDelegate?
  
  weak var subscriberDelegate: StoreAccessDelegate?
  
  // MARK: Reachability

  /// Returns `true` if the App Store at `host` is reachable or else installs
  /// a callback and returns `falls`. This method uses `Ola` for reachability
  /// checking. Set `host` to `localhost` during testing—that should be fine.
  /// Replacing this with a block would be better:
  /// (
  private func isReachable() -> Bool {
    return subscriberDelegate?.reach() ?? false
  }

  // MARK: - Products and Identifiers

  /// Returns the first product matching `identifier`.
  private func product(matching identifier: ProductIdentifier) -> SKProduct? {
    return products?.first { $0.productIdentifier == identifier }
  }

  /// The current products request.
  var request: SKProductsRequest?

  private var _productIdentifiers: Set<String>?

  /// Product identifiers of, locally known, available products. If necessary,
  /// loaded from a configuration file.
  private var productIdentifiers: Set<String> {
    if let pids = _productIdentifiers {
      return pids
    }
    
    dispatchPrecondition(condition: .notOnQueue(.main))

    do {
      os_log("loading product identifiers", log: log, type: .debug)
      let json = try Data(contentsOf: url)
      let localProducts = try JSONDecoder().decode(
        [LocalProduct].self, from: json
      )
      _productIdentifiers = Set(localProducts.map { $0.productIdentifier })
      os_log("product identifiers: %@", log: log, type: .debug,
             _productIdentifiers!)
      return _productIdentifiers!
    } catch {
      os_log("no product identifiers", log: log, type: .error)
      return []
    }
  }

  private func fetchProducts() {
    os_log("fetching products", log: log, type: .debug)
    request?.cancel()
    
    indicator.increase()
    
    let req = SKProductsRequest(productIdentifiers: self.productIdentifiers)
    req.delegate = self
    req.start()
    
    request = req
  }

  private func updateProducts() -> StoreState {
    if isReachable() {
      fetchProducts()
      return .fetchingProducts
    } else {
      delegateQueue.async {
        self.delegate?.store(self, offers: [], error: .offline)
      }
      return .offline
    }
  }

  // MARK: Saving and Loading Receipts
  
  public func removeReceipts() {
    os_log("removing receipts", log: log)
    store.removeObject(forKey: "receipts")
  }

  private func loadReceipts() -> [PodestReceipt] {
    os_log("loading receipts", log: log, type: .debug)
    
    dispatchPrecondition(condition: .notOnQueue(.main))

    guard let json = store.data(forKey: "receipts") else {
      os_log("no receipts: creating container", log: log, type: .debug)
      return []
    }
    
    do {
      return try JSONDecoder().decode([PodestReceipt].self, from: json)
    } catch {
      removeReceipts()
      return []
    }
  }

  private func saveReceipt(_ receipt: PodestReceipt) {
    os_log("saving receipt: %@", log: log, type: .debug,
           String(describing: receipt))

    let acc = loadReceipts() + [receipt]
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    let data = try! encoder.encode(acc)
    store.set(data, forKey: "receipts")

    let str = String(data: data, encoding: .utf8)!
    os_log("saved: %@", log: log, type: .debug, str)
  }

  /// Our non-renewing in-app purchase subscription duration.
  private enum SubscriptionDuration: Double {
    typealias RawValue = Double

    /// The development subscription duration is one hour in seconds.
    case development = -3600 // -86400 or one day maybe

    /// The production subscription duration is one year in seconds.
    case production = -31536e3
  }
  
  /// Returns the product identifier of the first valid subscription found in
  /// `receipts` or `nil` if a matching product identifier could not be found
  /// or, respectively, all matching transactions are older than one year, the
  /// duration of our subscriptions.
  static func validProductIdentifier(
    _ receipts: [PodestReceipt],
    matching productIdentifiers: Set<ProductIdentifier>
  ) -> ProductIdentifier? {
    for r in receipts {
      let id = r.productIdentifier

      let duration = SubscriptionDuration.production.rawValue
      guard productIdentifiers.contains(id),
        r.transactionDate.timeIntervalSinceNow > duration else {
        continue
      }
      
      return id
    }
    
    return nil
  }

  private func validateReceipts() -> StoreState {
    let receipts = loadReceipts()
    
    os_log("validating receipts: %@", log: log, type: .debug,
           String(describing: receipts))
    
    guard let id = StoreFSM.validProductIdentifier(
      receipts, matching: productIdentifiers) else {
      return .interested
    }
    
    return .subscribed(id)
  }

  // MARK: Handling Events and Managing State

  /// An internal serial queue for synchronized access.
  private let sQueue = DispatchQueue(label: "ink.codes.podest.store.serial")

  private (set) var state: StoreState = .initialized {
    didSet {
      guard state != oldValue else {
        os_log("** warning: corresponding %{public}@", log: log, state.description)
        return
      }
      
      os_log("new state: %{public}@, old state: %{public}@",
             log: log, type: .debug,
             state.description, oldValue.description
      )
    }
  }

  // Calling the delegate on a distinct system queue for keeping things
  // serially in order.
  private var delegateQueue = DispatchQueue.global()

  private func updatedState(
    after error: ShoppingError,
    next nextState: StoreState
  ) -> StoreState {
    let er: ShoppingError = isReachable() ? error : .offline
    
    delegateQueue.async {
      self.delegate?.store(self, error: er)
    }
    
    if case .offline = er {
      return .offline
    }

    return nextState
  }
  
  private var isAccessible: Bool = false {
    didSet {
      guard isAccessible != oldValue else {
        return
      }
      delegateQueue.async {
        self.subscriberDelegate?.store(self, isAccessible: self.isAccessible)
      }
    }
  }
  
  /// Updates `isAccessible` matching `state`.
  private func updateIsAccessible(matching state: StoreState) -> StoreState {
    switch state {
    case .subscribed:
      isAccessible = false
    case .interested:
      isAccessible = true
    default:
      break
    }
    
    return state
  }
  
  private func addPayment(matching productIdentifier: ProductIdentifier) -> StoreState {
    guard let p = product(matching: productIdentifier) else {
      delegateQueue.async {
        self.delegate?.store(self, error: .invalidProduct(productIdentifier))
      }
      return state
    }
    
    let payment = SKPayment(product: p)
    indicator.increase()
    paymentQueue.add(payment)
    
    return .purchasing(productIdentifier, state)
  }
  
  private func restoreCompletedTransactions() -> StoreState {
    delegate?.storeRestoring(self)
    
    indicator.increase()
    paymentQueue.restoreCompletedTransactions()
    
    return .restoring(state)
  }
  
  private var didChangeExternallyObserver: NSObjectProtocol?
  
  private func observeUbiquitousKeyValueStore() {
    precondition(didChangeExternallyObserver == nil)
    
    didChangeExternallyObserver = NotificationCenter.default.addObserver(
      forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
      object: store.sender,
      queue: .main
    ) { notification in
      guard let info = notification.userInfo,
        let reason = info[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int else {
        return
      }
      
      switch reason {
      case NSUbiquitousKeyValueStoreAccountChange:
        os_log("push received: account change",
               log: log, type: .info)
        DispatchQueue.global().async {
          self.event(.receiptsChanged)
        }
      case NSUbiquitousKeyValueStoreInitialSyncChange,
           NSUbiquitousKeyValueStoreServerChange:
        guard
          let keys = info[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String],
          keys.contains("receipts") else {
          break
        }
        os_log("push received: initial sync | server change",
               log: log, type: .info)
        DispatchQueue.global().async {
          self.event(.receiptsChanged)
        }
      case NSUbiquitousKeyValueStoreQuotaViolationChange:
        os_log("push received: quota violation", log: log)
        break
      default:
        break
      }
    }
  }
  
  private func stopObservingUbiquitousKeyValueStore() {
    guard let observer = didChangeExternallyObserver else {
      return
    }
    NotificationCenter.default.removeObserver(observer)
  }
  
  /// Returns the new store state after processing `event` relatively to the
  /// current state. `interested` and `subscribed` are the two main antagonistic
  /// states this finite state machine can be in. Its other states are
  /// transitional.
  ///
  /// This strict FSM traps on unexpected events. Assuming synchronized access
  /// allows transitional states to focus on specific events, for we will be in
  /// the next state before a new event arrives. Some redundant events are
  /// explicitly ignored.
  ///
  /// - Parameter event: The event to handle.
  ///
  /// - Returns: The state resulting from the event.
  private func updatedState(after event: StoreEvent) -> StoreState {
    dispatchPrecondition(condition: .onQueue(sQueue))
    
    switch state {

    // MARK: initialized

    case .initialized:
      switch event {
      case .activate:
        os_log("adding observers to payment queue and kv-store",
               log: log, type: .debug)
        
        precondition(!isObserving, "already observing")
        
        paymentQueue.add(self)
        observeUbiquitousKeyValueStore()
        
        isObserving = true
        
        return updateProducts()

      default:
        fatalError("unhandled event")
      }

    // MARK: fetchingProducts

    case .fetchingProducts:
      switch event {
      case .productsReceived(let products, let error):
        self.products = products

        delegateQueue.async {
          self.delegate?.store(self, offers: products, error: error)
        }
        
        return updateIsAccessible(matching: validateReceipts())
      
      case .receiptsChanged, .update, .online:
        return state
        
      default:
        fatalError("unhandled event")
      }

    // MARK: offline

    case .offline:
      switch event {
      case .online, .receiptsChanged, .update:
        return updateProducts()
        
      default:
        fatalError("unhandled event")
      }
      
    // MARK: interested

    case .interested:
      switch event {
      case .receiptsChanged:
        return updateIsAccessible(matching: validateReceipts())

      case .purchased(let pid):
        delegateQueue.async {
          self.delegate?.store(self, purchased: pid)
        }
        return updateIsAccessible(matching: validateReceipts())

      case .purchasing(let pid):
        delegateQueue.async {
          self.delegate?.store(self, purchasing: pid)
        }
        return .purchasing(pid, state)

      case .failed(let error):
        return updatedState(after: error, next: .interested)

      case .pay(let pid):
        delegateQueue.async {
          self.delegate?.store(self, purchasing: pid)
        }
        return addPayment(matching: pid)
      
      case .restore:
        return restoreCompletedTransactions()
        
      case .update:
        return updateProducts()
        
      default:
        fatalError("unhandled event")
      }

    // MARK: subscribed

    case .subscribed:
      return state

    // MARK: purchasing

    case .purchasing(let current, let nextState):
      switch event {
      case .purchased(let pid):
        if current != pid {
          os_log("mismatching products: ( %@, %@ )",
                 log: log, current, pid)
        }
        delegateQueue.async {
          self.delegate?.store(self, purchased: pid)
        }
        return updateIsAccessible(matching: validateReceipts())
        
      case .failed(let error):
        return updatedState(after: error, next: nextState)
        
      case .purchasing(let pid), .pay(let pid):
        if current != pid {
          os_log("parallel purchasing: ( %@, %@ )",
                 log: log, current, pid)
        }
        return state
      
      case .receiptsChanged, .update:
        return state

      default:
        fatalError("unhandled event")
      }
      
    // MARK: restoring
      
    case .restoring(let nextState):
      switch event {
      case .failed(let error):
        return updatedState(after: error, next: nextState)
      
      case .restored:
        let validated = validateReceipts()
        
        let pids: [ProductIdentifier] = {
          if case .subscribed(let pid) = validated {
            return [pid]
          }
          return []
        }()
        
        delegateQueue.async {
          self.delegate?.storeRestored(self, productIdentifiers: pids)
        }
        
        return updateIsAccessible(matching: validated)
        
      case .receiptsChanged, .update:
        return state
        
      default:
        fatalError("unhandled event")
      }
    }
  }

  /// Synchronously handles event using `sQueue`, our event queue. Obviously,
  /// a store with one cashier works sequencially.
  ///
  /// **Do not block external users!**
  private func event(_ e: StoreEvent) {
    sQueue.sync {
      os_log("handling event: %{public}@", log: log, type: .debug,
             e.description)
      state = updatedState(after: e)
    }
  }

}

// MARK: - SKProductsRequestDelegate

extension StoreFSM: SKProductsRequestDelegate {

  func productsRequest(
    _ request: SKProductsRequest,
    didReceive response: SKProductsResponse
  ) {
    os_log("response received: %@", log: log, type: .debug, response)

    DispatchQueue.main.async {
      self.indicator.decrease()
      self.request = nil
    }

    DispatchQueue.global().async {
      let error: ShoppingError? = {
        let invalidIDs = response.invalidProductIdentifiers
        guard invalidIDs.isEmpty else {
          os_log("invalid product identifiers: %@",
                 log: log, type: .error, invalidIDs)
          return .invalidProduct(invalidIDs.first!)
        }
        return nil
      }()

      let products = response.products

      self.event(.productsReceived(products, error))
    }

  }

}

// MARK: - SKPaymentTransactionObserver

extension StoreFSM: SKPaymentTransactionObserver {

  private func finish(transaction t: SKPaymentTransaction) {
    os_log("finishing: %@", log: log, type: .debug, t)
    paymentQueue.finishTransaction(t)
    
    // Very fuzzy, but the most central place I could find. Maybe network
    // activity should not be indicated while purchasing at all.
    indicator.decrease()
  }

  private func process(transaction t: SKPaymentTransaction) {
    os_log("processing: %@", log: log, type: .debug, t)

    let pid = t.payment.productIdentifier

    guard t.error == nil else {
      let er = t.error!
      os_log("handling transaction error: %@", log: log, type: .error,
             er as CVarArg)
      event(.failed(ShoppingError(underlyingError: er)))
      return finish(transaction: t)
    }

    switch t.transactionState {
    case .failed:
      os_log("transactionState: failed", log: log, type: .debug)
      event(.failed(.failed))
      finish(transaction: t)

    case .purchased:
      os_log("transactionState: purchased", log: log, type: .debug)
      guard let receipt = PodestReceipt(transaction: t) else {
        fatalError("receipt missing")
      }
      
      saveReceipt(receipt)
      event(.purchased(pid))

      finish(transaction: t)

    case .purchasing, .deferred:
      os_log("transactionState: purchasing | deferred", log: log, type: .debug)
      event(.purchasing(pid))

    case .restored:
      os_log("transactionState: restored", log: log, type: .debug)
      guard
        let original = t.original,
        let receipt = PodestReceipt(transaction: original) else {
        fatalError("receipt missing")
      }

      saveReceipt(receipt)
      event(.purchased(pid))
      
      finish(transaction: t)
    }
  }

  func paymentQueue(
    _ queue: SKPaymentQueue,
    updatedTransactions transactions: [SKPaymentTransaction]
  ) {
    os_log("payment queue has updated transactions", log: log, type: .debug)
    
    DispatchQueue.global().async {
      for t in transactions {
        self.process(transaction: t)
      }
    }
  }
  
  func paymentQueueRestoreCompletedTransactionsFinished(
    _ queue: SKPaymentQueue) {
    os_log("payment queue has finished sending restored transactions",
           log: log, type: .debug)
    
    indicator.decrease()
    
    DispatchQueue.global().async {
      self.event(.restored)
    }
  }

  func paymentQueue(
    _ queue: SKPaymentQueue,
    restoreCompletedTransactionsFailedWithError error: Error
  ) {
    os_log("error occurred while restoring transactions: %{public}@",
           log: log, type: .error, error as CVarArg)
    
    indicator.decrease()
    
    DispatchQueue.global().async {
      self.event(.failed(ShoppingError(underlyingError: error, restoring: true)))
    }
  }
}

// MARK: - Shopping

extension StoreFSM: Shopping {
  
  func online() {
    DispatchQueue.global().async {
      self.event(.online)
    }
  }
  
  func update() {
    DispatchQueue.global().async {
      self.event(.update)
    }
  }
  
  func restore() {
    os_log("restoring previous transactions", log: log, type: .debug)
    DispatchQueue.global().async {
      self.event(.restore)
    }
  }
  
  func activate() {
    DispatchQueue.global().async {
      self.event(.activate)
    }
  }
  
  func deactivate() {
    os_log("removing observer from the payment queue", log: log, type: .debug)
    paymentQueue.remove(self)
    stopObservingUbiquitousKeyValueStore()
    isObserving = false
  }

  func payProduct(matching productIdentifier: String) {
    os_log("paying product: %@", log: log, type: .debug, productIdentifier)
    DispatchQueue.global().async {
      self.event(.pay(productIdentifier))
    }
  }

  var canMakePayments: Bool {
    return SKPaymentQueue.canMakePayments()
  }
  
  var maxSubscriptionCount: Int {
    if case .interested = state {
      return 5
    }
    return .max
  }

}
