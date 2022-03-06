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

struct SearchContainer: View {
  @Environment(\.horizontalSizeClass) var horizontalSizeClass
  
  var body: some View {
    VStack(spacing: 0) {
      NavigationView {
        SearchView()
          .navigationTitle("Discover")
        
      }
      if horizontalSizeClass == .compact {
        PlayerStageView()
      }
    }
  }
}

struct SearchContainer_Previews: PreviewProvider {
  static var previews: some View {
    SearchContainer()
  }
}
