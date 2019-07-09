//
//  DisplayTableViewCell.swift
//  Podest
//
//  Created by Michael Nisi on 10.01.19.
//  Copyright © 2019 Michael Nisi. All rights reserved.
//

import UIKit
import FeedKit

/// Displays an image and a longer text.
class DisplayTableViewCell: UITableViewCell {

  @IBOutlet weak var largeImageView: UIImageView!
  @IBOutlet weak var textView: UITextView!

  override func awakeFromNib() {
    super.awakeFromNib()

    let x = CGFloat(-5)
    let prev = textView.textContainerInset

    textView.textContainerInset = UIEdgeInsets(
      top: prev.top, left: x, bottom: prev.bottom, right: x)
  }
  
  var images: Images? {
    didSet {
      guard images == nil else {
        largeImageView?.image = DisplayTableViewCell.fallbackImage
        return
      }

      largeImageView?.image = nil
    }
  }

  private var isReset = true

  private static let fallbackImage = UIImage(named: "Oval")

  var item: Imaginable? {
    willSet {
      guard let view = largeImageView, let images = self.images else {
        return
      }

      images.cancel(displaying: view)

      view.image = DisplayTableViewCell.fallbackImage
      isReset = true
    }
  }

  var imageQuality: ImageQuality = .medium

  private var imageSizeLoaded: CGSize?

  override func layoutSubviews() {
    super.layoutSubviews()
    
    // Loading images in the view, instead of in the data source, is 
    // unfortunate, but we need to know the size.

    guard
      let view = largeImageView,
      let item = self.item,
      (isReset || view.bounds.size != imageSizeLoaded) else {
      return
    }

    // Redispatching saves us one redundant loadImage call during animations,
    // but it does not matter really, it would just be hitting the in-memory 
    // cache.

    DispatchQueue.main.async { [weak self] in
      self?.images?.loadImage(
        representing: item,
        into: view,
        options: FKImageLoadingOptions(
          fallbackImage: DisplayTableViewCell.fallbackImage,
          quality: self?.imageQuality ?? .medium,
          isClean: true
        )
      )

      self?.imageSizeLoaded = view.bounds.size
      self?.isReset = false
    }
  }
}
