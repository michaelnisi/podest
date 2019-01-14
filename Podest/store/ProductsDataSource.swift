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

private let log = OSLog.disabled

protocol CellProductsDelegate {
  func cell(_ cell: UICollectionViewCell, payProductMatching productIdentifier: String)
}

/// Provides data for our Store UICollectionView.
final class ProductsDataSource: NSObject, SectionedDataSource {

  /// Enumerates item types provided by this data source.
  enum Item: Hashable {
    case article(String, String, String)
    case offline
    case empty
    case product(SKProduct)
    case thanks
    case failed(String)
    case loading
    case restoring
  }

  static var messageCellID = "MessageCellID"
  static var productCellID = "ProductCellID"
  static var productsHeaderID = "ProductsHeaderID"
  static var productsFooterID = "ProductsFooterID"
  static var articleCellID = "ArticleCollectionViewCellID"

  var _sections = [[Item.loading]]

  /// The current sections of this data source.
  ///
  /// Access from the main queue only.
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
    case .offline, .empty, .thanks, .failed, .loading, .restoring:
      return true
    }
  }

  /// A distinct worker queue for diffing.
  private var worker = DispatchQueue.global()

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
  
  func numberOfSections(in collectionView: UICollectionView) -> Int {
    return sections.count
  }
  
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
    case .article(let category, let headline, let body):
      let cell = collectionView.dequeueReusableCell(
        withReuseIdentifier: ProductsDataSource.articleCellID,
        for: indexPath) as! ArticleCollectionViewCell

      cell.categoryLabel.font = .preferredFont(forTextStyle: .body)
      cell.categoryLabel.text = category

      cell.headlineLabel.font = UIFontMetrics.default.scaledFont(for:
        .systemFont(ofSize: 29, weight: .bold))
      cell.headlineLabel.text = headline

      cell.bodyLabel.font = UIFontMetrics.default.scaledFont(for:
        .systemFont(ofSize: 19, weight: .medium))
      cell.bodyLabel.text = body

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
      os_log("** product: %{public}@", log: log, type: .debug, product.productIdentifier)
      
      let cell = collectionView.dequeueReusableCell(
        withReuseIdentifier: ProductsDataSource.productCellID,
        for: indexPath) as! ProductCell

      priceFormatter.locale = product.priceLocale

      cell.data = ProductCell.Data(
        productIdentifier: product.productIdentifier,
        productName: product.localizedTitle,
        productDescription: product.localizedDescription,
        price: priceFormatter.string(for: product.price) ?? "Sorry"
      )

      cell.delegate = self

      return cell
    case .thanks:
      let cell = collectionView.dequeueReusableCell(
        withReuseIdentifier: ProductsDataSource.messageCellID,
        for: indexPath) as! MessageCollectionViewCell
      
      cell.title.text = "Thank you!"
      
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
      
      cell.title.text = "Loading Products…"
      
      return cell
    
    case .restoring:
      let cell = collectionView.dequeueReusableCell(
        withReuseIdentifier: ProductsDataSource.messageCellID,
        for: indexPath) as! MessageCollectionViewCell
      
      cell.title.text = "Restoring Purchases…"
      
      return cell
    }
  }

}

// MARK: - UITextViewDelegate

extension ProductsDataSource: UITextViewDelegate {
  
  func textView(
    _ textView: UITextView,
    shouldInteractWith URL: URL,
    in characterRange: NSRange,
    interaction: UITextItemInteraction
  ) -> Bool {
    switch URL.absoluteString {
    case "restore":
      Podest.store.restore()
      return false
    default:
      return true
    }
  }
  
}

// MARK: - CellProductsDelegate

extension ProductsDataSource: CellProductsDelegate {
  
  func cell(
    _ cell: UICollectionViewCell,
    payProductMatching productIdentifier: String
  ) {
    Podest.store.payProduct(matching: productIdentifier)
  }

}

// MARK: - ShoppingDelegate

extension ProductsDataSource: StoreDelegate {

  /// Submits `new` sections with the change handler on the main queue.
  private func submitSections(_ new: [Array<Item>]) {
    // Capturing old sections on the main queue.

    DispatchQueue.main.async { [weak self] in
      guard let old = self?.sections else {
        return
      }

      // Offloading diffing to a worker queue.

      self?.worker.async {
        let changes = ProductsDataSource.makeChanges(old: old, new: new)

        DispatchQueue.main.async {
          self?.sectionsChangeHandler?(changes)
        }
      }
    }
  }

  func store(_ store: Shopping, offers products: [SKProduct], error: ShoppingError?) {
    os_log("store: offers: %{public}@", log: log, type: .debug, products)

    guard error == nil else {
      let er = error!
      switch er {
      case .offline:
        submitSections([[.offline]])

      default:
        submitSections([[.empty]])
      }

      return
    }
    
    guard !products.isEmpty else {
      return submitSections([[.empty]])
    }

    let intro = Item.article(
      "Support",
      "Making apps is hard",
      """
      Help me deliver podcasts. Here are three ways you can enjoy podcasts \
      with Podest for one year.
      """
    )

    let outro = Item.article(
      "Thanks",
      "Making apps is fun",
      """
      Choose your price for a non-renewing subscription, granting you to use \
      this app without restrictions for one year.

      Of course, you can always restore previous purchases.
      """
    )

    submitSections([[intro], products.map { .product($0) }, [outro]])
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
           log: log, type: .debug, productIdentifier)

    DispatchQueue.main.async { [weak self] in
      guard let ip = self?.indexPath(matching: productIdentifier) else {
        os_log("store: no matching product found in sections: %{public}@",
               log: log, productIdentifier)
        return
      }

      self?.purchasingHandler?(ip)
    }
  }
  
  func storeRestoring(_ store: Shopping) {
    os_log("store: restoring", log: log, type: .debug)
    submitSections([[.restoring]])
  }
  
  func storeRestored(
    _ store: Shopping,
    productIdentifiers: [String]
  ) {
    os_log("store: restored: %{public}@",
           log: log, type: .debug, productIdentifiers)

    guard !productIdentifiers.isEmpty else {
      return submitSections([[.failed("Sorry, no previous purchases to restore.")]])
    }

    submitSections([[.thanks]])
  }
  
  func store(_ store: Shopping, purchased productIdentifier: String) {
    os_log("store: purchased: %{public}@",
           log: log, type: .debug, productIdentifier)
    submitSections([[.thanks]])
  }
  
  private static func makeSections(error: ShoppingError) -> [[Item]] {
    switch error {
    case .cancelled:
      return [[.failed("Your purchase has been cancelled.")]]
    case .failed, .invalidProduct:
      return [[.failed("Your purchase failed.")]]
    case .notRestored:
      return [[.failed("Not restored.")]]
    case .offline:
      return [[.offline]]
    case .serviceUnavailable:
      return [[.failed("The App Store is not available at the moment.")]]
    }
  }
  
  func store(_ store: Shopping, error: ShoppingError) {
    os_log("store: error: %{public}@", log: log, error as CVarArg)
    submitSections(ProductsDataSource.makeSections(error: error))
  }
  
}
