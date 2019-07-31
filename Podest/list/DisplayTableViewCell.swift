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
