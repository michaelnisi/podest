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
  
  lazy var dataSource: ProductsDataSource = {
    dispatchPrecondition(condition: .onQueue(.main))
    
    let ds = ProductsDataSource()
    
    ds.sectionsChangeHandler = { [weak self] changes in
      guard let cv = self?.collectionView else {
        return
      }

      ds.commit(changes, performingWith: .collection(cv))
    }
    
    ds.purchasingHandler = { [weak self] indexPath in
      DispatchQueue.main.async {
        guard let cell = self?.collectionView?.cellForItem(
          at: indexPath) as? ProductCell, let data = cell.data else {
          return
        }
        
        cell.isPurchasing = true
      }
    }
    
    Podest.store.delegate = ds
    
    return ds
  }()
  
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
    cv.dataSource = dataSource
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)

    Podest.store.update()
  }

}

