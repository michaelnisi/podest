//
//  ColumnFlowLayout.swift
//  Podest
//
//  Created by Michael Nisi on 03.01.19.
//  Copyright © 2019 Michael Nisi. All rights reserved.
//

import UIKit

class ColumnFlowLayout: UICollectionViewFlowLayout {

  var summaryAttributes: UICollectionViewLayoutAttributes!

  override func prepare() {
    guard let cv = collectionView else {
      return
    }

    let w = cv.bounds.inset(by: cv.layoutMargins).size.width

    self.itemSize = CGSize(width: w, height: 104)

    self.sectionInset = UIEdgeInsets(
      top: self.minimumInteritemSpacing, left: 0.0, bottom: 0.0, right: 0.0)

    self.sectionInsetReference = .fromSafeArea
  }

  override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
    return super.layoutAttributesForItem(at: indexPath)
  }

}

