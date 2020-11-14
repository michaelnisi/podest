import SwiftUI

struct CloseBarButton: View {
  var body: some View {
    Rectangle()
      .fill(Color(UIColor.systemFill))
      .frame(width: 96, height: 6)
      .cornerRadius(3)
  }
}

