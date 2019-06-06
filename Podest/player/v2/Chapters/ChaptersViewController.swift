//
//  ChaptersViewController.swift
//  Player
//
//  Created by Michael Nisi on 15.05.19.
//  Copyright © 2019 Michael Nisi. All rights reserved.
//

import UIKit
import os.log

private let log = OSLog(subsystem: "ink.codes.podest", category: "player")

class ChaptersViewController: UICollectionViewController {
  
  let dataSource = ChaptersDataSource()
  
  deinit {
    os_log("** deinit", log: log, type: .debug)
  }
}

// MARK: - UIViewController

extension ChaptersViewController {
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    dataSource.registerCells(collectionView: collectionView)
    
    collectionView.dataSource = dataSource
    collectionView.collectionViewLayout = SingleRowLayout()
  }
}
