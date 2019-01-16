//
//  StoreLayout.swift
//  Podest
//
//  Created by Michael Nisi on 13.01.19.
//  Copyright © 2019 Michael Nisi. All rights reserved.
//

import UIKit

private extension CGRect {

  func dividedIntegral(
    fraction: CGFloat, from fromEdge: CGRectEdge
  ) -> (first: CGRect, second: CGRect) {
    let dimension: CGFloat

    switch fromEdge {
    case .minXEdge, .maxXEdge:
      dimension = self.size.width
    case .minYEdge, .maxYEdge:
      dimension = self.size.height
    }

    let distance = (dimension * fraction).rounded(.up)
    var slices = self.divided(atDistance: distance, from: fromEdge)

    switch fromEdge {
    case .minXEdge, .maxXEdge:
      slices.remainder.origin.x += 1
      slices.remainder.size.width -= 1
    case .minYEdge, .maxYEdge:
      slices.remainder.origin.y += 1
      slices.remainder.size.height -= 1
    }

    return (first: slices.slice, second: slices.remainder)
  }

}

/// Single section layout for the in-app store.
final class StoreLayout: UICollectionViewLayout {

  private enum SegmentStyle {
    case full
    case fullWidth
    case twoThirdsOneThird
    case oneThirdTwoThirds

    init(collectionView: UICollectionView, numberOfItems: Int) {
      guard numberOfItems != 1 else {
        self = .full
        return
      }

      let traits = collectionView.traitCollection

      guard traits.horizontalSizeClass == .regular,
        traits.verticalSizeClass == .regular else {
        self = .fullWidth
        return
      }

      self = .twoThirdsOneThird
    }
  }

  /// The combined attributes frame.
  private var contentBounds = CGRect.zero

  /// The attributes cache.
  private var cachedAttributes = [UICollectionViewLayoutAttributes]()

  override func prepare() {
    super.prepare()

    guard let cv = collectionView else { return }

    precondition(cv.numberOfSections == 1)

    // Reset cached information.
    cachedAttributes.removeAll()
    contentBounds = CGRect(origin: .zero, size: cv.bounds.size)

    let count = cv.numberOfItems(inSection: 0)

    var currentIndex = 0
    var segment = SegmentStyle(collectionView: cv, numberOfItems: count)
    var lastFrame: CGRect = .zero

    let cvWidth = cv.bounds.size.width

    while currentIndex < count {
      let segmentFrame = CGRect(x: 0, y: lastFrame.maxY + 1.0, width: cvWidth, height: 200.0)

      var segmentRects = [CGRect]()

      switch segment {
      case .fullWidth:
        segmentRects = [segmentFrame]
      case .oneThirdTwoThirds:
        let s = segmentFrame.dividedIntegral(fraction: 1 / 3, from: .minXEdge)
        segmentRects = [s.first, s.second]
      case .twoThirdsOneThird:
        let s = segmentFrame.dividedIntegral(fraction: 2 / 3, from: .minXEdge)
        segmentRects = [s.first, s.second]
      case .full:
        segmentRects = [segmentFrame]
      }

      // Creating and caching attributes.
      for rect in segmentRects {
        let ip = IndexPath(item: currentIndex, section: 0)
        let attributes = UICollectionViewLayoutAttributes(forCellWith: ip)

        attributes.frame = rect

        cachedAttributes.append(attributes)
        contentBounds = contentBounds.union(lastFrame)

        currentIndex += 1
        lastFrame = rect
      }

      // Picking the next segment style.

      switch segment {
      case .fullWidth:
        segment = .fullWidth
      case .twoThirdsOneThird:
        segment = .oneThirdTwoThirds
      case .oneThirdTwoThirds:
        segment = .twoThirdsOneThird
      case .full:
        segment = .fullWidth
      }

    }

    // Not withholding the last frame.

    contentBounds = contentBounds.union(lastFrame)
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
      let firstMatchIndex = StoreLayout.firstIntersectingIndex(
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
