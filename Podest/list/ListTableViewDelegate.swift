//
//  ListTableViewDelegate.swift
//  Podest
//
//  Created by Michael Nisi on 28.08.19.
//  Copyright © 2019 Michael Nisi. All rights reserved.
//

import Foundation
import UIKit

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
extension ListViewController {
    
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
