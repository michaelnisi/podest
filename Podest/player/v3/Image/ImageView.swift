import SwiftUI

public struct ImageView: View {

  @ObservedObject var image: FetchImage
  
  public var body: some View {
    GeometryReader { proxy in
      let sideLength = proxy.size.width
      let size = CGSize(width: sideLength, height: sideLength)
      
      image.fetch(fitting: size).view?
        .onDisappear {
          print("** image view: disappear")
        }
    }
  }
}
