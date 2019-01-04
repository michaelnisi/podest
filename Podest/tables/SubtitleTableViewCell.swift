//
//  SubtitleTableViewCell.swift
//  Podest
//
//  Created by Michael Nisi on 30.12.18.
//  Copyright © 2018 Michael Nisi. All rights reserved.
//

import UIKit
import FeedKit

class SubtitleTableViewCell: UITableViewCell {

  var images: Images?

  var item: Imaginable? {
    willSet {
      guard let view = imageView else {
        return
      }

      images?.cancel(displaying: view)
    }
  }

  var imageQuality: ImageQuality = .medium

  override func layoutSubviews() {
    super.layoutSubviews()

    guard let view = imageView, let item = self.item else {
      return
    }

    // Needing the image size, before loading it.
    
    images?.loadImage(
      representing: item,
      into: view,
      options: FKImageLoadingOptions(
        fallbackImage: UIImage(named: "Oval"),
        quality: imageQuality,
        isDirect: true
      )
    )
  }

}
