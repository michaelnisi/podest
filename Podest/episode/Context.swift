//
//  Context.swift - Episode Context
//  Podest
//
//  Created by Michael Nisi on 25.08.19.
//  Copyright © 2019 Michael Nisi. All rights reserved.
//

import Foundation
import UIKit
import FeedKit

// MARK: - Creating View Controllers

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

// MARK: Identifying Episodes

enum Episode {
  
  class ID: NSObject, NSCopying {
    let entry: Entry 
    
    init(entry: Entry) {
      self.entry = entry
    }
    
    func copy(with zone: NSZone? = nil) -> Any {
      return self
    }
  }
}

// MARK: - Contextual Menu

extension Episode {
  
  @available(iOS 13.0, *)
  private static func makeQueueAction(
    entry: Entry, queue: Queueing) -> UIMenuElement {
    guard queue.contains(entry: entry) else {
      return UIAction(
        title: "Enqueue", 
        image: UIImage(systemName: "plus.circle")
      ) { action in 
        queue.enqueue(entries: [entry], belonging: .user) { enqueued, error in
          //
        }
      }
    }
    
    return UIAction(
      title: "Delete from Queue", 
      image: UIImage(systemName: "trash.circle")
    ) { action in 
      queue.dequeue(entry: entry) { dequeued, error in
        //
      }
    }
  }
  
  @available(iOS 13.0, *)
  private static func makeLibraryAction(
    entry: Entry, 
    library: Subscribing
  ) -> UIMenuElement? {
    guard library.has(subscription: entry.feed) else {
      return nil
    }
    
    return UIAction(
      title: "Unsubscribe", 
      image: UIImage(systemName: "minus.circle")
    ) { action in 
      library.unsubscribe(entry.feed) { error in
        //
      }
    }
  }
  
  @available(iOS 13.0, *)
  static func makeContextConfiguration(
    entry: Entry, 
    navigationDelegate: ViewControllers?, 
    queue: Queueing, 
    library: Subscribing
  ) -> UIContextMenuConfiguration {
    let actionProvider: ([UIMenuElement]) -> UIMenu? = { _ in    
      var children: [UIMenuElement] = [
        UIAction(
          title: "Play", 
          image: UIImage(systemName: "play")
        ) { action in 
          navigationDelegate?.play(entry)
        },
        UIAction(
          title: "Copy", 
          image: UIImage(systemName: "doc.on.doc")
        ) { action in 
          print("copy") 
        },
        UIAction(
          title: "Share", 
          image: UIImage(systemName: "square.and.arrow.up")
        ) { action in 
          print("share") 
        },
        makeQueueAction(entry: entry, queue: queue)
      ]
      
      if let unsubscribing = makeLibraryAction(entry: entry, library: library) {
        children.append(unsubscribing)
      }
      
      return UIMenu(title: entry.title, children: children)
    }
    
    return UIContextMenuConfiguration(
      identifier: Episode.ID(entry: entry), 
      previewProvider: { MakeEpisode.viewController(item: entry) }, 
      actionProvider: actionProvider
    )
  }
}
