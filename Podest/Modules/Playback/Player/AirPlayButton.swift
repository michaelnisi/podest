//===----------------------------------------------------------------------===//
//
// This source file is part of the Podest open source project
//
// Copyright (c) 2021 Michael Nisi and collaborators
// Licensed under MIT License
//
// See https://github.com/michaelnisi/podest/blob/main/LICENSE for license information
//
//===----------------------------------------------------------------------===//

import SwiftUI
import AVKit

struct AirPlayButton: UIViewRepresentable {
  
  func makeUIView(context: Context) -> AVRoutePickerView {
    AVRoutePickerView()
  }
  
  func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
    uiView.tintColor = makeTintColor(environment: context.environment)
  }
  
  func makeTintColor(environment: EnvironmentValues) -> UIColor? {
    let colors = environment.colors
    let color = environment.colorScheme == .dark ? colors.light : colors.dark
    guard let cgColor = color.cgColor else {
      return nil
    }
    
    return UIColor(cgColor: cgColor)
  }
}
 
