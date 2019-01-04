//
//  SectionedDataSource.swift
//  Podest
//
//  Created by Michael Nisi on 21.12.17.
//  Copyright © 2017 Michael Nisi. All rights reserved.
//

import Foundation
import UIKit

/// A section of a table view data model.
struct Section<Item: Hashable>: Hashable {
  let id: Int
  let title: String?
  var items: [Item]

  /// Creates a new section, identified by its **unique** `id`.
  ///
  /// - Parameters:
  ///   - id: The unique identifier for this sections in this data source.
  ///   - title: An optional title of the sections.
  ///   - items: Optionally, the items of this section.
  init(id: Int, title: String? = nil, items: [Item] = [Item]()) {
    self.id = id
    self.title = title
    self.items = items
  }
  
  /// The number of items in this section.
  var count: Int {
    return items.count
  }

  var isEmpty: Bool {
    return items.isEmpty
  }

  var first: Item? {
    return items.first
  }
  
  /// Appends item to end of section.
  mutating func append(_ item: Item) {
    items.append(item)
  }

}

protocol SectionedDataSource: class {
  associatedtype Item: Hashable
  var sections: [Section<Item>] { get set }
}

extension SectionedDataSource {

  @available(*, deprecated, message: "Wrong in many ways, don’t use.")
  static func makeUpdates(old: [Section<Item>], new: [Section<Item>]) -> Updates {
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
        items = prev.items
        if section != prev || new.count != old.count {
          updates.reloadSection(at: n)
        }
      }
      for (i, item) in (section.items).enumerated() {
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
      while x > section.items.count {
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

extension SectionedDataSource {

  /// Returns updates for merging `new` and `old` sections.
  ///
  /// - Parameters:
  ///   - old: The old sections of the data source.
  ///   - new: The new sections of the data source.
  ///
  /// - Returns: The diff between `old` and `new`, one level deep, sections.
  static func makeUpdates2(
    old: [Section<Item>],
    new: [Section<Item>]) -> Updates {

    let updates = Updates()

    let sectionChanges = diff(old: old, new: new)

    for c in sectionChanges {
      switch c {
      case .delete(let section):
        updates.deleteSection(at: section.index)
      case .insert(let section):
        updates.insertSection(at: section.index)
      case .move(let section):
        updates.deleteSection(at: section.fromIndex)
        updates.insertSection(at: section.toIndex)
      case .replace(let section):
        updates.reloadSection(at: section.index)
      }
    }

    for (section, s) in new.enumerated() {
      guard let other = old.first(where: { $0.id == s.id } ) else {
        continue
      }

      let itemChanges = diff(old: other.items, new: s.items)

      for c in itemChanges {
        switch c {
        case .delete(let row):
          updates.deleteRow(at: IndexPath(row: row.index, section: section))
        case .insert(let row):
          updates.insertRow(at: IndexPath(row: row.index, section: section))
        case .move(let row):
          updates.deleteRow(at: IndexPath(row: row.fromIndex, section: section))
          updates.insertRow(at: IndexPath(row: row.toIndex, section: section))
        case .replace(let row):
          updates.reloadRow(at: IndexPath(row: row.index, section: section))
        }
      }

    }

    return updates
  }

}

extension SectionedDataSource {
  
  func itemAt(indexPath: IndexPath) -> Item? {
    guard sections.indices.contains(indexPath.section) else {
      return nil
    }

    let section = sections[indexPath.section]

    guard section.items.indices.contains(indexPath.row) else {
      return nil
    }

    return section.items[indexPath.row]
  }
  
  var isEmpty: Bool {
    return sections.isEmpty
  }
  
}

extension SectionedDataSource {

  func commit(
    sections: [Section<Item>],
    updates: Updates,
    view: UICollectionView,
    completionBlock: ((Bool) -> Void)? = nil
  ) {
    dispatchPrecondition(condition: .onQueue(.main))

    UIView.performWithoutAnimation {
      view.performBatchUpdates({
        let rowsToReload = updates.rowsToReload.sorted()

        for ip in rowsToReload {
          let row = sections[ip.section].items[ip.row]
          self.sections[ip.section].items[ip.row] = row
        }

        let sectionsToReload = updates.sectionsToReload.sorted()

        for i in sectionsToReload {
          let section = sections[i]
          self.sections[i] = section
        }

        view.reloadItems(at: Array(rowsToReload))
        view.reloadSections(IndexSet(sectionsToReload))
      })
    }

    view.performBatchUpdates({
      // Deleting in descending order.
      let rowsToDelete = updates.rowsToDelete.sorted { $0 > $1 }
      let sectionsToDelete = updates.sectionsToDelete.sorted { $0 > $1 }

      for ip in rowsToDelete {
        self.sections[ip.section].items.remove(at: ip.row)
      }

      for i in sectionsToDelete {
        self.sections.remove(at: i)
      }

      // Inserting in ascending order.
      let sectionsToInsert = updates.sectionsToInsert.sorted()
      let rowsToInsert = updates.rowsToInsert.sorted()

      for i in sectionsToInsert {
        let section = sections[i]
        self.sections.insert(section, at: i)
      }

      for ip in rowsToInsert {
        let row = sections[ip.section].items[ip.row]
        self.sections[ip.section].items.insert(row, at: ip.row)
      }

      view.deleteSections(IndexSet(sectionsToDelete))
      view.deleteItems(at: Array(rowsToDelete))

      view.insertSections(IndexSet(sectionsToInsert))
      view.insertItems(at: Array(rowsToInsert))
    }) { finished in
      completionBlock?(finished)
    }

  }

}
