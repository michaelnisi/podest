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
extension QueueViewController: Unsubscribing, Dequeueing {
    
  override func tableView(
    _ tableView: UITableView, 
    contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint
  ) -> UIContextMenuConfiguration? {
    guard let entry = dataSource.entry(at: indexPath) else {
      return nil
    }
    
    return EpisodeContext.makeContextConfiguration(
      entry: entry, 
      navigationDelegate: navigationDelegate,
      queue: self,
      library: self,
      view: tableView.cellForRow(at: indexPath)
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
  private func makePlayAction(entry: Entry) -> UIContextualAction {
    let action = UIContextualAction(style: .normal, title: nil) { action, sourceView, completionHandler in
      Podcasts.player.setItem(matching: EntryLocator(entry: entry))
      
      completionHandler(true)
    }
    action.image = UIImage(systemName: "play.fill")!
    action.backgroundColor = .systemGreen
    
    return action
  }
  
  override func tableView(
    _ tableView: UITableView, 
    leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath
  ) -> UISwipeActionsConfiguration? {
    guard let entry = dataSource.entry(at: indexPath), 
      !Podcasts.playback.isPlaying(guid: entry.guid) else {
      return nil
    }

    let actions = [makePlayAction(entry: entry)]
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
     let action = UIContextualAction(style: .destructive, title: nil, handler: h)
     action.image = QueueViewController.trash
     
     return action
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
