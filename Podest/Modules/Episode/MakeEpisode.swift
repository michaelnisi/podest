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

/// Creates episode view controllers configured with `EntryLocator` or `Entry`.
struct MakeEpisode<Item> {
  private static func instantiateViewController(
    navigationDelegate: ViewControllers? = nil) -> EpisodeViewController {
    let storyboard = UIStoryboard(name: "Episode", bundle: .main)
    
    guard let vc = storyboard.instantiateViewController(
      withIdentifier: "EpisodeID") as? EpisodeViewController else {
      fatalError("missing view controller")
    }
    
    vc.navigationDelegate = navigationDelegate
    
    return vc
  }
}

extension MakeEpisode where Item == Entry {
  static func viewController(
    item: Item, 
    navigationDelegate: ViewControllers? = nil
  ) -> EpisodeViewController {  
    let vc = instantiateViewController(navigationDelegate: navigationDelegate)
    vc.entry = item

    return vc
  }
}

extension MakeEpisode where Item == EntryLocator {
  static func viewController(
    item: Item, 
    navigationDelegate: ViewControllers? = nil
  ) -> EpisodeViewController {
    let vc = instantiateViewController(navigationDelegate: navigationDelegate)
    vc.locator = item

    return vc
  }
}
