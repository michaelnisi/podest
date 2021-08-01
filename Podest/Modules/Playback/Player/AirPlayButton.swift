//
//  AirPlayButton.swift
//  Podest
//
//  Created by Michael Nisi on 05.12.20.
//  Copyright © 2020 Michael Nisi. All rights reserved.
//

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
 
