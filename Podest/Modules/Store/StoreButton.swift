//
//  StoreButton.swift
//  Podest
//
//  Created by Michael Nisi on 17.04.18.
//  Copyright © 2018 Michael Nisi. All rights reserved.
//

import UIKit

/// A button with rounded corners.
@IBDesignable
class StoreButton: UIButton {

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

