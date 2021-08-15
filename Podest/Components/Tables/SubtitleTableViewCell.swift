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
  
  /// This closure runs once after laying out subviews (before its dismissal).
  var layoutSubviewsBlock: ((UIImageView) -> Void)?
  
  override func layoutSubviews() {
    super.layoutSubviews()

    guard let imageView = self.imageView, imageView.bounds != .zero else {
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
