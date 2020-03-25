//
//  MakeList.swift
//  Podest
//
//  Created by Michael Nisi on 22.03.20.
//  Copyright © 2020 Michael Nisi. All rights reserved.
//

import Foundation
import UIKit
import FeedKit

struct MakeList<Item> {
  private static func instantiateViewController(
    navigationDelegate: ViewControllers? = nil) -> ListViewController {
    let storyboard = UIStoryboard(name: "List", bundle: .main)
    
    guard let vc = storyboard.instantiateViewController(
      withIdentifier: "EpisodesID") as? ListViewController else {
      fatalError("missing view controller")
    }
    
    vc.navigationDelegate = navigationDelegate
    
    return vc
  }
}

extension MakeList where Item == Feed {
  static func viewController(
    item: Item, 
    navigationDelegate: ViewControllers? = nil
  ) -> ListViewController {  
    let vc = instantiateViewController(navigationDelegate: navigationDelegate)
    vc.feed = item

    return vc
  }
}
