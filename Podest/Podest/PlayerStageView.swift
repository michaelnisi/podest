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

struct PlayerItem: Identifiable {
  let id: String
  let name: String
}

struct PlayerStageView: View {
  @State var player: PlayerItem?
  
  var body: some View {

      Color.yellow
        .frame(maxWidth: .infinity, minHeight: 100, maxHeight: 100)
        .contextMenu {
            Button {
                print("Change country setting")
            } label: {
                Label("Choose Country", systemImage: "globe")
            }

            Button {
                print("Enable geolocation")
            } label: {
                Label("Detect Location", systemImage: "location.circle")
            }
        }
        .fullScreenCover(item: $player) { item in
          Text(item.name)
            .onTapGesture {
              player = nil
            }
        }
        .onTapGesture {
          player = .init(id: "abc", name: "Hello")
        }
  }
}

struct PlayerStageView_Previews: PreviewProvider {
    static var previews: some View {
        PlayerStageView()
    }
}
