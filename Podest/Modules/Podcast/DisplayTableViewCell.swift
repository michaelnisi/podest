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

  /// The layout block runs once after layout before it’s dismissed.
  var layoutSubviewsBlock: ((UIImageView) -> Void)?
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    guard let largeImageView = self.largeImageView else {
      return
    }
    
    layoutSubviewsBlock?(largeImageView)
    
    layoutSubviewsBlock = nil
  }
  
  func invalidate(image: UIImage?) {
    layoutSubviewsBlock = nil
    largeImageView.image = image
  }
}
