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

    let layout = StoreLayout()
    
    layout.minimumInteritemSpacing = 20
    layout.minimumLineSpacing = 30

    cv.collectionViewLayout = layout
    cv.contentInsetAdjustmentBehavior = .always
    cv.allowsSelection = false
    cv.dataSource = dataSource
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    Podest.store.update()
  }

  override func willTransition(
    to newCollection: UITraitCollection,
    with coordinator: UIViewControllerTransitionCoordinator
  ) {
    // Preventing layout errors during animation.

    if let l = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
      l.itemSize = UICollectionViewFlowLayout.automaticSize
    }

    super.willTransition(to: newCollection, with: coordinator)
  }

}

/*

private extension UICollectionView {
  
  var safeContentBounds: CGSize {
    let l = safeAreaInsets.left + contentInset.left
    let r = safeAreaInsets.right + contentInset.right

    let w = bounds.width - l - r
    
    let t = safeAreaInsets.top + contentInset.top
    let b = safeAreaInsets.bottom + contentInset.bottom

    let h = bounds.height - t - b
    
    return CGSize(width: w, height: h)
  }

  var maxWidth: CGFloat {
    let layout = collectionViewLayout as! UICollectionViewFlowLayout

    return safeContentBounds.width -
      layout.sectionInset.left - layout.sectionInset.right
  }

  var maxHeight: CGFloat {
    let layout = collectionViewLayout as! UICollectionViewFlowLayout

    return safeContentBounds.height -
      layout.sectionInset.top - layout.sectionInset.bottom
  }
  
  var isSpacious: Bool {
    return traitCollection.containsTraits(in:
      UITraitCollection(traitsFrom: [
        UITraitCollection(horizontalSizeClass: .regular),
        UITraitCollection(verticalSizeClass: .regular)
      ])
    )
  }
  
  var itemsPerRow: CGFloat {
    let w = safeContentBounds.width
    
    if isSpacious {
      return w > 750 ? 2 : 3
    } else {
      return w > 568 ? 3 : 1
    }
  }
  
}

// MARK: - UICollectionViewDelegateFlowLayout

/// Assuming three products, framed by a header and a footer, and displaying
/// of messages, provided as single items by the data source.
extension ProductsViewController: UICollectionViewDelegateFlowLayout {
  
  func itemSize(
    within collectionView: UICollectionView,
    layout: UICollectionViewFlowLayout
  ) -> CGSize {
    guard !dataSource.isMessage else {
      let w = min(collectionView.maxWidth, collectionView.maxHeight)

      return CGSize(width: w, height: w)
    }

    let width = collectionView.safeContentBounds.width
    let spacing = 2 * layout.minimumInteritemSpacing
    let itemsPerRow = collectionView.itemsPerRow
    
    let s = min(width / itemsPerRow, 414) - spacing
    
    return CGSize(width: s, height: min(s, 224))
  }
  
  func collectionView(
    _ collectionView: UICollectionView,
    layout collectionViewLayout: UICollectionViewLayout,
    insetForSectionAt section: Int
  ) -> UIEdgeInsets {
    let bounds = collectionView.safeContentBounds
    let itemsPerRow = dataSource.isMessage ? 1 : collectionView.itemsPerRow
    
    let layout = collectionViewLayout as! UICollectionViewFlowLayout
    let p = itemSize(within: collectionView, layout: layout)
  
    let items = p.width * itemsPerRow
    let columnSpacing = layout.minimumInteritemSpacing * (itemsPerRow - 1)
    let h = max((bounds.width - items - columnSpacing) / 2, 0)

    let v: CGFloat = 12 * (collectionView.isSpacious ? 2 : 1)

    return UIEdgeInsets(top: v, left: h, bottom: v, right: h)
  }

  func collectionView(
    _ collectionView: UICollectionView,
    layout collectionViewLayout: UICollectionViewLayout,
    sizeForItemAt indexPath: IndexPath
  ) -> CGSize {
    let item = dataSource.storeItem(where: indexPath)

    switch item {
    case .failed, .thanks, .offline, .empty, .loading, .restoring:
      let w = min(collectionView.maxWidth, collectionView.maxHeight)

      return CGSize(width: w, height: w)
    case .product:
      let layout = collectionViewLayout as! UICollectionViewFlowLayout
      return itemSize(within: collectionView, layout: layout)
    }
  }
  
  /// Returns the size of header or footer.
  private func makeSupplementaryElementSize(
    collectionView: UICollectionView,
    kind: String
  ) -> CGSize {
    let indexPath = IndexPath(item: 0, section: 0)
    let tmp = dataSource.collectionView(
      collectionView, viewForSupplementaryElementOfKind: kind, at: indexPath)

    let w = collectionView.safeContentBounds.width

    // Removing translated autoresizing mask constraints.
    for c in tmp.constraints {
      switch c.identifier {
      case "UIView-Encapsulated-Layout-Width",
           "UIView-Encapsulated-Layout-Height":
        c.isActive = false
      default:
        continue
      }
    }
    
    tmp.widthAnchor.constraint(equalToConstant: w).isActive = true
    
    let h = tmp.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).height
    
    return CGSize(width: w, height: h)
  }
  
  func collectionView(
    _ collectionView: UICollectionView,
    layout collectionViewLayout: UICollectionViewLayout,
    referenceSizeForHeaderInSection section: Int
  ) -> CGSize {
    guard dataSource.shouldShowHeader else {
      return CGSize(width: 0, height: 0)
    }
    
    return makeSupplementaryElementSize(
      collectionView: collectionView,
      kind: UICollectionView.elementKindSectionHeader
    )
  }

  func collectionView(
    _ collectionView: UICollectionView,
    layout collectionViewLayout: UICollectionViewLayout,
    referenceSizeForFooterInSection section: Int
  ) -> CGSize {
    guard dataSource.shouldShowFooter else {
      return CGSize(width: 0, height: 0)
    }
    
    return makeSupplementaryElementSize(
      collectionView: collectionView,
      kind: UICollectionView.elementKindSectionFooter
    )
  }
  
}

*/
