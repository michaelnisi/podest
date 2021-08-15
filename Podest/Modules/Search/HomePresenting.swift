//===----------------------------------------------------------------------===//
//
// This source file is part of the Podest open source project
//
// Copyright (c) 2021 Michael Nisi and collaborators
// Licensed under MIT License
//
// See https://github.com/michaelnisi/podest/blob/main/LICENSE for license information
//
//===----------------------------------------------------------------------===//

import Foundation
import UIKit

/// Presents a home screen, something like Safari’s Favourites.
protocol HomePresenting {
  
  /// The target table view controller for adding Home to.
  var targetController: UITableViewController { get }
  
  /// Adds Home to target view controller.
  func addHome()
  
  /// Removes Home from target view controller.
  func removeHome()
}

extension HomePresenting {
  
  private var home: UIViewController? {
    guard let home = targetController.children
      .last as? UICollectionViewController else {
      return nil
    }
    
    return home
  }
  
  private var isShowingHome: Bool {
     home != nil
  }
}

// MARK: - HomePresenting

extension HomePresenting {
    
  func addHome() {
    guard !isShowingHome else {
      return
    }
    
    let storyboard = UIStoryboard(name: "Home", bundle: .main)
    let vc = storyboard.instantiateViewController(withIdentifier: "HomeID")
      
    let transition: CATransition = CATransition()
    transition.duration = 0.3
    transition.type = .fade
    
    targetController.view.layer.add(transition, forKey: nil)
    targetController.view.addSubview(vc.view)
    targetController.addChild(vc)
  }
  
  func removeHome() {
    targetController.tableView.scrollToRow(
      at: IndexPath(row: 0, section: 0), at: .top, animated: false)
    
    home?.willMove(toParent: nil)
    home?.view.removeFromSuperview()
    home?.removeFromParent()
  }
}
