import SwiftUI

typealias LoadImage = ((CGSize, ((UIImage) -> Void)?) -> Void)

public final class FetchImage: ObservableObject, Identifiable {
  
  @Published public private(set) var view: SwiftUI.Image?
  
  private var loadImage: LoadImage?
  private var size: CGSize?
  
  init(loadImage: LoadImage?) {
    self.loadImage = loadImage
  }
  
  func fetch(fitting size: CGSize) -> Self {
    loadImage?(size) { uiImage in
      self.view = Image(uiImage: uiImage)
    }
    
    return self
  }
}
