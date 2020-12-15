//
//  ContextView.swift
//  Podest
//
//  Created by Michael Nisi on 15.12.20.
//  Copyright © 2020 Michael Nisi. All rights reserved.
//

import Foundation
import SwiftUI

struct ContextView : View {
  var body: some View {
    VStack {
      Text("Podcast Title")
        .font(.largeTitle)
      
      List {
        Text("Episode 1")
        Text("Episode 2")
        Text("Episode 3")
        Text("Episode 4")
      }
      
      List {
        Text("Chapter 1")
        Text("Chapter 2")
        Text("Chapter 3")
        Text("Chapter 4")
      }
    }
  }
}
