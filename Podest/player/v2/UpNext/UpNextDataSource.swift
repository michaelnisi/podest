//
//  UpNextDataSource.swift
//  Player
//
//  Created by Michael Nisi on 14.05.19.
//  Copyright © 2019 Michael Nisi. All rights reserved.
//

import UIKit

class UpNextDataSource: NSObject {
  
  typealias Item = String
  var sections: [[Item]] = [[
    "Another One", 
    "Another Two", 
    "Another Three", 
    "Another Four",
    "Another Five",
    "Another Six",
    "Another Seven",
    "Another Eight",
    "Another Nine",
    "Another Ten"
    ]]
}

extension UpNextDataSource {
  
  func registerCells(collectionView: UICollectionView) {
    collectionView.register(
      UINib(nibName: "ChapterCell", bundle: .main), 
      forCellWithReuseIdentifier: "ChapterCellID"
    )
  }
}

extension UpNextDataSource: UICollectionViewDataSource {
  
  func collectionView(
    _ collectionView: UICollectionView, 
    numberOfItemsInSection section: Int) -> Int {
    return sections[section].count
  }
  
  func collectionView(
    _ collectionView: UICollectionView, 
    cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    let item = sections[indexPath.section][indexPath.row]
    let cell = collectionView.dequeueReusableCell(
      withReuseIdentifier: "ChapterCellID", for: indexPath) as! ChapterCell
    
    cell.titleLabel.text = item
    
    return cell
  }
}
