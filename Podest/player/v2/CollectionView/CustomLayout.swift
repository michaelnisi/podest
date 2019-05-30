//
//  CustomLayout.swift
//  Player
//
//  Created by Michael Nisi on 16.05.19.
//  Copyright © 2019 Michael Nisi. All rights reserved.
//

import UIKit

class CustomLayout: UICollectionViewLayout {
  
  /// The combined attributes frame.
  var contentBounds = CGRect.zero
  
  /// The attributes cache.
  var cachedAttributes = [UICollectionViewLayoutAttributes]()
  
  /// Returns the initial rectangular space for our layout.
  private static 
    func makeRectangle(collectionView cv: UICollectionView) -> CGRect {
    let m = cv.layoutMargins
    let insets = UIEdgeInsets(top: m.top, left: 0, bottom: m.bottom, right: 0)
    
    return cv.bounds.inset(by: insets)
  }
  
  override func prepare() {
    super.prepare()
  }
  
  override var collectionViewContentSize: CGSize {
    return contentBounds.size
  }
  
  override
  func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
    guard let cv = collectionView else { return false }
    return !newBounds.size.equalTo(cv.bounds.size)
  }
  
  override func layoutAttributesForItem(
    at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
    return cachedAttributes[indexPath.item]
  }
  
  /// Returns the first index of `attributes` intersecting with `rect` between
  /// `start` and `end`.
  private static func firstIntersectingIndex(
    _ attributes: [UICollectionViewLayoutAttributes],
    _ rect: CGRect,
    start: Int,
    end: Int
    ) -> Int? {
    if end < start { return nil }
    
    let mid = (start + end) / 2
    let attr = attributes[mid]
    
    if attr.frame.intersects(rect) {
      return mid
    } else {
      if attr.frame.maxY < rect.minY {
        return firstIntersectingIndex(attributes, rect, start: (mid + 1), end: end)
      } else {
        return firstIntersectingIndex(attributes, rect, start: start, end: (mid - 1))
      }
    }
  }
  
  override func layoutAttributesForElements(
    in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
    var attributesArray = [UICollectionViewLayoutAttributes]()
    
    // Find any cell that sits within the query rect.
    guard let lastIndex = cachedAttributes.indices.last,
      let firstMatchIndex = CustomLayout.firstIntersectingIndex(
        cachedAttributes, rect, start: 0, end: lastIndex) else {
          return attributesArray
    }
    
    // Starting from the match, loop up and down through the array until all
    // the attributes have been added within the query rect.
    for attributes in cachedAttributes[..<firstMatchIndex].reversed() {
      guard attributes.frame.maxY >= rect.minY else { break }
      attributesArray.append(attributes)
    }
    
    for attributes in cachedAttributes[firstMatchIndex...] {
      guard attributes.frame.minY <= rect.maxY else { break }
      attributesArray.append(attributes)
    }
    
    
    return attributesArray
  }
  
  override func finalLayoutAttributesForDisappearingItem(
    at itemIndexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
    return nil
  }
  
  override func initialLayoutAttributesForAppearingItem(
    at itemIndexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
    return nil
  }
}
