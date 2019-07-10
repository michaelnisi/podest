//
//  SubtitleTableViewCell.swift
//  Podest
//
//  Created by Michael Nisi on 30.12.18.
//  Copyright © 2018 Michael Nisi. All rights reserved.
//

import UIKit
import FeedKit

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
