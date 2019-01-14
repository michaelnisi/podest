//
//  ArticleCollectionViewCell.swift
//  Podest
//
//  Created by Michael Nisi on 13.01.19.
//  Copyright © 2019 Michael Nisi. All rights reserved.
//

import UIKit

class ArticleCollectionViewCell: UICollectionViewCell {
  @IBOutlet weak var categoryLabel: UILabel!

  @IBOutlet weak var headlineLabel: UILabel!
  @IBOutlet weak var bodyLabel: UILabel!
  override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

}
