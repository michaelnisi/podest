import SwiftUI

struct ControlsView: View {
  
  let play: VoidHandler
  let pause: VoidHandler
  let forward: VoidHandler
  let backward: VoidHandler
  
  var insets: EdgeInsets {
    EdgeInsets(top: 20, leading: 20, bottom: 64, trailing: 20)
  }
  
  @State var isPlaying: Bool
  
  private func isPlayingChange(value: Bool) {
    value ? play() : pause()
  }

  var body: some View {
      HStack(spacing: 32) {
        BackwardButton(action: backward)
          .frame(width: 48, height: 48)
        PlayButton(isPlaying: $isPlaying.onChange(isPlayingChange))
          .frame(width: 48, height: 48)
        ForwardButton(action: forward)
          .frame(width: 48, height: 64)
      }
      .foregroundColor(Color(UIColor.label))
      .padding(insets)
  }
}
