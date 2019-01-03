//
//  ReusableNib.swift
//  Podest
//
//  Created by Michael Nisi on 03.01.19.
//  Copyright © 2019 Michael Nisi. All rights reserved.
//

import UIKit

typealias ReuseIdentifier = String

struct ReusableNib {
  let id: ReuseIdentifier
  let nib: UINib
}

struct UITableViewNib {

  static let suggestion = ReusableNib(
    id: "SuggestionCellID",
    nib: UINib(nibName: "SuggestionCell", bundle: .main)
  )

  static let message = ReusableNib(
    id: "MessageTableViewCellID",
    nib: UINib(nibName: "MessageTableViewCell", bundle: .main)
  )

  static let subtitle = ReusableNib(
    id: "SubtitleTableViewCellID",
    nib: UINib(nibName: "SubtitleTableViewCell", bundle: .main)
  )

  static let summary = ReusableNib(
    id: "SummaryTableViewCellID",
    nib: UINib(nibName: "SummaryTableViewCell", bundle: .main)
  )

}

extension UITableView {
  typealias Nib = UITableViewNib
}
