//
//  ChapterCell.swift
//  Player
//
//  Created by Michael Nisi on 14.05.19.
//  Copyright © 2019 Michael Nisi. All rights reserved.
//

import UIKit

class ChapterCell: UICollectionViewCell {
  
  @IBOutlet weak var titleLabel: UILabel!
  
  override func awakeFromNib() {
    super.awakeFromNib()
    // Initialization code
    
    layer.cornerRadius = 16
    layer.masksToBounds = true
  }
}
