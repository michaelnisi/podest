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
