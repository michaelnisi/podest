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
    imageView?.image = UIImage(named: "LoupeIcon")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    if let img = imageView {
      img.frame = CGRect(x: 15, y: 14, width: 20, height: 20)
    }
    
    if let label = textLabel {
      label.frame = label.frame.offsetBy(dx: -11, dy: 0)
    }
  }
}
