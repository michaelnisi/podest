//
//  MarqueeText.swift
//  Podest
//
//  Created by Michael Nisi on 04.12.20.
//  Copyright © 2020 Michael Nisi. All rights reserved.
//

import SwiftUI

/// A view that displays a single line text pendulum.
struct MarqueeText : View {
  
  @Binding var string: String
  @Binding var width: CGFloat
  
  @State var offset: CGFloat = .zero
  @State var multiplier: CGFloat = 1
  
  private let space: CGFloat = 24

  private var stringWidth: CGFloat {
    string.size(usingFont: .preferredFont(forTextStyle: .headline)).width + space
  }
  
  private var shouldAnimate: Bool {
    stringWidth - space > width
  }
  
  private func updateOffset() {
    guard shouldAnimate else {
      offset = 0
      return
    }
    
    offset = (stringWidth - width) / 2 * multiplier
  }
  
  private func flipDirection() {
    multiplier *= -1
  }
  
  private var duration: Double {
    shouldAnimate ? min(18, max(9, Double(stringWidth) * 0.03)) : 0
  }
  
  private func update() {
    guard width > 0 else {
      return
    }
    
    withAnimation(.linear(duration: duration)) {
      updateOffset()
    }
  }
  
  private func start() {
    multiplier = 1
    update()
  }
  
  var body: some View {
    ZStack {
      Text(string)
        .lineLimit(1)
        .font(.headline)
        .fixedSize()
        .frame(width: width)
        .offset(x: offset)
        .clipped()
        .onAnimationComplete(for: offset) {
          flipDirection()
          update()
        }
    }.onChange(of: string) { _ in
      start()
    }.onChange(of: width) { _ in
      start()
    }.onAppear {
      start()
    }
  }
}

struct SizePrefKey: PreferenceKey {
  
  static var defaultValue: CGSize = .zero
  
  static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
    value = nextValue()
  }
}

private extension String {
  
  func size(usingFont font: UIFont) -> CGSize {
    size(withAttributes: [NSAttributedString.Key.font: font])
  }
}

