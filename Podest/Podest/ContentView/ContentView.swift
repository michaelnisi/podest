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

struct ContentView: View {
  @Environment(\.scenePhase) private var scenePhase
  @AppStorage(Mode.key) private var selectedMode = Mode.start

  var body: some View {
    switch selectedMode {
    case .main:
      MainView()
   
    case .onboarding:
      OnboardingView()
        .ignoresSafeArea()
    }
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
      .preferredColorScheme(.dark)
      .previewInterfaceOrientation(.landscapeLeft)
  }
}
