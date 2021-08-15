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

class ArticleCollectionViewCell: UICollectionViewCell {

  @IBOutlet weak var textView: UITextView!

  override func awakeFromNib() {
    super.awakeFromNib()
    
    layer.cornerRadius = 16
    layer.masksToBounds = true
  }

}
