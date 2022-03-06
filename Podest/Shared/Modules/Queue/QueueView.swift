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


struct EpisodeView: View {
#if os(iOS)
  @Environment(\.horizontalSizeClass) var horizontalSizeClass
#endif
  let name: String
  
  var body: some View {
    VStack(spacing: 0) {
      Text(name)
        .frame(maxHeight: .infinity)
#if os(iOS)
        .toolbar {
          ToolbarItem(placement: .navigationBarTrailing) {
            Button("Help") {
              print("Help tapped!")
            }
          }
        }
#endif
#if os(iOS)
      if horizontalSizeClass != .compact {
        PlayerStageView()
        
      }
#endif
      
    }
    .frame(maxHeight: .infinity, alignment: .bottom)
    
  }
}

struct QueueView: View {
  
  @State var names = [
    "Holly",
    "Josh",
    "Rhonda",
    "Ted",
    "Alfred",
    "Chester",
    "Hudson",
    "Ibrahim",
    "Emily",
    "Ellie",
    "Chloe",
    "Jessica",
    "Sophie"
  ]
  
  @State private var searchText = ""
  @State private var visible = false
  
  func delete(at offsets: IndexSet) {
    names.remove(atOffsets: offsets)
  }
  
  var body: some View {
    List {
      ForEach(searchResults, id: \.self) { name in
        NavigationLink(destination: EpisodeView(name: name)) {
          
          Text(name)
          
          
        }
      }
#if os(iOS)
      .onDelete(perform: delete)
#endif
    }
    .toolbar {
#if os(iOS)
      EditButton()
#else
      ToolbarItem(placement: .primaryAction) {
        Button("Now Playing") {
          visible.toggle()
        }
        .sheet(isPresented: $visible){
          Text("Hello")
        }
      }
      ToolbarItem(placement: .destructiveAction) {
        Button("Edit") {}
      }
#endif
    }
    .searchable(text: $searchText, placement: .toolbar)
    .refreshable {
      //
    }
  }
  
  var searchResults: [String] {
    if searchText.isEmpty {
      return names
    } else {
      return names.filter { $0.contains(searchText) }
    }
  }
}

struct QueueView_Previews: PreviewProvider {
  static var previews: some View {
    QueueView()
  }
}
