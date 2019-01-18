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

protocol CellProductsDelegate: class {
  func cell(_ cell: UICollectionViewCell, payProductMatching productIdentifier: String)
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
    case restoring
  }

  static var messageCellID = "MessageCellID"
  static var productCellID = "ProductCellID"
  static var productsHeaderID = "ProductsHeaderID"
  static var productsFooterID = "ProductsFooterID"
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

      cell.textView.attributedText = StringRepository.makeSummaryWithHeadline(info: info)
      cell.textView.delegate = self

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
    case "restore:":
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

  /// Submits `new` items as our new sole section to the change handler on the
  /// main queue.
  private func submit(_ items: [Item]) {
    // Capturing old sections on the main queue.

    DispatchQueue.main.async { [weak self] in
      guard let old = self?.sections else {
        return
      }

      // Offloading diffing to a worker queue.

      self?.worker.async {
        let changes = ProductsDataSource.makeChanges(old: old, new: [items])

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
      Help me deliver podcasts. Here are three ways you can enjoy podcasts \
      with Podest for one year and support my work.
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
      Of course, you can always <a href="restore:">restore</a> previous purchases.
      </p>
      """,
      title: "Choose your price",
      author: "Michael Nisi",
      guid: UUID().uuidString
    )

    let open = Info(
      summary:"""
      If you feel so inclined, please create issues on \
      <a href="\(Podest.contact.github)">GitHub</a>.
      <p>
      <a href="mailto:\(Podest.contact.email)">Email me</a> if you have any \
      questions.
      </p>
      """,
      title: "100% Open Source",
      author: "Michael Nisi",
      guid: UUID().uuidString
    )

    submit(
      [.article(claim)] +
      products.map { .product($0) } +
      [.article(explain), .article(open)]
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
    submit([.restoring])
  }
  
  func storeRestored(
    _ store: Shopping,
    productIdentifiers: [String]
  ) {
    os_log("store: restored: %{public}@",
           log: log, type: .debug, productIdentifiers)

    guard !productIdentifiers.isEmpty else {
      return submit([.failed("Sorry, no previous purchases to restore.")])
    }

    submit([.thanks])
  }
  
  func store(_ store: Shopping, purchased productIdentifier: String) {
    os_log("store: purchased: %{public}@",
           log: log, type: .debug, productIdentifier)
    submit([.thanks])
  }

  /// Produces items from `error`.
  private static func makeItems(error: ShoppingError) -> [Item] {
    switch error {
    case .cancelled:
      return [.failed("Your purchase has been cancelled.")]
    case .failed, .invalidProduct:
      return [.failed("Your purchase failed.")]
    case .notRestored:
      return [.failed("Not restored.")]
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
