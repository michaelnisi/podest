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

// MARK: - Selecting

extension ListViewController {

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

// MARK: - Menus and Shortcuts

@available(iOS 13.0, *)
extension ListViewController: Dequeueing {
    
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
      view: tableView.cellForRow(at: indexPath), 
      isShowPodcastRequired: false
    )
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
      self?.navigationDelegate?.show(entry: entry)
    }
  }
}

// MARK: - Leading Swipe Actions

extension ListViewController {
  
  private func makePlayAction(entry: Entry) -> UIContextualAction {
    let a = UIContextualAction(style: .normal, title: nil) { action, sourceView, completionHandler in
      Podcasts.player.setItem(matching: EntryLocator(entry: entry))
      completionHandler(true)
    }
    a.image = UIImage(systemName: "play.fill")
    a.backgroundColor = .systemGreen
    
    return a
  }
  
  @available(iOS 13.0, *)
  private func makeAddAction(entry: Entry) -> UIContextualAction {
    let action = UIContextualAction(style: .normal, title: nil) { 
      action, sourceView, completionHandler in
      Podcasts.userQueue.enqueue(entries: [entry], belonging: .user) { enqueued, error in
        DispatchQueue.main.async {
          completionHandler(enqueued.contains(entry) && error == nil)
        }
      }
    }
    action.image = UIImage(systemName: "plus")
    action.backgroundColor = .systemTeal

    return action
  }
  
  override func tableView(
    _ tableView: UITableView, 
    leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath
  ) -> UISwipeActionsConfiguration? {
    guard let entry = dataSource.entry(at: indexPath) else {
      return nil
    }
    
    var actions = Array<UIContextualAction>()
    
    if !Podcasts.playback.isPlaying(guid: entry.guid) {
      actions.append(makePlayAction(entry: entry))
    }

    if !Podcasts.userQueue.contains(entry: entry) {
      actions.append(makeAddAction(entry: entry))
    }
    
    Podcasts.player.setItem(matching: EntryLocator(entry: entry))
    
    let conf = UISwipeActionsConfiguration(actions: actions)
    conf.performsFirstActionWithFullSwipe = true
    
    return conf
  }
}

// MARK: - Trailing Swipe Actions

extension ListViewController {
  
  private static var trash: UIImage {
    if #available(iOS 13.0, *) {
      return UIImage(systemName: "trash.fill")!
    } else {
      return UIImage(named: "Trash")!
    }
  }
  
  private func makeDequeueAction(entry: Entry) -> UIContextualAction {
    let action = UIContextualAction(style: .destructive, title: nil) { 
      action, sourceView, completionHandler in
      Podcasts.userQueue.dequeue(entry: entry) { dequeued, error in
        DispatchQueue.main.async {
          completionHandler(!dequeued.isEmpty && error == nil)
        }
      }
    }
    
    action.image = ListViewController.trash
    
    return action
  }
  
  override func tableView(
    _ tableView: UITableView,
    trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
  ) -> UISwipeActionsConfiguration? {
    guard let entry = dataSource.entry(at: indexPath), Podcasts.userQueue.contains(entry: entry) else {
      return nil
    }
    
    let actions = [makeDequeueAction(entry: entry)]
    let conf = UISwipeActionsConfiguration(actions: actions)
    conf.performsFirstActionWithFullSwipe = true
    
    return conf
  }
}

