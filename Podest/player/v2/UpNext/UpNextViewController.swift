//
//  UpNextViewController.swift
//  Player
//
//  Created by Michael Nisi on 16.05.19.
//  Copyright © 2019 Michael Nisi. All rights reserved.
//

import UIKit

class UpNextViewController: UICollectionViewController {
  
  let dataSource = UpNextDataSource()
}

// MARK: - UIViewController

extension UpNextViewController {
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    dataSource.registerCells(collectionView: collectionView)
    
    collectionView.dataSource = dataSource
    collectionView.collectionViewLayout = SingleRowLayout()
  }
}
