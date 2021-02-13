//
//  ProductsDataSource.swift
//  Podest
//
//  Created by Michael Nisi on 14.04.18.
//  Copyright © 2018 Michael Nisi. All rights reserved.
//

import UIKit
import StoreKit
import os.log
import BatchUpdates

private let log = OSLog(subsystem: "ink.codes.podest", category: "store")

protocol CellProductsDelegate: class {
  func cell(_ cell: UICollectionViewCell,
            payProductMatching productIdentifier: String)
}

/// Provides a single section presenting in-app purchasing.
final class ProductsDataSource: NSObject, SectionedDataSource {

  /// For making an attributed paragraph.
  struct Info: Summarizable {
    var summary: String?
    var title: String
    var author: String?
    var guid: String
  }

  /// Enumerates item types provided by this data source.
  enum Item: Hashable {
    case article(Info)
    case offline
    case empty
    case product(SKProduct)
    case thanks
    case failed(String)
    case loading
  }

  static var messageCellID = "MessageCellID"
  static var productCellID = "ProductCellID"
  static var articleCellID = "ArticleCollectionViewCellID"

  private var _sections = [[Item.loading]]

  /// The current sections of this data source.
  ///
  /// Sections must be accessed on the main queue.
  var sections: [Array<Item>] {
    get {
      dispatchPrecondition(condition: .onQueue(.main))
      return _sections
    }

    set {
      dispatchPrecondition(condition: .onQueue(.main))
      _sections = newValue
    }
  }

  /// The central change handler called when the collection changed.
  var sectionsChangeHandler: (([[Change<Item>]]) -> Void)?
  
  /// Receives the index path of the product currently being purchased.
  var purchasingHandler: ((IndexPath) -> Void)?
  
  lazy var priceFormatter: NumberFormatter = {
    let fmt = NumberFormatter()

    fmt.formatterBehavior = .behavior10_4
    fmt.numberStyle = .currency

    return fmt
  }()

  /// Speculates if we are currently displaying a message.
  var isMessage: Bool {
    guard sections.count == 1,
      sections.first?.count == 1,
      let first = sections.first?.first else {
      return false
    }

    switch first {
    case .article, .product:
      return false
    case .offline, .empty, .thanks, .failed, .loading:
      return true
    }
  }

  /// A distinct worker queue for diffing.
  private var worker = DispatchQueue.global(qos: .userInteractive)

  private let store: Shopping

  private let contact: Contact

  /// Creates a new products data source.
  ///
  /// - Parameters:
  ///   - store: The store API to use.
  ///   - contact: The sellers contact information.
  init(store: Shopping, contact: Contact) {
    self.store = store
    self.contact = contact
  }

}

// MARK: - UICollectionViewDataSource

extension ProductsDataSource: UICollectionViewDataSource {

  /// Registers nib objects with `collectionView` under identifiers.
  static func registerCells(with collectionView: UICollectionView) {
    let pairs = [
      ("MessageCollectionViewCell", messageCellID),
      ("ProductCell", productCellID),
      ("ArticleCollectionViewCell", articleCellID)
    ]

    for p in pairs {
      let nib = UINib(nibName: p.0, bundle: .main)
      collectionView.register(nib, forCellWithReuseIdentifier: p.1)
    }
  }
  
  // numberOfSections == 1

  func collectionView(
    _ collectionView: UICollectionView,
    numberOfItemsInSection section: Int
  ) -> Int {
    return sections[section].count
  }
  
  func storeItem(where indexPath: IndexPath) -> Item {
    return sections[indexPath.section][indexPath.row]
  }
  
  func collectionView(
    _ collectionView: UICollectionView,
    cellForItemAt indexPath: IndexPath
  ) -> UICollectionViewCell {
    let item = storeItem(where: indexPath)
    
    switch item {
    case .article(let info):
      let cell = collectionView.dequeueReusableCell(
        withReuseIdentifier: ProductsDataSource.articleCellID,
        for: indexPath) as! ArticleCollectionViewCell

      cell.textView.attributedText = StringRepository
        .makeSummaryWithHeadline(info: info)

      return cell
    case .offline:
      let cell = collectionView.dequeueReusableCell(
        withReuseIdentifier: ProductsDataSource.messageCellID,
        for: indexPath) as! MessageCollectionViewCell
      
      cell.title.text = "You’re offline."
      
      return cell
    case .empty:
      let cell = collectionView.dequeueReusableCell(
        withReuseIdentifier: ProductsDataSource.messageCellID,
        for: indexPath) as! MessageCollectionViewCell
      
      cell.title.text = "No products available at the moment."
      
      return cell
    case .product(let product):
      let cell = collectionView.dequeueReusableCell(
        withReuseIdentifier: ProductsDataSource.productCellID,
        for: indexPath) as! ProductCell

      priceFormatter.locale = product.priceLocale

      // In the meantime, I’ve grown sceptical about this self-configuring
      // cells technique. I’d rather encapsulate all configuration in the data
      // source, in one place. Having to switch into cell implementations,
      // while working on the data source is distracting.

      let p = priceFormatter.string(for: product.price) ?? "Sorry"

      cell.data = ProductCell.Data(
        productIdentifier: product.productIdentifier,
        productName: product.localizedTitle,
        productDescription: product.localizedDescription + "\n\(p) per year.",
        price: p
      )

      cell.delegate = self

      return cell
    case .thanks:
      let cell = collectionView.dequeueReusableCell(
        withReuseIdentifier: ProductsDataSource.messageCellID,
        for: indexPath) as! MessageCollectionViewCell
      
      cell.title.text = "Thank you for your purchase."
      
      return cell
    case .failed(let desc):
      let cell = collectionView.dequeueReusableCell(
        withReuseIdentifier: ProductsDataSource.messageCellID,
        for: indexPath) as! MessageCollectionViewCell
      
      cell.title.text = desc
      
      return cell
    
    case .loading:
      let cell = collectionView.dequeueReusableCell(
        withReuseIdentifier: ProductsDataSource.messageCellID,
        for: indexPath) as! MessageCollectionViewCell
      
      cell.title.text = "Loading"
      
      return cell
    }
  }

}

