//
//  SuggestionCell.swift
//  Podest
//
//  Created by Michael on 4/11/17.
//  Copyright © 2017 Michael Nisi. All rights reserved.
//

import UIKit

final class SuggestionCell: UITableViewCell {
  
  private static func makeLoupe() -> UIImage? {
    guard #available(iOS 13.0, *) else {
      return UIImage(named: "Loupe")
    }
    
    let conf = UIImage.SymbolConfiguration(textStyle: .body)
    
    return UIImage(systemName: "magnifyingglass", withConfiguration: conf)
  }
  
  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    
    initColors()
    
    imageView?.image = SuggestionCell.makeLoupe()
    imageView?.tintColor = UIColor(named: "Secondary")
  }
  
  override func layoutSubviews() {
    defer {
      super.layoutSubviews()
    }
    
    if #available(iOS 13.0, *) { return }
    
    // Manual pixel adjusting is bad for obvious reasons.
    
    if let img = imageView {
      img.frame = CGRect(x: 15, y: 14, width: 17, height: 17)
    }
    
    if let label = textLabel {
      label.frame = label.frame.offsetBy(dx: 0, dy: 0)
    }
  }
}
