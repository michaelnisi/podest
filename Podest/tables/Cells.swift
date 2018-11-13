//
//  Cells.swift
//  Podest
//
//  Created by Michael Nisi on 21.12.17.
//  Copyright © 2017 Michael Nisi. All rights reserved.
//

import Foundation
import UIKit

struct Cell {
  let id: String
  let nib: UINib
}

final class Cells {
  
  static let image = Cell(
    id: "FKImageCellID",
    nib: UINib(nibName: "FKImageCell", bundle: Bundle.main)
  )
  static let text = Cell(
    id: "FKTextCellID",
    nib: UINib(nibName: "FKTextCell", bundle: Bundle.main)
  )
  static let suggestion = Cell(
    id: "SuggestionCellID",
    nib: UINib(nibName: "SuggestionCell", bundle: Bundle.main)
  )
  static let result = Cell(
    id: "SearchResultCellID",
    nib: UINib(nibName: "SearchResultCell", bundle: Bundle.main)
  )
  
  // MARK: Registering Cells
  
  static func registerSuggestionCell(with tableView: UITableView) {
    let cell = Cells.suggestion
    tableView.register(cell.nib, forCellReuseIdentifier: cell.id)
  }
  
  static func registerSearchResultCell(with tableView: UITableView) {
    let cell = Cells.result
    tableView.register(cell.nib, forCellReuseIdentifier: cell.id)
  }
  
  /// Registers the cell and configures the table view to use Auto Layout.
  static func registerFKImageCell(with tableView: UITableView) {
    let cell = Cells.image
    tableView.register(cell.nib, forCellReuseIdentifier: cell.id)
    tableView.rowHeight = UITableView.automaticDimension
    tableView.estimatedRowHeight = 70.0
  }
  
  /// Registers the cell and configures the table view to use Auto Layout.
  static func registerFKTextCell(with tableView: UITableView) {
    let cell = Cells.text
    tableView.register(cell.nib, forCellReuseIdentifier: cell.id)
    tableView.rowHeight = UITableView.automaticDimension
    tableView.estimatedRowHeight = 50.0
  }
  
}
