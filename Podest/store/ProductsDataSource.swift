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

/// A visual item shown in the store collection view, including messages.
enum StoreItem {
  
  /// The device is currently offline.
  case offline
  
  /// No products available.
  case empty
  
  /// A product on purchase.
  case product(SKProduct)
  
  /// The purchase was successful.
  case thanks
  
  /// The purchase failed.
  case failed(String)
  
  /// Loading products.
  case loading
  
  /// Restoring previous purchases.
  case restoring
  
}

protocol CellProductsDelegate {
  func cell(_ cell: UICollectionViewCell, payProductMatching productIdentifier: String)
}


/// Provides data for our Store UICollectionView.
final class ProductsDataSource: NSObject {

  static var messageCellID = "MessageCellID"
  static var productCellID = "ProductCellID"
  static var productsHeaderID = "ProductsHeaderID"
  static var productsFooterID = "ProductsFooterID"
  
  /// An internal serial queue for synchronized access.
  let sQueue = DispatchQueue(
    label: "ink.codes.podest.ProductsDataSource-\(UUID().uuidString).serial")

  var _sections = [[StoreItem.loading]]
  
  var sections: [[StoreItem]] {
    get {
      return sQueue.sync {
        return _sections
      }
    }
    set {
      sQueue.sync {
        _sections = newValue
        sectionsChangeHandler?()
      }
    }
  }
  
  /// The central change handler called when the collection changed.
  var sectionsChangeHandler: (() -> Void)?
  
  /// Receives the index path of currently purchased item.
  var purchasingHandler: ((IndexPath) -> Void)?
  
  lazy var priceFormatter: NumberFormatter = {
    let fmt = NumberFormatter()
    fmt.formatterBehavior = .behavior10_4
    fmt.numberStyle = .currency
    return fmt
  }()
  
  var shouldShowHeader: Bool {
    return sections.first?.count == 3 
  }
  
  var shouldShowFooter: Bool {
    return shouldShowHeader
  }
  
  var isMessage: Bool {
    return !shouldShowHeader
  }

}

// MARK: - UICollectionViewDataSource

extension ProductsDataSource: UICollectionViewDataSource {
  
  func numberOfSections(in collectionView: UICollectionView) -> Int {
    return sections.count
  }
  
  func collectionView(
    _ collectionView: UICollectionView,
    numberOfItemsInSection section: Int
  ) -> Int {
    return sections[section].count
  }
  
  func storeItem(where indexPath: IndexPath) -> StoreItem {
    return sections[indexPath.section][indexPath.row]
  }
  
  func collectionView(
    _ collectionView: UICollectionView,
    cellForItemAt indexPath: IndexPath
  ) -> UICollectionViewCell {
    let item = storeItem(where: indexPath)
    
    switch item {
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
      
      cell.title.text = "Loading..."
      
      return cell
    
    case .restoring:
      let cell = collectionView.dequeueReusableCell(
        withReuseIdentifier: ProductsDataSource.messageCellID,
        for: indexPath) as! MessageCollectionViewCell
      
      cell.title.text = "Restoring..."
      
      return cell
    }
  }
  
  func collectionView(
    _ collectionView: UICollectionView,
    viewForSupplementaryElementOfKind kind: String,
    at indexPath: IndexPath
  ) -> UICollectionReusableView {
    switch kind {
    case UICollectionView.elementKindSectionHeader:
      let view = collectionView.dequeueReusableSupplementaryView(
        ofKind: kind,
        withReuseIdentifier: ProductsDataSource.productsHeaderID,
        for: indexPath
      ) as! ProductsHeader
      view.body.text = """
      Help me deliver podcasts. Here are three ways you can enjoy podcasts \
      with Podest for one year.
      """
      
      return view
    case UICollectionView.elementKindSectionFooter:
      let view = collectionView.dequeueReusableSupplementaryView(
        ofKind: kind,
        withReuseIdentifier: ProductsDataSource.productsFooterID,
        for: indexPath
      ) as! ProductsHeader
      let body = UIFont.preferredFont(forTextStyle: .body)

      let a = NSMutableAttributedString(string: """
      Choose your price for a non-renewing subscription, granting you to use \
      this app without restrictions for one year.

      Of course, you can always 
      """, attributes: [.font: body])
      
      let b = NSAttributedString(
        string: "restore",
        attributes: [.font: body, .link: "restore"]
      )
      
      let c = NSAttributedString(
        string: " previous purchases.",
        attributes: [.font: body]
      )

      // There were many more segments, in case you’re wondering.
      for t in [b,c] { a.append(t) }
      
      view.body.attributedText = a
      view.body.isUserInteractionEnabled = true
      view.body.delegate = self
      
      return view
    default:
      fatalError("no supplementary element of this kind: \(kind)")
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
    case "https://troubled.pro/privacy.html",
         "https://github.com/michaelnisi",
         "mailto:michael.nisi@gmail.com":
      return true
    default:
      return false
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
  
  func store(_ store: Shopping, offers products: [SKProduct], error: ShoppingError?) {
    os_log("store: offers: %{public}@", log: log, type: .debug, products)

    guard error == nil else {
      let er = error!
      switch er {
      case .offline:
        sections = [[.offline]]
        sectionsChangeHandler?()
      default:
        sections = [[.empty]]
        sectionsChangeHandler?()
      }
      return
    }
    
    guard !products.isEmpty else {
      sections = [[.empty]]
      sectionsChangeHandler?()
      return
    }
    
    sections = [products.map { .product($0) }]
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
    
    guard let ip = indexPath(matching: productIdentifier) else {
      os_log("store: no matching product found in sections: %{public}@",
             log: log, productIdentifier)
      return
    }
    
    purchasingHandler?(ip)
  }
  
  func storeRestoring(_ store: Shopping) {
    os_log("store: restoring", log: log, type: .debug)
    sections = [[.restoring]]
  }
  
  func storeRestored(
    _ store: Shopping,
    productIdentifiers: [String]
  ) {
    os_log("store: restored: %{public}@",
           log: log, type: .debug, productIdentifiers)
    guard !productIdentifiers.isEmpty else {
      sections = [[.failed("Sorry, no previous purchases to restore.")]]
      return
    }
    sections = [[.thanks]]
  }
  
  func store(_ store: Shopping, purchased productIdentifier: String) {
    os_log("store: purchased: %{public}@",
           log: log, type: .debug, productIdentifier)
    sections = [[.thanks]]
  }
  
  private static func makeSections(error: ShoppingError) -> [[StoreItem]] {
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
    sections = ProductsDataSource.makeSections(error: error)
  }
  
}
