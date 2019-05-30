//
//  SingleRowLayout.swift
//  Player
//
//  Created by Michael Nisi on 16.05.19.
//  Copyright © 2019 Michael Nisi. All rights reserved.
//

import UIKit

class SingleRowLayout: CustomLayout {
  
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
    let rect = SingleRowLayout.makeRectangle(collectionView: cv)
    
    let width: CGFloat = 200
    let height: CGFloat = 100
    let space: CGFloat = 20
    
    while currentIndex < count {
      let segmentFrame = CGRect(
        x: lastFrame.maxX + space,
        y: rect.origin.y,
        width: width,
        height: height
      )
      
      let segmentRects = [segmentFrame]
      
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
    }
    
    contentBounds = contentBounds.union(lastFrame)
  }
}
