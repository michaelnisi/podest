//
//  UpNextViewController.swift
//  Player
//
//  Created by Michael Nisi on 16.05.19.
//  Copyright © 2019 Michael Nisi. All rights reserved.
//

import UIKit
import os.log

private let log = OSLog(subsystem: "ink.codes.podest", category: "player")

class UpNextViewController: UICollectionViewController {
  
  let dataSource = UpNextDataSource()
  
  deinit {
    os_log("** deinit", log: log, type: .info)
  }
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
