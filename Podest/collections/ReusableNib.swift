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
  let type: AnyClass
}

struct UITableViewNib {

  static let suggestion = ReusableNib(
    id: "SuggestionCellID",
    nib: UINib(nibName: "SuggestionCell", bundle: .main),
    type: SuggestionCell.self
  )

  static let message = ReusableNib(
    id: "MessageTableViewCellID",
    nib: UINib(nibName: "MessageTableViewCell", bundle: .main),
    type: MessageTableViewCell.self
  )

  static let subtitle = ReusableNib(
    id: "SubtitleTableViewCellID",
    nib: UINib(nibName: "SubtitleTableViewCell", bundle: .main),
    type: SubtitleTableViewCell.self
  )

  static let summary = ReusableNib(
    id: "SummaryTableViewCellID",
    nib: UINib(nibName: "SummaryTableViewCell", bundle: .main),
    type: SummaryTableViewCell.self
  )

}

struct UICollectionViewNib {

  static let text = ReusableNib(
    id: "TextCollectionViewCellID",
    nib: UINib(nibName: "TextCollectionViewCell", bundle: .main),
    type: TextCollectionViewCell.self
  )

}

extension UITableView {
  typealias Nib = UITableViewNib
}

extension UICollectionView {
  typealias Nib = UICollectionViewNib
}
