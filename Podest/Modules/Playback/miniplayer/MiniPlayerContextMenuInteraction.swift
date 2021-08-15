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

class MiniPlayerContextMenuInteraction: NSObject {
  private weak var viewController: MiniPlayerViewController?
  private var interaction: UIInteraction?
  private var isInvalidated = false
  private var view: UIView? { viewController?.view }
  var navigationDelegate: ViewControllers? { viewController?.navigationDelegate }
  
  init(viewController: MiniPlayerViewController) {
    self.viewController = viewController
  }
  
  func install() -> MiniPlayerContextMenuInteraction {
    precondition(!isInvalidated)
    
    let interaction = UIContextMenuInteraction(delegate: self)
    
    view?.addInteraction(interaction)
    
    self.interaction = interaction
    
    return self
  }
  
  func invalidate() {
    isInvalidated = true
    
    guard let interaction = self.interaction else {
      return
    }
    
    view?.removeInteraction(interaction)
  }
  
  private func makeActionProvider(entry: Entry) -> UIContextMenuActionProvider {
    { [weak self] suggestedActions in
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
}

// MARK: - UIContextMenuInteractionDelegate

extension MiniPlayerContextMenuInteraction: UIContextMenuInteractionDelegate {
  func contextMenuInteraction(
    _ interaction: UIContextMenuInteraction, 
    configurationForMenuAtLocation location: CGPoint
  ) -> UIContextMenuConfiguration? {
    guard let entry = viewController?.entry else {
      return nil
    }
    
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
      self?.viewController?.showPlayer()
    }
  }
}
