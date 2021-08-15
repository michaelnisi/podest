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

  static let display = ReusableNib(
    id: "DisplayTableViewCellID",
    nib: UINib(nibName: "DisplayTableViewCell", bundle: .main),
    type: DisplayTableViewCell.self
  )
  
}

struct UICollectionViewNib {

  static let message = ReusableNib(
    id: "MessageCellID",
    nib: UINib(nibName: "MessageCollectionViewCell", bundle: .main),
    type: MessageCollectionViewCell.self
  )

}

extension UITableView {
  typealias Nib = UITableViewNib
}

extension UICollectionView {
  typealias Nib = UICollectionViewNib
}
