//
//  PlayerDataSource.swift
//  Player
//
//  Created by Michael Nisi on 10.05.19.
//  Copyright © 2019 Michael Nisi. All rights reserved.
//

import UIKit
import os.log

private let log = OSLog(subsystem: "ink.codes.podest", category: "player")

/// A conventional named nib.
private struct NamedNib {
  let nib: UINib
  let reuseIdentifier: String
  
  init(named name: String) {
    let nibName = name.appending("Cell")
    nib = UINib(nibName: nibName, bundle: .main)
    reuseIdentifier = nibName.appending("ID")
  }
}

class PlayerDataSource: NSObject {
  
  private enum Item {
    case hero
    case controls
    case nextInQueue
    case moreFromThisFeed
    case message
  }
  
  struct Data: Codable {
    let title: String
    let more: [Data]
  }
  
  private var sections: [[Item]] = [
    [.hero, .controls, .moreFromThisFeed, .nextInQueue]
  ]
  
  func use(data: Data) {
    // TODO: Update sections and submit changesBlock
  }
}

// MARK: - Receiving Target Actions

extension PlayerDataSource {
  
  @objc func trackSliderChange(slider: UISlider) {
    os_log("track slider change: %f", log: log, type: .debug, slider.value)
  }
}

// MARK: - UICollectionViewDataSource

extension PlayerDataSource: UICollectionViewDataSource {
  
  func registerCells(collectionView cv: UICollectionView) {
    for name in ["Hero", "Controls", "More"] {
      let nib = NamedNib(named: name)
      cv.register(nib.nib, forCellWithReuseIdentifier: nib.reuseIdentifier)
    }
  }
  
  func collectionView(
    _ collectionView: UICollectionView, 
    numberOfItemsInSection section: Int
  ) -> Int {
    return sections[section].count
  }
  
  func collectionView(
    _ collectionView: UICollectionView, 
    cellForItemAt indexPath: IndexPath
  ) -> UICollectionViewCell {
    let item = sections[indexPath.section][indexPath.row]
    
    switch item {
    case .hero:
      let cell = collectionView.dequeueReusableCell(
        withReuseIdentifier: "HeroCellID", for: indexPath) as! HeroCell
      
      cell.imageView.image = UIImage(named: "Dummy")
      
      return cell
      
    case .controls:
      let cell = collectionView.dequeueReusableCell(
        withReuseIdentifier: "ControlsCellID", for: indexPath) as! ControlsCell
      
      cell.subtitleLabel.text = "Reply All"
      
      cell.titleButton.setTitle("#140 The Roman Mars Mazda Virus", for: .normal)
      cell.trackSlider.addTarget(
        self, action: #selector(trackSliderChange), for: .valueChanged)
      
      return cell
      
    case .moreFromThisFeed:
      let cell = collectionView.dequeueReusableCell(
        withReuseIdentifier: "MoreCellID", for: indexPath) as! MoreCell
      
      cell.type = .chapters
      
      return cell
      
    case .message:
       fatalError("not implemented yet")
      
    case .nextInQueue:
      let cell = collectionView.dequeueReusableCell(
        withReuseIdentifier: "MoreCellID", for: indexPath) as! MoreCell
      
      cell.type = .queue
      
      return cell
    }
  }
}
