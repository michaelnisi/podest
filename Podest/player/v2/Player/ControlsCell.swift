//
//  ControlsCell.swift
//  Player
//
//  Created by Michael Nisi on 11.05.19.
//  Copyright © 2019 Michael Nisi. All rights reserved.
//

import UIKit

class ControlsCell: UICollectionViewCell {    
  @IBOutlet weak var titleButton: UIButton!
  @IBOutlet weak var subtitleLabel: UILabel!
  @IBOutlet weak var trackSlider: UISlider!
  
  override func awakeFromNib() {
    super.awakeFromNib()
    // Initialization code
    
    titleButton.titleLabel?.numberOfLines = 3
    titleButton.titleLabel?.textAlignment = .center
  }
}
