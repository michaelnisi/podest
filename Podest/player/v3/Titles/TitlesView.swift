import SwiftUI

struct TitlesView: View {
  
  @EnvironmentObject var model: PlayerUIView.Model
  
  var body: some View {
    VStack {
      Text(model.item.title)
        .font(.title)
      Text(model.item.feedTitle ?? "")
        .font(.subheadline)
    }.multilineTextAlignment(.center)
  }
}
