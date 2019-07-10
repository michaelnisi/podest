//
//  PieView.swift
//  Podest
//
//  Created by Michael Nisi on 23.06.19.
//  Copyright © 2019 Michael Nisi. All rights reserved.
//

import Foundation
import UIKit

/// Originally conceived for indicating playback progression state, now boiled
/// down to plain dot or no-dot for unplayed and played. An image would do.
class PieLayer: CAShapeLayer {
  
  var percentage: CGFloat = 0 {
    didSet {
      if percentage != oldValue {
        setNeedsDisplay()
      }
    }
  }
  
  var color: CGColor = UIColor.blue.cgColor {
    didSet {
      if color != oldValue {
        setNeedsDisplay()
      }
    }
  }
  
  override init() {
    super.init()
  }
  
  override init(layer: Any) {
    super.init(layer: layer)
    
    if let layer = layer as? PieLayer {
      percentage = layer.percentage
      color = layer.color
    }
  }
  
  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }
  
  override func draw(in ctx: CGContext) {
    if percentage != 0 {
      ctx.setFillColor(color)
      ctx.fillEllipse(in: CGRect(x: 6, y: 0, width: 12, height: 12))
    }
  }
}

class PieView: UIView {
  
  override class var layerClass: AnyClass {
    return PieLayer.self
  }
  
  var pieLayer: PieLayer {
    return self.layer as! PieLayer
  }
  
  var percentage: CGFloat {
    set { pieLayer.percentage = newValue }
    get { return pieLayer.percentage }
  }
  
  var color: UIColor {
    set {
      if #available(iOS 13.0, *) {
        pieLayer.color = tintColor.resolvedColor(with: traitCollection).cgColor
      } else {
        pieLayer.color = tintColor.cgColor
      }
    }
    
    get { 
      return UIColor(cgColor: pieLayer.color)
    }
  }
}
