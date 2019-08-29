//
//  QueueTableViewDelegate.swift
//  Podest
//
//  Created by Michael Nisi on 21.04.19.
//  Copyright © 2019 Michael Nisi. All rights reserved.
//

import Foundation
import UIKit
import FeedKit

extension QueueViewController {
  
  // MARK: - Selecting

  override func tableView(
    _ tableView: UITableView,
    willSelectRowAt indexPath: IndexPath
  ) -> IndexPath? {
    guard case .entry? = dataSource.itemAt(indexPath: indexPath) else {
      return nil
    }
    
    return indexPath
  }
  
  override func tableView(
    _ tableView: UITableView,
    didSelectRowAt indexPath: IndexPath
  ) {
    guard let entry = dataSource.entry(at: indexPath) else {
      return
    }
    
    navigationDelegate?.show(entry: entry)
  }
}

// MARK: - Editing

extension QueueViewController {
  
  override func tableView(
    _ tableView: UITableView, willBeginEditingRowAt indexPath: IndexPath) {
    choreographer.wait()
  }
  
  
  override func tableView(
    _ tableView: UITableView, didEndEditingRowAt indexPath: IndexPath?) {
    choreographer.clear()
  }
}

// MARK: - Menus and Shortcuts

@available(iOS 13.0, *)
extension QueueViewController {
    
  override func tableView(
    _ tableView: UITableView, 
    contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint
  ) -> UIContextMenuConfiguration? {
    guard let entry = dataSource.entry(at: indexPath) else {
      return nil
    }
    
    return Episode.makeContextConfiguration(
      entry: entry, 
      navigationDelegate: navigationDelegate,
      queue: Podest.userQueue,
      library: Podest.userLibrary
    )
  }
  
  override func tableView(
    _ tableView: UITableView, 
    previewForHighlightingContextMenuWithConfiguration configuration: UIContextMenuConfiguration
  ) -> UITargetedPreview? {
    choreographer.wait()
    
    return nil
  }
  
  override func tableView(
    _ tableView: UITableView, 
    previewForDismissingContextMenuWithConfiguration configuration: UIContextMenuConfiguration
  ) -> UITargetedPreview? {
    choreographer.clear()

    return nil
  }
  
  override func tableView(
    _ tableView: UITableView, 
    willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration, 
    animator: UIContextMenuInteractionCommitAnimating
  ) {
    guard 
      let episode = animator.previewViewController as? EpisodeViewController, 
      let entry = episode.entry else {
      return
    }
    
    animator.addCompletion { [weak self] in
      self?.choreographer.clear()
      self?.navigationDelegate?.show(entry: entry)
    }
  }
}

// MARK: - Leading Swipe Actions

extension QueueViewController {
  
  private static var play: UIImage {
    if #available(iOS 13.0, *) {
      return UIImage(systemName: "play.fill")!
    } else {
      return UIImage(named: "Play")!
    }
  }
  
  private func makePlayAction(
    indexPath: IndexPath, entry: Entry) -> UIContextualAction {
    let a = UIContextualAction(style: .normal, title: nil) { 
      action, sourceView, completionHandler in
      let actionPerformed = Podest.playback.resume(entry: entry)
      
      completionHandler(actionPerformed)
    }
    a.image = QueueViewController.play
    a.backgroundColor = .systemGreen
    
    return a
  }
  
  override func tableView(
    _ tableView: UITableView, 
    leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath
  ) -> UISwipeActionsConfiguration? {
    guard let entry = dataSource.entry(at: indexPath), 
      !Podest.playback.isPlaying(guid: entry.guid) else {
      return nil
    }

    let actions = [makePlayAction(indexPath: indexPath, entry: entry)]
    let conf = UISwipeActionsConfiguration(actions: actions)
    conf.performsFirstActionWithFullSwipe = true
    
    return conf
  }
}

// MARK: - Trailing Swipe Actions

extension QueueViewController {
  
  private static var trash: UIImage {
     if #available(iOS 13.0, *) {
       return UIImage(systemName: "trash.fill")!
     } else {
       return UIImage(named: "Trash")!
     }
  }
   
   private func makeDequeueAction(indexPath: IndexPath) -> UIContextualAction {
     let h = dataSource.makeDequeueHandler(
      indexPath: indexPath, tableView: tableView)
     let a = UIContextualAction(style: .destructive, title: nil, handler: h)
     a.image = QueueViewController.trash
     
     return a
   }
   
   override func tableView(
     _ tableView: UITableView,
     trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
   ) -> UISwipeActionsConfiguration? {
     let actions = [makeDequeueAction(indexPath: indexPath)]
     let conf = UISwipeActionsConfiguration(actions: actions)
     conf.performsFirstActionWithFullSwipe = true
     
     return conf
   }
}
