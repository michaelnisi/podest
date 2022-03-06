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

struct MainView: View {
  @Environment(\.horizontalSizeClass) var horizontalSizeClass
  
  var body: some View {
    if horizontalSizeClass == .compact {
      TabContainer()
    } else {
      QueueContainer()
    }
  }
}

struct MainView_Previews: PreviewProvider {
  static var previews: some View {
    MainView()
  }
}
