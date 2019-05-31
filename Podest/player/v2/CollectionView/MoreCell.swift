//
//  MoreCell.swift
//  Player
//
//  Created by Michael Nisi on 16.05.19.
//  Copyright © 2019 Michael Nisi. All rights reserved.
//

import UIKit

/// A container cell managed by its own view controller.
class MoreCell: UICollectionViewCell {
  
  /// Enumerates possible cell types.
  enum Kind {
    case chapters, queue
  }
  
  var type: Kind!
  
  /// Our managing player view controller needs a reference to the container.
  weak var container: UIViewController!
  
  override func awakeFromNib() {
    super.awakeFromNib()
    // Initialization code
  }
}
