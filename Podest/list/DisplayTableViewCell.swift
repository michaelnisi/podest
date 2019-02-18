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

    // Tailor-made image loading requires a somewhat stable image size. Checking
    // the image size prevents excessive requests, but might still lead to
    // multiple requests. I’m seeing two at the moment.

    guard let view = largeImageView, let images = images, let item = self.item,
      (isReset || view.bounds.size != imageSizeLoaded) else {
        return
    }

    images.loadImage(
      representing: item,
      into: view,
      options: FKImageLoadingOptions(
        fallbackImage: DisplayTableViewCell.fallbackImage,
        quality: imageQuality,
        isClean: true
      )
    )

    imageSizeLoaded = view.bounds.size
    isReset = false
  }

}
