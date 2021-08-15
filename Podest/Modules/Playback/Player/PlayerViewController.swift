//===----------------------------------------------------------------------===//
//
// This source file is part of the Podest open source project
//
// Copyright (c) 2021 Michael Nisi and collaborators
// Licensed under MIT License
//
// See https://github.com/michaelnisi/podest/blob/main/LICENSE for license information
//
//===----------------------------------------------------------------------===//

import SwiftUI
import Epic
import InsetPresentation

class PlayerViewController: UIHostingController<PlayerView>, ObservableObject, InsetPresentable {
  var transitionController: UIViewControllerTransitioningDelegate?
  
  init(model: Epic.Player) {
    super.init(rootView: PlayerView(
      model: model,
      airPlayButton: PlayerViewController.airPlayButton
    ))
  }
  
  @objc required dynamic init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    rootView.model.close()
  }
}

private extension PlayerViewController {
  static var emptyView: PlayerView {
    PlayerView(model: Epic.Player(), airPlayButton: airPlayButton)
  }
  
  static var airPlayButton: AnyView {
    AnyView(AirPlayButton())
  }
}
