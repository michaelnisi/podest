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

/// Enumerates known events within this state machine.
private enum StoreEvent {
  case resume
  case pause
  case failed(ShoppingError)
  case online
  case pay(ProductIdentifier)
  case productsReceived([SKProduct], ShoppingError?)
  case purchased(ProductIdentifier)
  case purchasing(ProductIdentifier)
  case receiptsChanged
  case update
}

extension StoreEvent: CustomStringConvertible {
  
  var description: String {
    switch self {
    case .resume:
      return "StoreEvent: resume"
    case .pause:
      return "StoreEvent: pause"
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
    case .update:
      return "StoreEvent: update"
    }
  }
  
}

private class DefaultPaymentQueue: Paying {}

/// StoreFSM is a store for in-app purchases, offering a single non-renewing
/// subscription at three flexible prices. After a successful purchase the store
/// disappears. It returns when the subscription expires or its receipts has
/// been deleted from the `Storing` key-value database.
///
/// The exposed `Shopping` API expects calls from the main queue.
final class StoreFSM: NSObject {

  /// The file URL of where to find the product identifiers.
  private let url: URL

  /// The maximum age of cached products should be kept relatively short, not
  /// existing products cannot be sold. However, products don’t change often.
  private let ttl: TimeInterval
  
  /// A queue of payment transactions to be processed by the App Store.
  private let paymentQueue: Paying
  
  /// The (default) iCloud key-value store object.
  private let db: NSUbiquitousKeyValueStore

  /// The version of the app.
  private let version: BuildVersion

  static var unsealedKey = "ink.codes.podest.store.unsealed"
  
  private static func unseal(_ db: NSUbiquitousKeyValueStore) {
    os_log("unsealing", log: log, type: .debug)
    db.set(Date().timeIntervalSince1970, forKey: StoreFSM.unsealedKey)
  }
  
  /// Creates a new store with minimal dependencies. **Protocol dependencies**
  /// for easier testing.
  ///
  /// - Parameters:
  ///   - url: The file URL of a JSON file containing product identifiers.
  ///   - ttl: The maximum age, 10 minutes, of cached products in seconds.
  ///   - paymentQueue: The App Store payment queue.
  ///   - db: The (default) iCloud key-value store object.
  ///   - version: The version of this app.
  init(
    url: URL,
    ttl: TimeInterval = 600,
    paymentQueue: Paying = DefaultPaymentQueue(),
    db: NSUbiquitousKeyValueStore = .default,
    version: BuildVersion = BuildVersion()
  ) {
    self.url = url
    self.ttl = ttl
    self.paymentQueue = paymentQueue
    self.db = db
    self.version = version
    self.state = .initialized
    
    if db.double(forKey: StoreFSM.unsealedKey) == 0 {
      StoreFSM.unseal(db)
    }
  }

  /// A date formatting block.
  public var formatDate: ((Date) -> String)?

  /// Flag for asserts, `true` if we are observing the payment queue.
  private var isObserving: Bool {
    return didChangeExternallyObserver != nil
  }

  /// The currently available products.
  private (set) var products: [SKProduct]?

  weak var delegate: StoreDelegate?
  
  weak var subscriberDelegate: StoreAccessDelegate?
  
  // MARK: - Reachability

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

    let req = SKProductsRequest(productIdentifiers: self.productIdentifiers)
    req.delegate = self
    req.start()
    
