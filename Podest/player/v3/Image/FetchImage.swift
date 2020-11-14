import SwiftUI
import Nuke
import FeedKit

public final class FetchImage: ObservableObject, Identifiable {
  
  @Published public private(set) var view: SwiftUI.Image?
  
  private let item: Imaginable
  
  init(item: Imaginable) {
    self.item = item
  }
  
  func fetch(fitting size: CGSize) -> Self {
    Podest.images.loadImage(representing: item, at: size) { uiImage in
      self.view = Image(uiImage: uiImage!)
    }
    
    return self
  }
}
