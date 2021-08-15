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
import Podcasts

@available(iOS 13.0, *)
struct EpisodeContext {
  
   static func makeQueueAction(
    entry: Entry, queue: Dequeueing, view: UIView) -> UIMenuElement {
     guard queue.isEnqueued(entry: entry) else {
       return UIAction(
         title: "Add", 
         image: UIImage(systemName: "plus")
       ) { action in 
         queue.enqueue(entry: entry)
       }
     }
     
     return UIAction(
       title: "Delete", 
       image: UIImage(systemName: "trash"),
       attributes: .destructive    
     ) { action in 
       queue.dequeue(entry: entry, sourceView: view)
     }
   }
  
  static func makeLibraryAction(
    entry: Entry, library: Unsubscribing, view: UIView) -> UIMenuElement? {
    guard library.has(url: entry.feed) else {
      return nil
    }
    
    return UIAction(
      title: "Unsubscribe", 
      image: UIImage(systemName: "text.badge.minus"),
      attributes: .destructive
    ) { action in 
      library.unsubscribe(title: entry.feedTitle ?? entry.title, url: entry.feed, sourceView: view)
    }
  }
  
  static func makeShowPodcastAction(
    entry: Entry, navigationDelegate: ViewControllers?) -> UIMenuElement {
    return UIAction(
      title: "Show Podcast", 
      image: UIImage(systemName: "list.bullet")
    ) { action in
      navigationDelegate?.openFeed(url: entry.feed, animated: true)
    }
  }
  
  static func makeShowEpisodeAction(
    entry: Entry, navigationDelegate: ViewControllers?) -> UIMenuElement {
    return UIAction(
        title: "Show Episode", 
        image: UIImage(systemName: "doc")) { action in
          navigationDelegate?.show(entry: entry)
    }
  }
  
  static func makePlayAction(
    entry: Entry, navigationDelegate: ViewControllers?) -> UIMenuElement {
    return UIAction(
      title: "Play", 
      image: UIImage(systemName: "play.fill")
    ) { action in 
      Podcasts.player.setItem(matching: EntryLocator(entry: entry))
    }
  }
  
  static func makeLinkAction(entry: Entry) -> UIMenuElement? {
    guard let link = entry.link, let url = URL(string: link) else {
      return nil
    }
    
    return UIAction(
      title: "Open Link", 
      image: UIImage(systemName: "square.and.arrow.up")) { action in
        UIApplication.shared.open(url)
    }
  }

  static func makeContextConfiguration(
    entry: Entry, 
    navigationDelegate: ViewControllers?, 
    queue: Dequeueing, 
    library: Unsubscribing,
    view: UIView?,
    isShowPodcastRequired: Bool = true
  ) -> UIContextMenuConfiguration {
    let actionProvider: ([UIMenuElement]) -> UIMenu? = { _ in    
      var children: [UIMenuElement] = [
        makePlayAction(entry: entry, navigationDelegate: navigationDelegate)
      ]
      
      if isShowPodcastRequired {
        children.append(makeShowPodcastAction(
          entry: entry, navigationDelegate: navigationDelegate
        ))
      }
      
      if let view = view {
        children.append(makeQueueAction(entry: entry, queue: queue, view: view))
        
        if let unsubscribe = makeLibraryAction(entry: entry, library: library, view: view) {
          children.append(unsubscribe)
        }
      }
      
      return UIMenu(title: entry.title, children: children)
    }
     
     return UIContextMenuConfiguration(
       identifier: entry.guid as NSCopying, 
       previewProvider: { MakeEpisode.viewController(item: entry) }, 
       actionProvider: actionProvider
     )
   }
}