    request = req
  }

  private func updateProducts() -> StoreState {
    guard isReachable() else {
      delegateQueue.async {
        self.delegate?.store(self, offers: [], error: .offline)
      }
      
      if case .subscribed = validateReceipts() {
        return .offline(true)
      } else {
        return .offline(validateTrial())
      }
    }
    
    fetchProducts()
    
    return .fetchingProducts
  }

  // MARK: - Saving and Loading Receipts

  /// Returns different key for store and sandbox `environment`.
  private static func receiptsKey(suiting environment: BuildVersion.Environment) -> String {
    return environment == .sandbox ? "receiptsSandbox" : "receipts"
  }
  
  public func removeReceipts(forcing: Bool = false) -> Bool {
    switch (version.env, forcing) {
    case (.sandbox, _), (.store, true), (.simulator, _):
      os_log("removing receipts", log: log)
      db.removeObject(forKey: StoreFSM.receiptsKey(suiting: version.env))
      StoreFSM.unseal(db)
      
      return true
      
    case (.store, _):
      os_log("not removing production receipts without force", log: log)
      
      return false
    }
  }

  private func loadReceipts() -> [PodestReceipt] {
    dispatchPrecondition(condition: .notOnQueue(.main))

    let r = StoreFSM.receiptsKey(suiting: version.env)

    os_log("loading receipts: %@", log: log, type: .debug, r)

    guard let json = db.data(forKey: r) else {
      os_log("no receipts: creating container: %@", log: log, type: .debug, r)
      return []
    }
    
    do {
      return try JSONDecoder().decode([PodestReceipt].self, from: json)
    } catch {
      precondition(removeReceipts(forcing: true))
      return []
    }
  }

  private func updateSettings(status: String, expiration: Date) {
    let date = formatDate?(expiration) ?? expiration.description
    
    os_log("updating settings: ( %@, %@ )", log: log, type: .debug, status, date)
    UserDefaults.standard.set(status, forKey: UserDefaults.statusKey)
    UserDefaults.standard.set(date, forKey: UserDefaults.expirationKey)
  }

  static func makeExpiration(date: Date, period: Period) -> Date {
    return Date(timeIntervalSince1970: date.timeIntervalSince1970 + period.rawValue)
  }

  private func saveReceipt(_ receipt: PodestReceipt) {
    os_log("saving receipt: %@", log: log, type: .debug,
           String(describing: receipt))

    let acc = loadReceipts() + [receipt]
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    let data = try! encoder.encode(acc)
    let r = StoreFSM.receiptsKey(suiting: version.env)

    db.set(data, forKey: r)

    let id = receipt.productIdentifier
    let name = (id.split(separator: ".").last ?? "unknown").capitalized
    let x = StoreFSM.makeExpiration(date: receipt.transactionDate, period: .subscription)
    updateSettings(status: name, expiration: x)

    let str = String(data: data, encoding: .utf8)!

    os_log("saved: ( %@, %@ )", log: log, type: .debug, r, str)
  }

  /// Enumerates time periods in seconds.
  enum Period: TimeInterval {
    typealias RawValue = TimeInterval
    case subscription = 3.154e7
    case trial = 2.419e6
    case always = 0

    /// Returns `true` if `date` exceeds this period into the future.
    func isExpired(date: Date) -> Bool {
      return date.timeIntervalSinceNow <= -rawValue
    }
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

      guard productIdentifiers.contains(id),
        !Period.subscription.isExpired(date: r.transactionDate) else {
        continue
      }
      
      return id
    }
    
    return nil
  }
  
  private func validateTrial(updatingSettings: Bool = false) -> Bool {
    os_log("validating trial", log: log, type: .debug)
    
    let ts = db.double(forKey: StoreFSM.unsealedKey)
    
    if updatingSettings {
      let unsealed = Date(timeIntervalSince1970: ts)
      let expiration = StoreFSM.makeExpiration(date: unsealed, period: Period.trial)
      updateSettings(status: "Free Trial", expiration: expiration)
    }
    
    return !Period.trial.isExpired(date: Date(timeIntervalSince1970: ts))
  }

  private func validateReceipts() -> StoreState {
    let receipts = loadReceipts()
    
    os_log("validating receipts: %@", log: log, type: .debug,
           String(describing: receipts))

    guard let id = StoreFSM.validProductIdentifier(
      receipts, matching: productIdentifiers) else {
      return .interested(validateTrial(updatingSettings: true))
    }

    return .subscribed(id)
  }

  // MARK: - Handling Events and Managing State

  /// An internal serial queue for synchronized access.
  private let sQueue = DispatchQueue(
    label: "ink.codes.podest.StoreFSM",
    target: .global()
  )

  private (set) var state: StoreState {
    didSet {
      os_log("new state: %{public}@, old state: %{public}@",
             log: log, type: .debug,
             state.description, oldValue.description
      )
    }
  }

  // Calling the delegate on a distinct system queue for keeping things
  // serially in order.
  private var delegateQueue = DispatchQueue.global()

  /// Is `true` for interested users with the intention of hiding the store for customers.
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

    paymentQueue.add(payment)
    
    return .purchasing(productIdentifier, state)
  }

  private var didChangeExternallyObserver: NSObjectProtocol?

  /// Begin observing kv-store for receipt and account changes. In both cases
  /// firing a `.receiptsChanged` event.
  private func observeUbiquitousKeyValueStore() {
    precondition(didChangeExternallyObserver == nil)

    let r = StoreFSM.receiptsKey(suiting: version.env)
    
    didChangeExternallyObserver = NotificationCenter.default.addObserver(
      forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
      object: db,
      queue: .main
    ) { notification in
      guard let info = notification.userInfo,
        let reason = info[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int else {
        return
      }
      
      switch reason {
      case NSUbiquitousKeyValueStoreAccountChange:
        os_log("push received: account change", log: log, type: .info)

        DispatchQueue.global().async {
          self.event(.receiptsChanged)
        }

      case NSUbiquitousKeyValueStoreInitialSyncChange,
           NSUbiquitousKeyValueStoreServerChange:
        guard
          let keys = info[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String],
          keys.contains(r) else {
          break
        }

        os_log("push received: initial sync | server change",
               log: log, type: .info)
        DispatchQueue.global().async {
          self.event(.receiptsChanged)
        }

      case NSUbiquitousKeyValueStoreQuotaViolationChange:
        os_log("push received: quota violation", log: log)

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

    didChangeExternallyObserver = nil
  }

  private func addObservers() -> StoreState {
    precondition(!isObserving)
    paymentQueue.add(self)
    observeUbiquitousKeyValueStore()

    return updateProducts()
  }

  private func removeObservers() -> StoreState {
    precondition(isObserving)
    paymentQueue.remove(self)
    stopObservingUbiquitousKeyValueStore()
    
    return .initialized
  }

  private func receiveProducts(_ products: [SKProduct], error: ShoppingError?) -> StoreState {
    self.products = products

    delegateQueue.async {
      self.delegate?.store(self, offers: products, error: error)
    }

    return updateIsAccessible(matching: validateReceipts())
  }
  
  /// Returns the next state after an `error`, overriding `nextState` in some
  /// cases.
  ///
  /// Designated to **never** prompt subscribers about their expired free trial.
  /// OK, there’s still the rare case, where users subscribed on another device
  /// and are launching the app on an offline unsynchronized device. Thoughts?
  private func updatedState(
    after error: ShoppingError,
    next nextState: StoreState
  ) -> StoreState {
    let er: ShoppingError = isReachable() ? error : .offline
    
    delegateQueue.async {
      self.delegate?.store(self, error: er)
    }
    
    if case .offline = er {
      if case .subscribed  = validateReceipts() {
        return .offline(true)
      } else {
        return .offline(validateTrial())
      }
    }
    
    return nextState
  }
  
  /// Returns the new store state after processing `event` relatively to the
  /// current state. `interested` and `subscribed` are the two main antagonistic
  /// states this finite state machine can be in. Its other states are
  /// transitional.
  ///
  /// This strict FSM **traps** on unexpected events. All switch statements must
  /// be **exhaustive**.
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
      case .resume:
        return addObservers()

      case .pause:
        return state

      case .failed,
           .online,
           .pay,
           .productsReceived,
           .purchased,
           .purchasing,
           .receiptsChanged,
           .update:
        fatalError("unhandled event")
      }

    // MARK: fetchingProducts

    case .fetchingProducts:
      switch event {
      case .productsReceived(let products, let error):
        return receiveProducts(products, error: error)
      
      case .receiptsChanged, .update, .online:
        return state

      case .failed(let error):
        return updatedState(after: error, next: .interested(validateTrial()))

      case .resume:
        return state

      case .pause:
        return removeObservers()

      case .pay, .purchased, .purchasing:
        fatalError("unhandled event")
      }

    // MARK: offline

    case .offline:
      switch event {
      case .online, .receiptsChanged, .update:
        return updateProducts()

      case .pause:
        return removeObservers()

      case .resume, .failed, .pay, .productsReceived, .purchased, .purchasing:
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
        return updatedState(after: error, next: state)

      case .pay(let pid):
        delegateQueue.async {
          self.delegate?.store(self, purchasing: pid)
        }

        return addPayment(matching: pid)

      case .update:
        return updateProducts()

      case .productsReceived(let products, let error):
        return receiveProducts(products, error: error)

      case .resume:
        return state

      case .pause:
        return removeObservers()

      case .online:
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
          os_log("parallel purchasing: ( %@, %@ )", log: log, current, pid)
        }

        return state
      
      case .receiptsChanged:
        return updateIsAccessible(matching: validateReceipts())

      case .update:
        return updateProducts()

      case .pause:
        return removeObservers()

      case .productsReceived(let products, let error):
        return receiveProducts(products, error: error)

      case .resume, .online:
        fatalError("unhandled event")
      }
    }
  }

  /// Synchronously handles event using `sQueue`, our event queue. Obviously,
  /// a store with one cashier works sequentially.
  private func event(_ e: StoreEvent) {
    sQueue.sync {
      os_log("handling event: %{public}@", log: log, type: .debug, e.description)

      state = updatedState(after: e)
    }
  }

  // MARK: - Ratings and Reviews

  /// The timeout triggering rating requests.
  private var rateIncentiveTimeout: DispatchSourceTimer?

  /// A counting threshold that must be crossed before a timeout is started
  /// that eventually might trigger an actual rating request.
  private var rateIncentiveThreshold = 10 {
    didSet {
      os_log("rate incentive threshold: %{public}i",
             log: log, type: .debug, rateIncentiveThreshold)
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
  }

  private func process(transaction t: SKPaymentTransaction) {
    os_log("processing: %@", log: log, type: .debug, t)

    let pid = t.payment.productIdentifier

    guard t.error == nil else {
      let er = t.error!

      os_log("handling transaction error: %@",
             log: log, type: .error, er as CVarArg)

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
      fatalError("unexpected transaction state")
      
    @unknown default:
      fatalError("unknown case in switch: \(t.transactionState)")
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
  
  func resume() {
    os_log("resuming: %@", log: log, type: .debug, String(describing: version))
    DispatchQueue.global().async {
      self.event(.resume)
    }
  }
  
  func pause() {
    DispatchQueue.global().async {
      self.event(.pause)
    }
  }

  func payProduct(matching productIdentifier: String) {
    DispatchQueue.global().async {
      self.event(.pay(productIdentifier))
    }
  }

  var canMakePayments: Bool {
    return SKPaymentQueue.canMakePayments()
  }


}

// MARK: - Rating

extension StoreFSM: Rating {

  func requestReview() {
    dispatchPrecondition(condition: .onQueue(.main))
    rateIncentiveTimeout?.cancel()

    guard rateIncentiveThreshold >= 0 else {
      return
    }

    rateIncentiveThreshold -= 1

    guard rateIncentiveThreshold == 0 else {
      return
    }

    rateIncentiveThreshold = 10
    let build = version.build

    guard UserDefaults.standard.lastVersionPromptedForReview != version.build else {
      // Thwarting further attempts for same version.
      rateIncentiveThreshold = -1

      return
    }

    rateIncentiveTimeout = setTimeout(delay: .seconds(2), queue: .main) {
      UserDefaults.standard.set(
        build, forKey: UserDefaults.lastVersionPromptedForReviewKey)
      SKStoreReviewController.requestReview()
    }
  }

  func cancelReview(resetting: Bool) {
    dispatchPrecondition(condition: .onQueue(.main))
    rateIncentiveTimeout?.cancel()

    if resetting {
      rateIncentiveThreshold = 10
    }
  }

  func cancelReview() {
    cancelReview(resetting: false)
  }

}

// MARK: - Expiring

extension StoreFSM: Expiring {
  
  func isExpired() -> Bool {
    return sQueue.sync {
      switch state {
      case .offline(let free), .interested(let free):
        let expired = !free
        
        if expired {
          // Preventing overlapping alerts.
          rateIncentiveTimeout?.cancel()
          rateIncentiveThreshold = -1
        }
        
        delegateQueue.async {
          self.subscriberDelegate?.store(self, isExpired: expired)
        }
        
        return expired
      case .fetchingProducts, .initialized, .purchasing, .subscribed:
        return false
      }
    }
  }

}
