//
//  ControlsCell.swift
//  Player
//
//  Created by Michael Nisi on 11.05.19.
//  Copyright © 2019 Michael Nisi. All rights reserved.
//

import UIKit

/// Adopt this protocol for receiving events from playback controls.
///
/// Delegation is an alternative pattern to using a view controller for this
/// cell, like we do for the other *fat* cells in this collection.
protocol PlaybackControlsDelegate: class {
  func track(_ track: UISlider, changed value: Float)
}

class ControlsCell: UICollectionViewCell {    
  @IBOutlet weak var titleButton: UIButton!
  @IBOutlet weak var subtitleLabel: UILabel!
  @IBOutlet weak var trackSlider: UISlider!
  
  /// Receives events from this cell.
  weak var delegate: PlaybackControlsDelegate?
  
  @objc func trackSliderChange(slider: UISlider) {
    delegate?.track(slider, changed: slider.value)
  }
  
  override func awakeFromNib() {
    super.awakeFromNib()
    // Initialization code
    
    titleButton.titleLabel?.numberOfLines = 3
    titleButton.titleLabel?.textAlignment = .center
    
    trackSlider.addTarget(self, action: #selector(trackSliderChange), for: .valueChanged)
  }
}
