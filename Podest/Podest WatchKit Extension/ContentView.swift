//
//  ContentView.swift
//  Podest
//
//  Created by Michael Nisi on 15.01.22.
//

import SwiftUI

struct ContentView: View {
  @Environment(\.scenePhase) private var scenePhase
  @SceneStorage("ContentView.selectedTab") private var selectedTab: Tab = .search
  @EnvironmentObject var queueModel: QueueModel
  
  enum Tab: String {
      case queue
      case search
  }
  
  var body: some View {
    TabView(selection: $selectedTab) {
      NavigationView {
        QueueView()
          .navigationTitle("Queue")
      }
      .navigationViewStyle(.stack)
      .tabItem {
        Image(systemName: "list.bullet.circle.fill")
        Text("Queue")
      }
      .tag(Tab.queue)
      
      NavigationView {
        SearchView()
          .navigationTitle("Discover")
      }
      .navigationViewStyle(.stack)
      .tabItem {
        Image(systemName: "magnifyingglass.circle.fill")
        Text("Search")
      }
      .tag(Tab.search)
    }
    .onChange(of: scenePhase) { newScenePhase in
      if newScenePhase == .background {
        print("background")
      }
    }
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
      .preferredColorScheme(.dark)
      .previewInterfaceOrientation(.portrait)
  }
}
