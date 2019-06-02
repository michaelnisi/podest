//
//  TwoPlusLayout.swift
//  Podest
//
//  Created by Michael Nisi on 07.04.19.
//  Copyright © 2019 Michael Nisi. All rights reserved.
//

import UIKit

private extension CGRect {

  func dividedIntegral(
    fraction: CGFloat, from fromEdge: CGRectEdge, spacing: CGFloat = 0
    ) -> (first: CGRect, second: CGRect) {
    let dimension: CGFloat

    switch fromEdge {
    case .minXEdge, .maxXEdge:
      dimension = size.width
    case .minYEdge, .maxYEdge:
      dimension = size.height
    }

    let distance = (dimension * fraction).rounded(.up)
    var slices = divided(atDistance: distance, from: fromEdge)

    switch fromEdge {
    case .minXEdge, .maxXEdge:
      slices.remainder.origin.x += spacing
      slices.remainder.size.width -= spacing
    case .minYEdge, .maxYEdge:
      slices.remainder.origin.y += spacing
      slices.remainder.size.height -= spacing
    }

    return (first: slices.slice, second: slices.remainder)
  }
}

/// Single section layout for two initially visible items plus more to scroll.
final class TwoPlusLayout: CustomLayout {

  private enum SegmentStyle {
    case full
    case horizontal
    case vertical
    case fullWidth

    init(collectionView cv: UICollectionView, numberOfItems: Int) {
      guard numberOfItems > 1 else {
        self = .full
        return
      }
      
      let tc = cv.traitCollection
      
      switch (tc.horizontalSizeClass, tc.verticalSizeClass) {
      case (.regular, _):
        self = .horizontal
      case (_, .regular), (_, _):
        self = .vertical
      }
    }
  }

  /// Returns the initial rectangular space for our layout.
  private static 
  func makeRectangle(collectionView cv: UICollectionView) -> CGRect {
    let m = cv.layoutMargins
    let insets = UIEdgeInsets(top: m.top, left: 0, bottom: m.bottom, right: 0)
    
    return cv.bounds.inset(by: insets)
  }

  override func prepare() {
    super.prepare()

    guard let cv = collectionView else { return }

    precondition(cv.numberOfSections == 1)

    cachedAttributes.removeAll()
    contentBounds = CGRect(origin: .zero, size: .zero)

    var currentIndex = 0
    let count = cv.numberOfItems(inSection: 0)

    var lastFrame: CGRect = .zero
    let rect = TwoPlusLayout.makeRectangle(collectionView: cv)

    var segment = SegmentStyle(collectionView: cv, numberOfItems: count)

    while currentIndex < count {
      let segmentFrame = CGRect(
        x: rect.origin.x,
        y: lastFrame.maxY,
        width: rect.width,
        height: min(rect.height, rect.width / 2)
      )

      var segmentRects = [CGRect]()

      switch segment {
      case .vertical:
        let segmentFrame = CGRect(
          x: rect.origin.x,
          y: lastFrame.maxY,
          width: rect.width,
          height: rect.height
        )
        let s = segmentFrame.dividedIntegral(fraction: 0.5, from: .minYEdge)
        segmentRects = [s.first, s.second]
        
      case .horizontal:
        let s = segmentFrame.dividedIntegral(fraction: 0.5, from: .minXEdge)
        segmentRects = [s.first, s.second]
        
      case .full:
        segmentRects = [segmentFrame]
        
      case .fullWidth:
        let segmentFrame = CGRect(
          x: rect.origin.x,
          y: lastFrame.maxY,
          width: rect.width,
          height: 130
        )
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

      switch segment {
      case .vertical, .horizontal, .full, .fullWidth:
        segment = .fullWidth
      }
    }

    // Not withholding the last frame adding some space if we have more than
    // one item.

    contentBounds = contentBounds.union(lastFrame
      .offsetBy(dx: 0, dy: count > 1 ? 60 : 0))
  }
}
