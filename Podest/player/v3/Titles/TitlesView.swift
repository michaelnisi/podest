import SwiftUI

struct TitlesView: View {
  
  @EnvironmentObject var model: PlayerView.Model
  
  var body: some View {
    VStack(spacing: 12) {
      Text(model.item?.title ?? "")
        .font(.title)
      Text(model.item?.feedTitle ?? "")
        .font(.subheadline)
    }
    .multilineTextAlignment(.center)
    .padding(makeInsets())
  }
}

// MARK: - Factory

extension TitlesView {
  
  private func makeInsets() -> EdgeInsets {
    EdgeInsets(top: 0, leading: 20, bottom: 20, trailing: 20)
  }
}

