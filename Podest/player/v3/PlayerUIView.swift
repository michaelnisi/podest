//
//  PlayerUIView.swift
//  Podest
//
//  Created by Michael Nisi on 05.09.20.
//  Copyright © 2020 Michael Nisi. All rights reserved.
//

import SwiftUI

struct PlayerUIView: View {
    var body: some View {
      VStack {
        HStack {
          Image(<#T##name: String##String#>)
          PlayButton().frame(width: 120, height: 120)
        }
        HStack {
          PlayButton().frame(width: 120, height: 120)
        }
      }

    }
}

struct PlayerUIView_Previews: PreviewProvider {
    static var previews: some View {
        PlayerUIView()
    }
}
