//
//  PlayerDataSource.swift
//  Player
//
//  Created by Michael Nisi on 10.05.19.
//  Copyright © 2019 Michael Nisi. All rights reserved.
//

import UIKit

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
      
      cell.titleButton.setTitle("Carregando a Vida Atrás das Costas an immediacy that’s shared with the best of DJ Marfox or Nídia", for: .normal)
      
      cell.subtitleLabel.text = "Reply All"
      
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
