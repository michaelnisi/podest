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
    shouldOverrideIsCompact: Bool = false,
    navigationDelegate: ViewControllers? = nil
  ) -> ListViewController {  
    let vc = instantiateViewController(navigationDelegate: navigationDelegate)
    vc.feed = item
    vc.shouldOverrideIsCompact = shouldOverrideIsCompact

    return vc
  }
}
