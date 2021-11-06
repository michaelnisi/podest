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
import MediaPlayer

struct VolumeAndRouteView: UIViewRepresentable {
  func makeUIView(context: Context) -> MPVolumeView {
    MPVolumeView().setup()
  }
  
  func updateUIView(_ uiView: MPVolumeView, context: Context) {
    let environment = context.environment
    let (colorScheme, colors) = (environment.colorScheme, environment.colors)
    
    let foreground = colors.primary(matching: colorScheme)
    let background = colors.secondary(matching: colorScheme)
    
    uiView.tint(
      foreground: .init(cgColor: foreground.cgColor!),
      background: .init(cgColor: background.cgColor!)
    )
  }
}

private extension MPVolumeView {
  var slider: UISlider? {
    subviews.first { $0 is UISlider } as? UISlider
  }
  
  var routeButton: UIButton? {
    subviews.first { $0 is UIButton } as? UIButton
  }
  
  func setRouteButtonRenderingMode() {
    routeButton?.setImage(
      routeButton?.image(for: .normal)?.withRenderingMode(.alwaysTemplate),
      for: []
    )
  }

  func setup() -> Self {
    setVolumeThumbImage(.init(systemName: "circle.fill"), for: [])
    setRouteButtonRenderingMode()
    
    return self
  }
  
  func tint(foreground: UIColor, background: UIColor) {
    tintColor = foreground
    slider?.minimumTrackTintColor = foreground
    slider?.maximumTrackTintColor = background
  }
}
