import SwiftUI
import FeedKit

public struct ImageView: View {
  
  @ObservedObject private var image: FetchImage
  
  public var body: some View {
    GeometryReader { proxy in
      let sideLength = proxy.size.width
      let size = CGSize(width: sideLength, height: sideLength)
      
      image.fetch(fitting: size).view?
        .frame(width: sideLength, height: sideLength)
        .cornerRadius(8)
        .shadow(radius: 16)
    }
  }
  
  init(image: FetchImage) {
    self.image = image
  }
}
