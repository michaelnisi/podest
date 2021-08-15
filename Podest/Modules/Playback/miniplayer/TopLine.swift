//===----------------------------------------------------------------------===//
//
// This source file is part of the Podest open source project
//
// Copyright (c) 2021 Michael Nisi and collaborators
// Licensed under MIT License
//
// See https://github.com/michaelnisi/podest/blob/main/LICENSE for license information
//
//===----------------------------------------------------------------------===//

import Foundation
import UIKit

class TopLineLayer: CAShapeLayer {

  override init() {
    super.init()
  }
  
  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }
  
  override init(layer: Any) {
    super.init(layer: layer)
  }
  
  override class func needsDisplay(forKey key: String) -> Bool {
    if (key == "bounds") {
      return true
    }
    
    return super.needsDisplay(forKey: key)
  }
  
  override func draw(in ctx: CGContext) { 
    let start = CGPoint(x: 0, y: 0)
    let end = CGPoint(x: bounds.width, y: 0)
    
    let linePath = UIBezierPath()
    
    linePath.move(to: start)
    linePath.addLine(to: end)
    
    path = linePath.cgPath
    
    opacity = 0.3
    strokeColor = UIColor.lightGray.cgColor
  }
}

class TopLineView: UIView {
  
  override class var layerClass: AnyClass {
    return TopLineLayer.self
  }
  
  override func draw(_ layer: CALayer, in ctx: CGContext) {
    (layer.presentation() as? TopLineLayer)?.draw(in: ctx)
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    layer.setNeedsDisplay()
  }
}