// MARK: - CellProductsDelegate

extension ProductsDataSource: CellProductsDelegate {
  
  func cell(
    _ cell: UICollectionViewCell,
    payProductMatching productIdentifier: String
  ) {
    store.payProduct(matching: productIdentifier)
  }

}

// MARK: - ShoppingDelegate

extension ProductsDataSource: StoreDelegate {

  /// Submits `new` items as our new sole section to the change handler on the
  /// main queue.
  private func submit(_ items: [Item]) {
    // Capturing old sections on the main queue.

    DispatchQueue.main.async { [weak self] in
      guard let old = self?.sections else {
        return
      }

      // Offloading diffing to a worker queue. How many engineers does it take
      // to change a light bulb?

      self?.worker.async {
        let changes = ProductsDataSource.makeChanges(old: old, new: [items])

        DispatchQueue.main.async {
          self?.sectionsChangeHandler?(changes)
        }
      }
    }
  }

  func store(_ store: Shopping, offers products: [SKProduct], error: ShoppingError?) {
    os_log("store: offers: %{public}@", log: log, type: .info, products)

    guard error == nil else {
      let er = error!
      switch er {
      case .offline:
        submit([.offline])

      default:
        submit([.empty])
      }

      return
    }
    
    guard !products.isEmpty else {
      return submit([.empty])
    }

    let claim = Info(
      summary: """
      Chip in, help me make this app better. Please rate it or write a \
      <a href="\(contact.review)">review</a> on the App Store. That helps a lot.
      <p>
      Enjoy your podcasts. 🎧✨
      </p>
      """,
      title: "Making apps is hard",
      author: "Michael Nisi",
      guid: UUID().uuidString
    )

    let explain = Info(
      summary:"""
      Choose your price for a non-renewing subscription, granting you to use \
      this app without restrictions for one year.
      <p>
      Thanks for using Podest.
      </p>
      """,
      title: "Choose your price",
      author: "Michael Nisi",
      guid: UUID().uuidString
    )

    let open = Info(
      summary:"""
      If you feel so inclined, please file issues on \
      <a href="\(contact.github)">GitHub</a>.
      <p>
      <a href="mailto:\(contact.email)">Email me</a> if you have any \
      questions.
      </p>
      """,
      title: "Open Source",
      author: "Michael Nisi",
      guid: UUID().uuidString
    )

    submit(
      [.article(explain)] +
      products.map { .product($0) } +
      [.article(claim), .article(open)]
    )
  }
  
  private func indexPath(matching productIdentifier: ProductIdentifier) -> IndexPath?{
    for (sectionIndex, section) in sections.enumerated() {
      for (itemIndex, item) in section.enumerated() {
        if case .product(let product) = item {
          if product.productIdentifier == productIdentifier {
            return IndexPath(item: itemIndex, section: sectionIndex)
          }
        }
      }
    }
    return nil
  }
  
  func store(_ store: Shopping, purchasing productIdentifier: String) {
    os_log("store: purchasing: %{public}@",
           log: log, type: .info, productIdentifier)

    DispatchQueue.main.async { [weak self] in
      guard let ip = self?.indexPath(matching: productIdentifier) else {
        os_log("store: no matching product found in sections: %{public}@",
               log: log, productIdentifier)
        return
      }

      self?.purchasingHandler?(ip)
    }
  }
  
  func store(_ store: Shopping, purchased productIdentifier: String) {
    os_log("store: purchased: %{public}@",
           log: log, type: .info, productIdentifier)
    submit([.thanks])
  }

  /// Produces items from `error`.
  private static func makeItems(error: ShoppingError) -> [Item] {
    switch error {
    case .cancelled:
      return [.failed("Your purchase has been cancelled.")]
    case .failed, .invalidProduct:
      return [.failed("Your purchase failed.")]
    case .offline:
      return [.offline]
    case .serviceUnavailable:
      return [.failed("The App Store is not available at the moment.")]
    }
  }
  
  func store(_ store: Shopping, error: ShoppingError) {
    os_log("store: error: %{public}@", log: log, error as CVarArg)
    submit(ProductsDataSource.makeItems(error: error))
  }
  
}
