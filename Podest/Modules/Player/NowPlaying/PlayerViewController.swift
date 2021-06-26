//
//  PlayerViewController.swift
//  Podest
//
//  Created by Michael Nisi on 05.09.20.
//  Copyright © 2020 Michael Nisi. All rights reserved.
//

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
}

private extension PlayerViewController {
  static var emptyView: PlayerView {
    PlayerView(model: Epic.Player(), airPlayButton: airPlayButton)
  }
  
  static var airPlayButton: AnyView {
    AnyView(AirPlayButton())
  }
}
