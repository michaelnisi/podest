import SwiftUI

extension Binding {
  
  func onChange(_ handler: @escaping (Value) -> Void) -> Binding<Value> {
    Binding(
      get: { self.wrappedValue },
      set: { selection in
        self.wrappedValue = selection
        handler(selection)
      })
  }
}



