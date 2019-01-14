//
//  StoreLayout.swift
//  Podest
//
//  Created by Michael Nisi on 13.01.19.
//  Copyright © 2019 Michael Nisi. All rights reserved.
//

import UIKit

/// The collection view flow layout for the in-app store.
class StoreLayout: UICollectionViewFlowLayout {

  private var dataSource: ProductsDataSource {
    return collectionView?.dataSource as! ProductsDataSource
  }

  override func prepare() {
    guard let cv = collectionView else {
      return
    }

    let w = cv.bounds.inset(by: cv.layoutMargins).size.width
    let h = cv.bounds.inset(by: cv.layoutMargins).size.height

    itemSize = CGSize(width: w, height: dataSource.isMessage ? h : 224)

    sectionInset = UIEdgeInsets(
      top: self.minimumInteritemSpacing, left: 0.0, bottom: 0.0, right: 0.0)

    sectionInsetReference = .fromSafeArea
  }
  
}
