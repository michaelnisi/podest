//
//  SuggestionCell.swift
//  Podest
//
//  Created by Michael on 4/11/17.
//  Copyright © 2017 Michael Nisi. All rights reserved.
//

import UIKit

final class SuggestionCell: UITableViewCell {

  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    
    imageView?.image = UIImage(named: "Loupe")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    // Manual pixel adjusting is bad for obvious reasons.
    
    if let img = imageView {
      img.frame = CGRect(x: 15, y: 14, width: 17, height: 17)
    }
    
    if let label = textLabel {
      label.frame = label.frame.offsetBy(dx: 0, dy: 0)
    }
  }
}
