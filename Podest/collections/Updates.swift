//
//  Updates.swift
//  Podest
//
//  Created by Michael Nisi on 21.12.17.
//  Copyright © 2017 Michael Nisi. All rights reserved.
//

import Foundation
import UIKit

/// A bucket of `UITableView` updates, applying no logic, except for basic
/// sanity asserts.
class Updates {
  
  private var indicesToInsert = [Int]()
  private var indicesToDelete = [Int]()
  private var indicesToReload = [Int]()
  
  var sectionsToInsert: IndexSet { return IndexSet(indicesToInsert) }
  var sectionsToDelete: IndexSet { return IndexSet(indicesToDelete) }
  var sectionsToReload: IndexSet { return IndexSet(indicesToReload) }
  
  lazy var rowsToInsert = [IndexPath]()
  lazy var rowsToDelete = [IndexPath]()
  lazy var rowsToReload = [IndexPath]()
  
  func deleteSection(at index: Int) {
    assert(!indicesToDelete.contains(index))
    indicesToDelete.append(index)
  }
  
  func reloadSection(at index: Int) {
    assert(!indicesToReload.contains(index))
    indicesToReload.append(index)
  }
  
  func insertSection(at index: Int) {
    assert(!indicesToInsert.contains(index))
    indicesToInsert.append(index)
  }
  
  func insertRow(at indexPath: IndexPath) {
    assert(!rowsToInsert.contains(indexPath))
    rowsToInsert.append(indexPath)
  }
  
  func deleteRow(at indexPath: IndexPath) {
    assert(!rowsToDelete.contains(indexPath))
    rowsToDelete.append(indexPath)
  }
  
  func reloadRow(at indexPath: IndexPath) {
    assert(!rowsToReload.contains(indexPath))
    rowsToReload.append(indexPath)
  }
  
  var isEmpty: Bool {
    guard
      sectionsToInsert.isEmpty,
      sectionsToDelete.isEmpty,
      sectionsToReload.isEmpty,
      rowsToInsert.isEmpty,
      rowsToDelete.isEmpty,
      rowsToReload.isEmpty else {
      return false
    }

    return true
  }
}

/// Makes this equatable for testing.
extension Updates: Equatable {
  
  static func ==(lhs: Updates, rhs: Updates) -> Bool {
    guard
      lhs.indicesToInsert == rhs.indicesToInsert,
      lhs.indicesToDelete == rhs.indicesToDelete,
      lhs.indicesToReload == rhs.indicesToReload,
      
      lhs.sectionsToInsert == rhs.sectionsToInsert,
      lhs.sectionsToDelete == rhs.sectionsToDelete,
      lhs.sectionsToReload == rhs.sectionsToReload,
      
      lhs.rowsToInsert == rhs.rowsToInsert,
      lhs.rowsToDelete == rhs.rowsToDelete,
      lhs.rowsToReload == rhs.rowsToReload
      else {
      return false
    }

    return true
  }
  
}

extension Updates: CustomStringConvertible {
  
  var description: String { return """
    Updates: (
      rowsToInsert: \(rowsToInsert),
      rowsToDelete: \(rowsToDelete),
      rowsToReload: \(rowsToReload),
      sectionsToInsert: \(sectionsToInsert),
      sectionsToDelete: \(sectionsToDelete),
      sectionsToReload: \(sectionsToReload)
    )
    """
  }

}
