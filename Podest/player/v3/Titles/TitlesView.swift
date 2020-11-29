import SwiftUI

struct TitlesView: View {
  
  var title: String
  var subtitle: String
  
  var insets: EdgeInsets {
    EdgeInsets(top: 0, leading: 20, bottom: 20, trailing: 20)
  }
  
  var body: some View {
    VStack(spacing: 12) {
      Text(title)
        .font(.headline)
      Text(subtitle)
        .font(.subheadline)
    }
    .multilineTextAlignment(.center)
    .padding(insets)
  }
}
