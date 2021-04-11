//
//  ProductCell.swift
//  Podest
//
//  Created by Michael Nisi on 16.04.18.
//  Copyright © 2018 Michael Nisi. All rights reserved.
//

import UIKit
import os.log

private let log = OSLog.disabled

/// Inits a color with a product identifier.
private extension UIColor {
  convenience init?(productIdentifier: String?) {
    switch productIdentifier {
    case "ink.codes.podest.help":
      self.init(named: "Magenta")
    case "ink.codes.podest.love":
      self.init(named: "Stone")
    case "ink.codes.podest.sponsor":
      self.init(named: "Mint")
    default:
      self.init(white: 1/3, alpha: 1)
    }
  }
}

class ProductCell: UICollectionViewCell {
  
  @IBOutlet weak var title: UILabel!
  @IBOutlet weak var subtitle: UILabel!
  @IBOutlet weak var buy: UIButton!
  
  @IBAction func buyTouchUpInside(_ sender: UIButton) {
    delegate?.cell(self, payProductMatching: data!.productIdentifier)
  }
  
  weak var delegate: CellProductsDelegate?
  
  struct Data: Equatable {
    let productIdentifier: String
    let productName: String
    let productDescription: String
    let price: String
  }
  
  /// A color matching the product identifier. For unknown product identifiers
  /// `.darkGray` is returned.
  var color: UIColor? {
    return UIColor(productIdentifier: data?.productIdentifier) ?? .darkGray
  }
  
  var isPurchasing: Bool = false {
    didSet {
      contentView.backgroundColor = isPurchasing ?
        UIColor(named: "Purple") : color
    }
  }
  
  private func reset() {
    title.text = nil
    subtitle.text = nil
    buy.setTitle(nil, for: .normal)
  }
  
  private func updateViews() {
    guard dataChanged else {
      return
    }
    
    guard let data = self.data else {
      return reset()
    }
    
    title.text = data.productName
    subtitle.text = data.productDescription
    
    buy.setTitle(data.price, for: .normal)
    
    contentView.backgroundColor = color
  }
  
  var dataChanged = false
  
  var data: Data? {
    didSet {
      dataChanged = data != oldValue
      if let data = self.data {
        os_log("ProductCell: data: %{public}@", log: log, type: .info,
               String(describing: data))
      }
      
      updateViews()
    }
  }
  
  override func prepareForReuse() {
    super.prepareForReuse()
    
    data = nil
    isPurchasing = false
  }
  
  override func awakeFromNib() {
    super.awakeFromNib()

    title.font = UIFontMetrics.default.scaledFont(for:
      .systemFont(ofSize: 29, weight: .bold)
    )

    subtitle.font = UIFontMetrics.default.scaledFont(for:
      .systemFont(ofSize: 19, weight: .medium)
    )

    layer.cornerRadius = 16
    layer.masksToBounds = true
  }
  
}
