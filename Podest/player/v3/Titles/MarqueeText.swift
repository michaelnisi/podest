//
//  MarqueeText.swift
//  Podest
//
//  Created by Michael Nisi on 04.12.20.
//  Copyright © 2020 Michael Nisi. All rights reserved.
//

import SwiftUI

private extension String {
  
  func size(usingFont font: UIFont) -> CGSize {
    size(withAttributes: [NSAttributedString.Key.font: font])
  }
}

/// One-line Text compensating insufficient space through animation.
struct MarqueeText : View {
  
  @Binding var string: String
  
  private let animation = Animation.easeInOut(duration: 10)
    .delay(3.5)
    .repeatForever(autoreverses: true)
  
  private var stringWidth: CGFloat {
    string.size(usingFont: .preferredFont(forTextStyle: .headline)).width
  }

  var body : some View {
    Text(string).lineLimit(1)
      .font(.headline)
      .fixedSize()
  }
}

