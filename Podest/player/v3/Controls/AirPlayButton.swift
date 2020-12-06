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
      let view = AVRoutePickerView()
      view.tintColor = .secondaryLabel
      
      return view
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        //
    }
}
