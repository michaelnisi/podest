//
//  ListLayout.swift
//  Podest
//
//  Created by Michael Nisi on 07.01.19.
//  Copyright © 2019 Michael Nisi. All rights reserved.
//

import UIKit

class ListLayout: UICollectionViewLayout {

  var contentBounds = CGRect.zero
  var cachedAttributes = [UICollectionViewLayoutAttributes]()

  override func prepare() {
    super.prepare()

    guard let cv = collectionView else { return }

    // Reset cached information.
    cachedAttributes.removeAll()
    contentBounds = CGRect(origin: .zero, size: cv.bounds.size)

    let sectionCount = cv.numberOfSections
    var currentSection = 0
    let cvWidth = cv.bounds.size.width

    var lastFrame: CGRect = .zero

    while currentSection < sectionCount {
      let count = cv.numberOfItems(inSection: currentSection)
      var currentIndex = 0

      while currentIndex < count {
        let h: CGFloat = {
          if sectionCount == 1, count == 1 {
            // Assuming this is full screen message.
            return cv.bounds.size.height * 0.6
          }
          return currentSection == 0 ? cvWidth : 60
        }()

        let rect = CGRect(x: 0, y: lastFrame.maxY + 1.0, width: cvWidth, height: h)

        let ip = IndexPath(item: currentIndex, section: currentSection)
        let attributes = UICollectionViewLayoutAttributes(forCellWith: ip)

        attributes.frame = rect

        cachedAttributes.append(attributes)
        contentBounds = contentBounds.union(lastFrame)

        currentIndex += 1
        lastFrame = rect
      }

      currentSection += 1
    }

  }

  override var collectionViewContentSize: CGSize {
    return contentBounds.size
  }

  override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
    guard let collectionView = collectionView else { return false }
    return !newBounds.size.equalTo(collectionView.bounds.size)
  }

  override func layoutAttributesForItem(
    at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
    return cachedAttributes[indexPath.item]
  }

  override func layoutAttributesForElements(
    in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
    var attributesArray = [UICollectionViewLayoutAttributes]()

    // Find any cell that sits within the query rect.
    guard let lastIndex = cachedAttributes.indices.last,
      let firstMatchIndex = binSearch(rect, start: 0, end: lastIndex) else {
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

  // Perform a binary search on the cached attributes array.
  func binSearch(_ rect: CGRect, start: Int, end: Int) -> Int? {
    if end < start { return nil }

    let mid = (start + end) / 2
    let attr = cachedAttributes[mid]

    if attr.frame.intersects(rect) {
      return mid
    } else {
      if attr.frame.maxY < rect.minY {
        return binSearch(rect, start: (mid + 1), end: end)
      } else {
        return binSearch(rect, start: start, end: (mid - 1))
      }
    }
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
