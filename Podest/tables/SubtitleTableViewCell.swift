//
//  SubtitleTableViewCell.swift
//  Podest
//
//  Created by Michael Nisi on 30.12.18.
//  Copyright © 2018 Michael Nisi. All rights reserved.
//

import UIKit

final class SubtitleTableViewCell: UITableViewCell {
  
  /// The layout block runs once after layout before it’s dismissed.
  var layoutSubviewsBlock: ((UIImageView) -> Void)?
  
  override func layoutSubviews() {
    super.layoutSubviews()

    guard let imageView = self.imageView else {
      return
    }

    layoutSubviewsBlock?(imageView)
    
    layoutSubviewsBlock = nil
  }
  
  func invalidate(image: UIImage?) {
    layoutSubviewsBlock = nil
    imageView?.image = image
  }
}
