//===----------------------------------------------------------------------===//
//
// This source file is part of the Podest open source project
//
// Copyright (c) 2021 Michael Nisi and collaborators
// Licensed under MIT License
//
// See https://github.com/michaelnisi/podest/blob/main/LICENSE for license information
//
//===----------------------------------------------------------------------===//

import UIKit
import Podcasts

final class ProductsViewController: UICollectionViewController {

  @objc func onDone() {
    invalidate()
    dismiss(animated: true)
  }

  private var dataSource: ProductsDataSource!

  // Returns a newly created and installed data source.
  private func install() -> ProductsDataSource {
    dataSource = ProductsDataSource(store: Podcasts.store, contact: Podcasts.contact, textDelegate: self)

    dataSource.sectionsChangeHandler = { [weak self] changes in
      guard let cv = self?.collectionView else {
        return
      }

      self?.dataSource.commit(changes, performingWith: .collection(cv))
    }

    dataSource.purchasingHandler = { [weak self] indexPath in
      DispatchQueue.main.async {
        guard let cv = self?.collectionView,
          let cell = cv.cellForItem(at: indexPath) as? ProductCell else {
          return
        }

        cell.isPurchasing = true

        cv.scrollToItem(at: indexPath, at: .centeredVertically, animated: true)
      }
    }

    Podcasts.store.delegate = dataSource 

    return dataSource
  }

  /// Lets go of the data source.
  private func invalidate() {
    dataSource.sectionsChangeHandler = nil
    dataSource.purchasingHandler = nil
    dataSource = nil
  }

}

// MARK: - UIViewController

extension ProductsViewController {

  override func viewDidLoad() {
    super.viewDidLoad()
    
    navigationItem.title = "In-App Purchases"
    navigationItem.rightBarButtonItem = UIBarButtonItem(
      barButtonSystemItem: .done, target: self, action: #selector(onDone))

    guard let cv = collectionView else {
      fatalError("collectionView expected")
    }

    ProductsDataSource.registerCells(with: cv)

    cv.collectionViewLayout = StoreLayout()
    cv.contentInsetAdjustmentBehavior = .always
    cv.allowsSelection = false
    cv.dataSource = install()
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    Podcasts.store.update()
  }

}

extension ProductsViewController: UITextViewDelegate {
  func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
      UIApplication.shared.open(URL)
      return false
  }
}
