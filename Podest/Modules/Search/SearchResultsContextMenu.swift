//
//  SearchResultsContextMenu.swift
//  Podest
//
//  Created by Michael Nisi on 21.03.20.
//  Copyright © 2020 Michael Nisi. All rights reserved.
//

import Foundation
import UIKit
import FeedKit
import Podcasts

@available(iOS 13.0, *)
extension SearchResultsController: Dequeueing {
  
  private func makePreviewProvider(
    indexPath: IndexPath) -> UIContextMenuContentPreviewProvider? {
    return { [weak self] in
      guard let find = self?.dataSource.findAt(indexPath: indexPath) else {
        return nil
      }
      
      switch find {
      case .foundFeed(let feed), 
           .recentSearch(let feed), 
           .suggestedFeed(let feed):
        return MakeList.viewController(
          item: feed, 
          shouldOverrideIsCompact: true,
          navigationDelegate: self?.delegate?.navigationDelegate
        )
        
      case .suggestedEntry(let entry):
        return MakeEpisode.viewController(
          item: entry, 
          navigationDelegate: self?.delegate?.navigationDelegate
        )
      
      case .suggestedTerm:
        return nil
      }
    }
  }
  
  private func makeEntryMenu(entry: Entry, sourceView: UIView) -> UIMenu {
    func makeToggleQueueAction() -> UIAction {
      guard self.isEnqueued(entry: entry) else {
        return UIAction(
          title: "Add", 
          image: UIImage(systemName: "plus")) { 
            action in
          Podcasts.userQueue.enqueue(
              entries: [entry], belonging: .user, enqueueCompletionBlock: nil)
          }
      }
      
      return UIAction(
        title: "Delete", 
        image: UIImage(systemName: "trash"), 
        attributes: .destructive) { [weak self] action in
          self?.dequeue(entry: entry, sourceView: sourceView)
        }
    }
    
    let children = [
      makeToggleQueueAction()
    ]
    
    return UIMenu(title: entry.title, children: children)
  }
  
  private func makeFeedMenu(feed: Feed, sourceView: UIView) -> UIMenu {
    func makeToggleSubscriptionAction() -> UIAction {
      guard Podcasts.userLibrary.has(subscription: feed.url) else {
        return UIAction(
          title: "Subscribe", 
          image: UIImage(systemName: "text.badge.plus")) { 
            action in
          Podcasts.userLibrary.subscribe(feed, completionHandler: nil)
          }
      }
      
      return UIAction(
        title: "Unsubscribe", 
        image: UIImage(systemName: "text.badge.minus"), 
        attributes: .destructive) { [weak self] action in
          self?.unsubscribe(title: feed.title, url: feed.url, sourceView: sourceView)
        }
    }
    
    let children = [
      makeToggleSubscriptionAction()
    ]
    
    return UIMenu(title: feed.title, children: children)
  }
  
  private func makeActionProvider(
    tableView: UITableView, indexPath: IndexPath) -> UIContextMenuActionProvider {    
    return { [weak self] suggestedActions in
      guard let find = self?.dataSource.findAt(indexPath: indexPath), 
        let sourceView = tableView.cellForRow(at: indexPath) else {
        return nil
      }
      
      switch find {
      case .foundFeed(let feed), 
           .recentSearch(let feed), 
           .suggestedFeed(let feed):
        return self?.makeFeedMenu(feed: feed, sourceView: sourceView)
        
      case .suggestedEntry(let entry):
        return self?.makeEntryMenu(entry: entry, sourceView: sourceView)
        
      case .suggestedTerm:
        return nil
      }
    }
  }
  
  override func tableView(
    _ tableView: UITableView, 
    contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint
  ) -> UIContextMenuConfiguration? {
    return UIContextMenuConfiguration(
      identifier: nil, 
      previewProvider: makePreviewProvider(indexPath: indexPath),
      actionProvider: makeActionProvider(tableView: tableView, indexPath: indexPath)
    )
  }
  
  override func tableView(
    _ tableView: UITableView, 
    willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration, 
    animator: UIContextMenuInteractionCommitAnimating
  ) {
    func makeFind() -> Find? {
      switch animator.previewViewController {
      case let vc as ListViewController:
        guard let feed = vc.feed else {
          return nil
        }
        
        return .suggestedFeed(feed)
      
      case let vc as EpisodeViewController:
        guard let entry = vc.entry else {
          return nil
        }
        
        return .suggestedEntry(entry)
        
      default:
        return nil
      }
    }
    
    guard let find = makeFind() else {
      return
    }
    
    animator.addCompletion { [weak self] in
      guard let me = self else {
        return
      }
      
      me.delegate?.searchResults(me, didSelectFind: find)
    }
  }
}
