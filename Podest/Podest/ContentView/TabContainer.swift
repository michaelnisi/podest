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

struct TabContainer: View {
  @SceneStorage(Mode.key) private var selectedTab: Tab = .search
  
  enum Tab: String {
    case queue
    case search
  }
  
  var body: some View {
    TabView(selection: $selectedTab) {
      SearchContainer()
      .tabItem {
        Image(systemName: "magnifyingglass.circle.fill")
        Text("Discover")
      }
      .tag(Tab.search)
     
      QueueContainer()
        .tabItem {
          Image(systemName: "list.bullet.circle.fill")
          Text("Queue")
        }
        .tag(Tab.queue)
    }
  }
}

struct TabContainer_Previews: PreviewProvider {
  static var previews: some View {
    TabContainer()
  }
}
