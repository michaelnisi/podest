//
//  HomePresenting.swift
//  Podest
//
//  Created by Michael Nisi on 17.08.19.
//  Copyright © 2019 Michael Nisi. All rights reserved.
//

import Foundation
import UIKit

/// Presents a home screen, something like Safari’s Favourites.
protocol HomePresenting {
  var targetController: UIViewController? { get }
  
  func showHome()
  func removeHome()
}

/// NOP defaults.
extension HomePresenting {
  var targetController: UIViewController? { nil }
  
  func showHome() {}
  func removeHome() {}
} 

/* 🚧
extension HomePresenting {
  
  var home: UIViewController? {
    guard let home = targetController?.children
      .last as? UICollectionViewController else {
      return nil
    }
    
    return home
  }
  
  var isShowingHome: Bool {
     home != nil
  }
  
  func showHome() {
    guard !isShowingHome else {
      return
    }
    
    let storyboard = UIStoryboard(name: "Home", bundle: .main)
    let vc = storyboard.instantiateViewController(withIdentifier: "HomeID")
    
    let transition: CATransition = CATransition()
    transition.duration = 0.3
    transition.type = .fade

    targetController?.view.layer.add(transition, forKey: nil)
    targetController?.view.addSubview(vc.view)
    targetController?.addChild(vc)
  }
  
  func removeHome() {
    home?.view.removeFromSuperview()
    home?.removeFromParent()
  }
}
 */
