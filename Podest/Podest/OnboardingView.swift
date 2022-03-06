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

struct OnboardingView: View {
  @AppStorage(Mode.key) private var selectedMode = Mode.start
  
  var body: some View {
    VStack {
      Button("Start") {
        selectedMode = .main
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.yellow)
  }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
    }
}
