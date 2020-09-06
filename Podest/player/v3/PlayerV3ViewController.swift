//
//  PlayerV3ViewController.swift
//  Podest
//
//  Created by Michael Nisi on 05.09.20.
//  Copyright © 2020 Michael Nisi. All rights reserved.
//

import UIKit
import SwiftUI

class PlayerV3ViewController: UIHostingController<PlayerUIView> {

  override init?(coder aDecoder: NSCoder, rootView: PlayerUIView) {
    super.init(coder: aDecoder, rootView: rootView)
  }

  @objc required dynamic init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder, rootView: PlayerUIView())
  }
}
