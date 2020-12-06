//
//  MarqueeText.swift
//  Podest
//
//  Created by Michael Nisi on 04.12.20.
//  Copyright © 2020 Michael Nisi. All rights reserved.
//

import SwiftUI
import Combine

private extension String {
  
  func size(usingFont font: UIFont) -> CGSize {
    size(withAttributes: [NSAttributedString.Key.font: font])
  }
}

/// One-line Text compensating insufficient space through animation.
struct MarqueeText : View {
  
  private final class Model: ObservableObject {
    
    var string: String = ""
    var width: CGFloat = .zero
    
    @Published var animation: Animation?
    @Published var x: CGFloat = 0
    private var multiplier: CGFloat = 1
    private var timer: Cancellable?
    
    private var shouldAnimate: Bool {
      stringWidth > width
    }
    
    func configure(string: String, width: CGFloat) {
      self.string = string
      self.width = width
      
      guard shouldAnimate else {
        x = 0
        animation = nil
        timer?.cancel()
        return
      }
      
      timer = Timer.publish(every: 9, on: .main, in: .common)
        .autoconnect()
        .sink { [weak self] _ in
          self?.animate()
        }
    }
    
    func animate() {
      multiplier *= -1
      x = (stringWidth - width) / 2 * multiplier
      animation = makeAnimation()
    }
        
    private func makeAnimation() -> Animation {
      Animation.easeInOut(duration: 6)
    }
    
    private var stringWidth: CGFloat {
      string.size(usingFont: .preferredFont(forTextStyle: .headline)).width
    }
  }
  
  @ObservedObject private var model = Model()
  
  init(_ string: String, maxWidth: CGFloat) {
    model.configure(string: string, width: maxWidth)
  }
  
  var body : some View {
    Text(model.string)
      .lineLimit(1)
      .font(.headline)
      .fixedSize()
      .offset(x: model.x, y: 0)
      .animation(model.animation)
  }
}

