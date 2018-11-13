//
//  StoreButton.swift
//  Podest
//
//  Created by Michael Nisi on 17.04.18.
//  Copyright © 2018 Michael Nisi. All rights reserved.
//

import UIKit

@IBDesignable
class StoreButton: UIButton {

    /*
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        // Drawing code
    }
    */
  
  @IBInspectable var cornerRadius: CGFloat {
    get {
      return layer.cornerRadius
    }
    set {
      layer.cornerRadius = newValue
      layer.masksToBounds = newValue > 0
    }
  }
  
}

