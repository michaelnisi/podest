//
//  MoreCell.swift
//  Player
//
//  Created by Michael Nisi on 16.05.19.
//  Copyright © 2019 Michael Nisi. All rights reserved.
//

import UIKit

class MoreCell: UICollectionViewCell {
  
  enum Kind {
    case chapters, queue
  }
  
  var type: Kind!
  
  weak var container: UIViewController!
  
  override func awakeFromNib() {
    super.awakeFromNib()
    // Initialization code
  }
}
