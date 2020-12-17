//
//  AnimationCompletion.swift
//  Podest
//
//  Created by Michael Nisi on 17.12.20.
//  Copyright © 2020 Michael Nisi. All rights reserved.
//

import Foundation
import SwiftUI

/// Antoine van der Lee, https://www.avanderlee.com/swiftui/withanimation-completion-callback/
struct AnimationCompletion<Value>:
  AnimatableModifier where Value: VectorArithmetic {
  
  var animatableData: Value {
    didSet {
      notifyCompletionIfFinished()
    }
  }

  private var targetValue: Value
  private var completion: () -> Void
  
  init(observedValue: Value, completion: @escaping () -> Void) {
    self.completion = completion
    self.animatableData = observedValue
    targetValue = observedValue

  }

  private func notifyCompletionIfFinished() {
    guard animatableData == targetValue else {
      return
    }

    DispatchQueue.main.async {
      self.completion()
    }
  }
  
  func body(content: Content) -> some View {
    content
  }
}

extension View {

    func onAnimationComplete<Value: VectorArithmetic>(
      for value: Value,
      completion: @escaping () -> Void
    ) -> ModifiedContent<Self, AnimationCompletion<Value>> {
      modifier(AnimationCompletion(observedValue: value, completion: completion))
    }
}


