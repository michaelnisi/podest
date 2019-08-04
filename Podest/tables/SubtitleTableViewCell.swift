//
//  SubtitleTableViewCell.swift
//  Podest
//
//  Created by Michael Nisi on 30.12.18.
//  Copyright © 2018 Michael Nisi. All rights reserved.
//

import UIKit

extension UITableViewCell {
  
  /// Sets label colors working around an issue introduces with Xcode Version 
  /// 11.0 beta 5, where IB label colors stopped adjusting to mode changes.
  func initColors() {
    if #available(iOS 13.0, *) {
      textLabel?.textColor = .label
      detailTextLabel?.textColor = .secondaryLabel
    } else {
      // Use colors set in IB inspector.
    }
  }
}

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
    
  required init?(coder: NSCoder) {
    super.init(coder: coder)
    
    initColors()
  }
}
