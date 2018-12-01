//
//  FKImageCell.swift
//  Podest
//
//  Created by Michael on 4/11/17.
//  Copyright © 2017 Michael Nisi. All rights reserved.
//

import UIKit
import FeedKit
import os.log

final class FKImageCell: FKTextCell {
  
  @IBOutlet var thumbImageView: UIImageView!
  
  // Default image for resetting.
  private static var defaultImage: UIImage!

  private func resetImage() {
    thumbImageView.image = FKImageCell.defaultImage
  }
  
  private func loadImage(for item: Imaginable) -> UITableViewCell {
    resetImage()

    Podest.images.loadImage(
      representing: item,
      into: thumbImageView,
      options: FKImageLoadingOptions(
        fallbackImage: FKImageCell.defaultImage,
        quality: .medium,
        isDirect: true
      )
    )

    return self
  }
  
  // MARK: - UITableViewCell

  @discardableResult
  override public func configure(with entry: Entry) -> UITableViewCell {
    guard tag != entry.hashValue else {
      return self
    }

    super.configure(with: entry)

    return loadImage(for: entry)
  }
  
  @discardableResult
  override public func configure(with feed: Feed) -> UITableViewCell {
    guard tag != feed.hashValue else {
      return self
    }

    super.configure(with: feed)
    
    return loadImage(for: feed)
  }
  
}

// MARK: - NSObject

extension FKImageCell {
  
  override func awakeFromNib() {
    super.awakeFromNib()

    // Snatching the default image from IB.

    FKImageCell.defaultImage = thumbImageView.image
  }
  
}

