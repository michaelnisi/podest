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
        SearchView()
          .navigationTitle("Discover")
          .navigationBarTitleDisplayMode(.inline)
      }
      .navigationViewStyle(.stack)
      .tabItem {
        Image(systemName: "magnifyingglass.circle.fill")
      }
      .tag(Tab.search)
      
      NavigationView {
        QueueView()
          .navigationTitle("Queue")
          .navigationBarTitleDisplayMode(.inline)
      }
      .navigationViewStyle(.stack)
      .tabItem {
        Image(systemName: "list.bullet.circle.fill")
      }
      .tag(Tab.queue)
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
