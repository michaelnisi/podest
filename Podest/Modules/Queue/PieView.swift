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

/// Originally designed for indicating playback progression state in collection
/// cells, now turned into a simple dot or no dot for unplayed and played.
class PieLayer: CAShapeLayer {
  
  @NSManaged var percentage: CGFloat
  
  private func _init() {
    fillColor = UIColor(named: "Purple")!.cgColor
  }
  
  override init() {
    super.init()
    _init()
  }
  
  override init(layer: Any) {
    super.init(layer: layer)
    
    if let layer = layer as? PieLayer {
      percentage = layer.percentage
      _init()
    }
  }
  
  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    _init()
  }
  
  override func draw(in ctx: CGContext) {
    if percentage != 0 {
      ctx.setFillColor(fillColor!)
      ctx.fillEllipse(in: CGRect(x: 6, y: 0, width: 12, height: 12))
    }
  }
  
  override class func needsDisplay(forKey key: String) -> Bool {
    if key == "percentage" {
      return true
    }
    
    return super.needsDisplay(forKey: key)
  }
}

class PieView: UIView {
  
  override class var layerClass: AnyClass {
    return PieLayer.self
  }
  
  var percentage: CGFloat {
    set { (self.layer as? PieLayer)?.percentage = newValue }
    get { return (self.layer as? PieLayer)?.percentage ?? 0.0 }
  }
  
  override func draw(_ layer: CALayer, in ctx: CGContext) {
    (layer.presentation() as? PieLayer)?.draw(in: ctx)
  }
}
