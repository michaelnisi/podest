//===----------------------------------------------------------------------===//
//
// This source file is part of the Podest open source project
//
// Copyright (c) 2022 Michael Nisi and collaborators
// Licensed under MIT License
//
// See https://github.com/michaelnisi/podest/blob/main/LICENSE for license information
//
//===----------------------------------------------------------------------===//

import SwiftUI

enum Mode: String {
  case main
  case onboarding
  
  static let start: Self = .onboarding
  static let key = "ContentView.selectedMode"
}

@main
struct PodestApp: App {
  @AppStorage(Mode.key) private var selectedMode = Mode.start
  
  var body: some Scene {
    WindowGroup {
      ContentView()
    }
  }
}
