//
//  MessageTableViewCell.swift
//  Podest
//
//  Created by Michael Nisi on 28.12.18.
//  Copyright © 2018 Michael Nisi. All rights reserved.
//

import UIKit

class MessageTableViewCell: UITableViewCell {

  @IBOutlet weak var titleLabel: UILabel!

  /// The target height of the cell.
  ///
  /// Avoiding `tableView(_:heightForRowAt:)`.
  var targetHeight: CGFloat = 320
  
  override func systemLayoutSizeFitting(
    _ targetSize: CGSize,
    withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority,
    verticalFittingPriority: UILayoutPriority
  ) -> CGSize {
    return CGSize(width: targetSize.width, height: targetHeight)
  }

}
