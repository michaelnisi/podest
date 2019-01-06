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

private let log = OSLog(subsystem: "ink.codes.podest", category: "ds")

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

  func commit(
    _ batch: [[Change<Item>]],
    performingWith view: UICollectionView,
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
      view.deleteSections(sd)

      os_log("deleting rows: %@", log: log, type: .debug, rowsToDelete as CVarArg)
      view.deleteItems(at: rowsToDelete)

      os_log("inserting sections: %@", log: log, type: .debug, si as CVarArg)
      view.insertSections(si)

      os_log("inserting rows: %@", log: log, type: .debug, rowsToInsert as CVarArg)
      view.insertItems(at: rowsToInsert.map { $0.0 })
    })
  }

}

// MARK: - Temporary Extension for UITableView

extension SectionedDataSource {

  func commit(
    _ batch: [[Change<Item>]],
    performingWith view: UITableView,
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
      view.deleteSections(sd, with: .fade)

      os_log("deleting rows: %@", log: log, type: .debug, rowsToDelete as CVarArg)
      view.deleteRows(at: rowsToDelete, with: .fade)

      os_log("inserting sections: %@", log: log, type: .debug, si as CVarArg)
      view.insertSections(si, with: .fade)

      os_log("inserting rows: %@", log: log, type: .debug, rowsToInsert as CVarArg)
      view.insertRows(at: rowsToInsert.map { $0.0 }, with: .fade)
    })
  }

  @available(*, deprecated, message: "Replaced by SectionedDataSource commits.")
  static func makeUpdates(old: [Array<Item>], new: [Array<Item>]) -> Updates {
    let updates = Updates()
    let numberOfSections = old.count

    for (n, section) in new.enumerated() {
      var rows = 0
      var items: [Item]?
      if numberOfSections <= n {
        updates.insertSection(at: n)
      } else {
        let prev = old[n]
        rows = prev.count
        items = prev
        if section != prev || new.count != old.count {
          updates.reloadSection(at: n)
        }
      }
      for (i, item) in section.enumerated() {
        let indexPath = IndexPath(row: i, section: n)
        if rows <= i {
          updates.insertRow(at: indexPath)
        } else {
          if let prev = items?[i] {
            if item != prev {
              updates.reloadRow(at: indexPath)
            }
          }
        }
      }
      var x = rows
      while x > section.count {
        x -= 1
        let indexPath = IndexPath(row: x, section: n)
        updates.deleteRow(at: indexPath)
      }
    }
    var y = numberOfSections
    while y > new.count {
      y -= 1
      updates.deleteSection(at: y)
    }

    return updates
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
