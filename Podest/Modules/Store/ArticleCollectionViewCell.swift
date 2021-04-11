//
//  ArticleCollectionViewCell.swift
//  Podest
//
//  Created by Michael Nisi on 13.01.19.
//  Copyright © 2019 Michael Nisi. All rights reserved.
//

import UIKit

class ArticleCollectionViewCell: UICollectionViewCell {

  @IBOutlet weak var textView: UITextView!

  override func awakeFromNib() {
    super.awakeFromNib()
    
    layer.cornerRadius = 16
    layer.masksToBounds = true
  }

}
