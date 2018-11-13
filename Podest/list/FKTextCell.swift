//
//  FKTextCell.swift
//  Podest
//
//  Created by Michael Nisi on 21.12.17.
//  Copyright © 2017 Michael Nisi. All rights reserved.
//

import UIKit
import FeedKit

/// A table view cell text cell capable of rendering FeedKit entries and feeds.
class FKTextCell: UITableViewCell {
  
  @IBOutlet var titleLabel: UILabel!
  @IBOutlet var subtitleLabel: UILabel!
  
  @discardableResult public func configure(with entry: Entry) -> UITableViewCell {
    guard tag != entry.hashValue else {
      return self
    }

    titleLabel.text = entry.title
    subtitleLabel.text = StringRepository.episodeCellSubtitle(for: entry)

    tag = entry.hashValue
    
    return self
  }
  
  @discardableResult public func configure(with feed: Feed) -> UITableViewCell {
    guard tag != feed.hashValue else {
      return self
    }

    titleLabel.text = feed.title
    subtitleLabel.text = StringRepository.feedCellSubtitle(for: feed)

    tag = feed.hashValue
    
    return self
  }
  
}

// MARK: - NSObject

extension FKTextCell {
  
  override func awakeFromNib() {
    super.awakeFromNib()
    
    titleLabel.text = ""
    subtitleLabel.text = ""
  }
  
}
