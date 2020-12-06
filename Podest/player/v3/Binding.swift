import SwiftUI

extension Binding {
  
  /// Returns a Binding calling `handler` on set for **below iOS 14** which has `view.onChange`.
  ///
  /// - Parameters:
  ///   - handler: The closure receiving the value once it has changed.
  func onChange(_ handler: @escaping (Value) -> Void) -> Binding<Value> {
    Binding(
      get: { self.wrappedValue },
      set: { selection in
        self.wrappedValue = selection
        handler(selection)
      })
  }
}



