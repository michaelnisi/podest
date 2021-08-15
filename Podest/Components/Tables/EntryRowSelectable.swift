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

import UIKit
import FeedKit

/// Selects and deselects table view rows.
protocol EntryRowSelectable {

  associatedtype DataSource: EntryIndexPathMapping

  var dataSource: DataSource { get }
  var navigationDelegate: ViewControllers? { get }

}

extension EntryRowSelectable where Self: UITableViewController {

  @discardableResult func selectRow(
    representing entry: Entry?,
    animated: Bool,
    scrollPosition: UITableView.ScrollPosition = .none
  ) -> Bool {
    guard viewIfLoaded?.window != nil,
      let e = entry,
      let ip = dataSource.indexPath(matching: e) else {
      if let indexPathForSelectedRow = tableView.indexPathForSelectedRow {
        tableView.deselectRow(at: indexPathForSelectedRow, animated: animated)
      }

      return false
    }

    tableView.selectRow(at: ip, animated: animated, scrollPosition: scrollPosition)

    return true
  }

  func clearSelection(_ animated: Bool) {
    selectRow(representing: nil, animated: animated)
  }

  /// Selects the row matching the globally focused entry if possible.
  func selectCurrentRow(
    animated: Bool,
    scrollPosition: UITableView.ScrollPosition = .none
  ) {
    guard viewIfLoaded?.window != nil,
      let entry = self.navigationDelegate?.entry else {
      return
    }

    selectRow(representing: entry, animated: animated, scrollPosition: scrollPosition)
  }

}
