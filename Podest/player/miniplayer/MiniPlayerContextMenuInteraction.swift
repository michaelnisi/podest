//
//  MiniPlayerContextMenuInteraction.swift
//  Podest
//
//  Created by Michael Nisi on 20.03.20.
//  Copyright © 2020 Michael Nisi. All rights reserved.
//

import Foundation
import UIKit
import FeedKit

@available(iOS 13.0, *)
class MiniPlayerContextMenuInteraction: NSObject { 
  
  private let entry: Entry
  private weak var view: UIView?
  
  init(view: UIView, entry: Entry) {
    self.view = view
    self.entry = entry
  }
  
  private var interaction: UIInteraction?
  
  func install() {
    precondition(!isInvalidated)
    
    let interaction = UIContextMenuInteraction(delegate: self)
    
    view?.addInteraction(interaction)
    
    self.interaction = interaction
  }
  
  private var isInvalidated = false
  
  func invalidate() {
    isInvalidated = true
    
    guard let interaction = self.interaction else {
      return
    }
    
    view?.removeInteraction(interaction)
  }
  
  private func makeActionProvider(entry: Entry) -> UIContextMenuActionProvider {
    return { [weak self] suggestedActions in
      var children = Array<UIMenuElement>()
      
      if let link = EpisodeContext.makeLinkAction(entry: entry) {
        children.append(link)
      }
      
      if entry != self?.navigationDelegate?.entry {
        children.append(EpisodeContext.makeShowEpisodeAction(
          entry: entry, navigationDelegate: self?.navigationDelegate
        ))
      }
      
      if entry.feed != self?.navigationDelegate?.feed?.url {
        children.append(EpisodeContext.makeShowPodcastAction(
          entry: entry, navigationDelegate: self?.navigationDelegate
        ))
      }

      if !(self?.navigationDelegate?.isQueueVisible ?? false) {
        children.append(UIAction(
          title: "Show Queue", 
          image: UIImage(systemName: "house")) { action in
            self?.navigationDelegate?.showQueue()
        })
      }
      
      return UIMenu(
        title: entry.feedTitle ?? entry.title, 
        children: children.reversed()
      )
    }
  }

  func installContextMenuInteraction() {
    let interaction = UIContextMenuInteraction(delegate: self)
    
    view?.addInteraction(interaction)
  }
  
  var navigationDelegate: ViewControllers?
}

// MARK: - UIContextMenuInteractionDelegate

@available(iOS 13.0, *)
extension MiniPlayerContextMenuInteraction: UIContextMenuInteractionDelegate {
  
  func contextMenuInteraction(
    _ interaction: UIContextMenuInteraction, 
    configurationForMenuAtLocation location: CGPoint
  ) -> UIContextMenuConfiguration? {
    return UIContextMenuConfiguration(
      identifier: nil, 
      previewProvider: nil, 
      actionProvider: makeActionProvider(entry: entry)
    )
  }
  
  func contextMenuInteraction(
    _ interaction: UIContextMenuInteraction, 
    willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration, 
    animator: UIContextMenuInteractionCommitAnimating) {
    animator.addCompletion { [weak self] in
      guard let entry = self?.entry else {
        return
      }
      
      self?.navigationDelegate?.showNowPlaying(
        entry: entry, animated: true, completion: nil)
    }
  }
}
