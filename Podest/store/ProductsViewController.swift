//
//  ProductsViewController.swift
//  Podest
//
//  Created by Michael Nisi on 13.04.18.
//  Copyright © 2018 Michael Nisi. All rights reserved.
//

import UIKit

final class ProductsViewController: UICollectionViewController {
  
  @objc func onDone() {
    dismiss(animated: true)
  }

  private var dataSource: ProductsDataSource!

  // Returns a newly created and installed data source.
  private func install() -> ProductsDataSource {
    dataSource = ProductsDataSource(store: Podest.store, contact: Podest.contact)

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

    Podest.store.delegate = dataSource

    return dataSource
  }

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
    navigationItem.largeTitleDisplayMode = .always
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
    Podest.store.update()
  }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    invalidate()
  }

}

