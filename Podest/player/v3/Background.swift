//
//  Background.swift
//  Podest
//
//  Created by Michael Nisi on 13.12.20.
//  Copyright © 2020 Michael Nisi. All rights reserved.
//

import SwiftUI
import UIKit

struct Background: View {
  
  @Environment(\.colorScheme) var colorScheme: ColorScheme
  @Binding var image: UIImage
  
  var body: some View {
    Color(
      colorScheme == .dark ?
        image.averageColor.darker(componentDelta: 0.3) :
        image.averageColor.lighter()
    )
    .edgesIgnoringSafeArea(.all)
    .animation(.default)
  }
}

private extension UIColor {
  
  private func makeColor(componentDelta: CGFloat) -> UIColor {
    var red: CGFloat = 0
    var blue: CGFloat = 0
    var green: CGFloat = 0
    var alpha: CGFloat = 0
    
    getRed(
      &red,
      green: &green,
      blue: &blue,
      alpha: &alpha
    )
    
    return UIColor(
      red: add(componentDelta, toComponent: red),
      green: add(componentDelta, toComponent: green),
      blue: add(componentDelta, toComponent: blue),
      alpha: alpha
    )
  }
  
  private func add(_ value: CGFloat, toComponent: CGFloat) -> CGFloat {
    max(0, min(1, toComponent + value))
  }
  
  func lighter(componentDelta: CGFloat = 0.1) -> UIColor {
    makeColor(componentDelta: componentDelta)
  }
  
  func darker(componentDelta: CGFloat = 0.1) -> UIColor {
    makeColor(componentDelta: -1*componentDelta)
  }
}

private extension UIImage {
  
  private func makeCIAreaAverageFilter(image: CIImage) -> CIFilter? {
    let extentVector = CIVector(
      x: image.extent.origin.x,
      y: image.extent.origin.y,
      z: image.extent.size.width,
      w: image.extent.size.height
    )
    
    return CIFilter(
      name: "CIAreaAverage",
      parameters: [kCIInputImageKey: image, kCIInputExtentKey: extentVector]
    )
  }
  
  var averageColor: UIColor {
    guard let inputImage = CIImage(image: self) else {
      return .clear
    }
    
    guard let filter = makeCIAreaAverageFilter(image: inputImage) else {
      return .clear
    }
    
    guard let outputImage = filter.outputImage else {
      return .clear
    }
    
    var bitmap = [UInt8](repeating: 0, count: 4)
    let context = CIContext(options: [.workingColorSpace: kCFNull!])
    
    context.render(
      outputImage,
      toBitmap: &bitmap,
      rowBytes: 4,
      bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
      format: .RGBA8,
      colorSpace: nil
    )
    
    return UIColor(
      red: CGFloat(bitmap[0]) / 255,
      green: CGFloat(bitmap[1]) / 255,
      blue: CGFloat(bitmap[2]) / 255,
      alpha: CGFloat(bitmap[3]) / 255
    )
  }
}

