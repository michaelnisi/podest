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
  
  private func loadImage(for item: Imaginable) -> UITableViewCell {
    // Setting default image to prevent preloading of a smaller placeholder
    // image. We have to be quick here.

    thumbImageView.image = FKImageCell.defaultImage

    Podest.images.loadImage(for: item, into: thumbImageView, quality: .medium)

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

