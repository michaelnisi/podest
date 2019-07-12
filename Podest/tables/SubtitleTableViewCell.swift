//
//  SubtitleTableViewCell.swift
//  Podest
//
//  Created by Michael Nisi on 30.12.18.
//  Copyright © 2018 Michael Nisi. All rights reserved.
//

import UIKit
import FeedKit

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

final class SubtitleTableViewCell: UITableViewCell {

  var images: Images? {
    didSet {
      guard images == nil else {
        imageView?.image = SubtitleTableViewCell.fallbackImage
        return
      }

      imageView?.image = nil
    }
  }

  private var isReset = true

  private static let fallbackImage = UIImage(named: "Oval")

  var item: Imaginable? {
    willSet {
      guard let view = imageView, let images = self.images else {
        return
      }

      images.cancel(displaying: view)

      view.image = SubtitleTableViewCell.fallbackImage
      isReset = true
    }
  }

  var imageQuality: ImageQuality = .medium

  private var imageSizeLoaded: CGSize?
  
  private func updateAccesoryViewColor() {
    guard let pie = accessoryView as? PieView else {
      return 
    }
    
    pie.color = tintColor
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    
    // Loading images in the view, instead of in the data source, is 
    // unfortunate, but we need to know the size.

    guard
      let view = imageView,
      let images = images,
      let item = self.item,
      (isReset || view.bounds.size != imageSizeLoaded) else {
      return
    }
    
    images.loadImage(
      representing: item,
      into: view,
      options: FKImageLoadingOptions(
        fallbackImage: SubtitleTableViewCell.fallbackImage,
        quality: imageQuality,
        isDirect: true
      )
    )
    
    updateAccesoryViewColor()
    
    imageSizeLoaded = view.bounds.size
    isReset = false
  }
  
  override func tintColorDidChange() {
    updateAccesoryViewColor()
  }
}
