//
//  ListContextMenuInteraction.swift
//  Podest
//
//  Created by Michael Nisi on 21.03.20.
//  Copyright © 2020 Michael Nisi. All rights reserved.
//

import Foundation
import UIKit
import FeedKit

@available(iOS 13.0, *)
class ListContextMenuInteraction: NSObject {
  
  private let entry: Entry
  private weak var view: UIView?
  private var viewController: (Unsubscribing & Navigator)?
  
  init(view: UIView, entry: Entry, viewController: (Unsubscribing & Navigator)?) {
    self.view = view
    self.entry = entry
    self.viewController = viewController
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
    
    view = nil
    viewController = nil
  }
  
  private func makePreviewProvider(entry: Entry) -> UIContextMenuContentPreviewProvider  {
    return {
      let viewController = ListViewController()
      viewController.url = entry.feed
      
      return viewController
    }
  }
  
  private func makeActionProvider(entry: Entry) -> UIContextMenuActionProvider? {
    guard viewController?.has(url: entry.feed) ?? false, 
      let title = entry.feedTitle, 
      let view = view else {
      return nil
    }
    
    return { [weak self] suggestedActions in
      let children = [UIAction(
          title: "Unsubscribe", 
          image: UIImage(systemName: "text.badge.minus"), 
          attributes: .destructive) { action in
            self?.viewController?.unsubscribe(title: title, url: entry.feed, sourceView: view)
          }
      ]
    
      return UIMenu(title: title, children: children)
    }
  }
}

// MARK: - UIContextMenuInteractionDelegate

@available(iOS 13.0, *)
extension ListContextMenuInteraction: UIContextMenuInteractionDelegate {
   
   func contextMenuInteraction(
     _ interaction: UIContextMenuInteraction, 
     configurationForMenuAtLocation location: CGPoint
   ) -> UIContextMenuConfiguration? {
    
     return UIContextMenuConfiguration(
       identifier: nil, 
       previewProvider: makePreviewProvider(entry: entry),
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
      
      self?.viewController?.navigationDelegate?.openFeed(url: entry.feed, animated: false)
    }
  }
}
