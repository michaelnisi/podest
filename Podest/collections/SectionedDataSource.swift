//
//  SectionedDataSource.swift
//  Podest
//
//  Created by Michael Nisi on 21.12.17.
//  Copyright © 2017 Michael Nisi. All rights reserved.
//

import Foundation
import UIKit
import os.log

private let log = OSLog.disabled

/// Makes UITableView and UICollectionView interchangeable for our purposes.
enum SectionDataSourceView {
  case collection(UICollectionView)
  case table(UITableView)

  func performBatchUpdates(
    _ updates: (() -> Void)?, completion: ((Bool) -> Void)?) {
    switch self {
    case .table(let tv):
      tv.performBatchUpdates(updates, completion: completion)
    case .collection(let cv):
      cv.performBatchUpdates(updates, completion: completion)
    }
  }

  func update(
    sectionsToDelete: IndexSet,
    rowsToDelete: [IndexPath],
    sectionsToInsert: IndexSet,
    rowsToInsert: [IndexPath]
  ) {
    switch self {
    case .table(let tv):
      tv.deleteSections(sectionsToDelete, with: .fade)
      tv.deleteRows(at: rowsToDelete, with: .fade)
      tv.insertSections(sectionsToInsert, with: .fade)
      tv.insertRows(at: rowsToInsert, with: .fade)
    case .collection(let cv):
      cv.deleteSections(sectionsToDelete)
      cv.deleteItems(at: rowsToDelete)
      cv.insertSections(sectionsToInsert)
      cv.insertItems(at: rowsToInsert)
    }
  }
}

/// A sectioned data source for table and collection views.
protocol SectionedDataSource: class {
  associatedtype Item: Hashable
  var sections: [Array<Item>] { get set }
}

// MARK: - Performing Batch Updates

extension SectionedDataSource {

  /// Returns required changes for building the `new` sections.
  static func makeChanges(
    old: [Array<Item>], new: [Array<Item>]) -> [[Change<Item>]] {
    var changes = [[Change<Item>]]()

    for (i, section) in new.enumerated() {
      let items = i < old.endIndex ? old[i] : []

      changes.append(diff(old: items, new: section))
    }

    return changes
  }

  /// Commit changes `batch`, performing batch updates with `view`.
  ///
  /// Reloading sections and rows are still to crack, leaving **section titles
  /// not fully supported** yet.
  ///
  /// - Parameters:
  ///   - batch: Arrays of changes per section.
  ///   - view: The view performing the batch updates.
  ///   - completionBlock: A block to execute when all operations are finished.
  func commit(
    _ batch: [[Change<Item>]],
    performingWith view: SectionDataSourceView,
    completionBlock: ((Bool) -> Void)? = nil
    ) {
    dispatchPrecondition(condition: .onQueue(.main))

    let count = self.sections.count
    var sectionsCountDiff = batch.count - count

    var rowsToDelete = [IndexPath]()
    var rowsToInsert = [(IndexPath, Item)]()

    for (i, changes) in batch.enumerated() {
      for change in changes {
        switch change {
        case .delete(let c):
          let ip = IndexPath(row: c.index, section: i)

          rowsToDelete.append(ip)
        case .insert(let c):
          let ip = IndexPath(row: c.index, section: i)

          rowsToInsert.append((ip, c.item))
        case .move(let c):
          let from = IndexPath(row: c.fromIndex, section: i)
          let to = IndexPath(row: c.toIndex, section: i)

          rowsToDelete.append(from)
          rowsToInsert.append((to, c.item))
        case .replace(let c):
          let ip = IndexPath(row: c.index, section: i)

          rowsToDelete.append(ip)
          rowsToInsert.append((ip, c.newItem))
        }
      }
    }

    view.performBatchUpdates({
      // Appending and removing sections.

      var sectionsToDelete = Set<Int>()
      var sectionsToInsert = Set<Int>()

      while sectionsCountDiff < 0 {
        sectionsToDelete.insert(sectionsCountDiff + count)

        sectionsCountDiff = sectionsCountDiff + 1

        self.sections.removeLast()
      }

      while sectionsCountDiff > 0 {
        sectionsCountDiff = sectionsCountDiff - 1

        sectionsToInsert.insert(sectionsCountDiff + count)

        self.sections.append([])
      }

      // Deleting in descending order.

      let rowsToDelete = rowsToDelete.sorted(by: >)

      for ip in rowsToDelete {
        self.sections[ip.section].remove(at: ip.row)
      }

      // Inserting in ascending order.

      let rowsToInsert = rowsToInsert.sorted { $0.0 < $1.0 }

      for row in rowsToInsert {
        let (ip, item) = row
        self.sections[ip.section].insert(item, at: ip.row)
      }

      let (sd, si) = (
        IndexSet(sectionsToDelete.sorted(by: >)),
        IndexSet(sectionsToInsert.sorted())
      )

      os_log("deleting sections: %@", log: log, type: .debug, sd as CVarArg)
      os_log("deleting rows: %@", log: log, type: .debug, rowsToDelete as CVarArg)
      os_log("inserting sections: %@", log: log, type: .debug, si as CVarArg)
      os_log("inserting rows: %@", log: log, type: .debug, rowsToInsert as CVarArg)

      view.update(
        sectionsToDelete: sd,
        rowsToDelete: rowsToDelete,
        sectionsToInsert: si,
        rowsToInsert: rowsToInsert.map { $0.0 }
      )
    }) { completed in
      completionBlock?(completed)
    }
  }

}

// MARK: - Accessing Items

extension SectionedDataSource {
  
  func itemAt(indexPath: IndexPath) -> Item? {
    guard sections.indices.contains(indexPath.section) else {
      return nil
    }

    let section = sections[indexPath.section]

    guard section.indices.contains(indexPath.row) else {
      return nil
    }

    return section[indexPath.row]
  }
  
  var isEmpty: Bool {
    return sections.isEmpty
  }
  
}
