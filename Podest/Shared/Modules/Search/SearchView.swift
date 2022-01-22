//
//  SearchView.swift
//  Podest
//
//  Created by Michael Nisi on 22.01.22.
//

import SwiftUI

struct SearchView: View {
  let names = ["Holly", "Josh", "Rhonda", "Ted"]
  @State private var searchText = ""
  
    var body: some View {
      List {
        ForEach(searchResults, id: \.self) { name in
          NavigationLink(destination: Text(name)) {
            Text(name)
          }
        }
      }
      .searchable(text: $searchText, placement: .toolbar)
     
    }
  
  var searchResults: [String] {
    if searchText.isEmpty {
      return names
    } else {
      return names.filter { $0.contains(searchText) }
    }
  }
}

struct SearchView_Previews: PreviewProvider {
    static var previews: some View {
      SearchView()
    }
}
