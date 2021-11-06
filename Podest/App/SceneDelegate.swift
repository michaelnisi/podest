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

import UIKit
import os.log

private let log = OSLog(subsystem: "ink.codes.podest", category: "scene")

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?
  
  private var root: Routing {
    dispatchPrecondition(condition: .onQueue(.main))

    guard let vc = window?.rootViewController as? Routing else {
      fatalError("unexpected root view controller")
    }
    
    return vc
  }

  func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
    guard let _ = (scene as? UIWindowScene) else { return }
    
    window?.tintColor = UIColor(named: "Purple")!
  }

  func sceneDidDisconnect(_ scene: UIScene) {
    os_log("%@", log: log, type: .debug, #function)
    Podest.gateway.resign()
  }

  func sceneDidBecomeActive(_ scene: UIScene) {
    os_log("%@", log: log, type: .debug, #function)
    Podest.gateway.install(router: root)
  }

  func sceneWillResignActive(_ scene: UIScene) {
    os_log("%@", log: log, type: .debug, #function)
    // Called when the scene will move from an active state to an inactive state.
    // This may occur due to temporary interruptions (ex. an incoming phone call).
  }

  func sceneWillEnterForeground(_ scene: UIScene) {
    os_log("%@", log: log, type: .debug, #function)
    // Called as the scene transitions from the background to the foreground.
    // Use this method to undo the changes made on entering the background.
  }

  func sceneDidEnterBackground(_ scene: UIScene) {
    os_log("%@", log: log, type: .debug, #function)
    Podest.gateway.schedule()
  }
  
  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    for context in URLContexts {
      assert(root.open(url: context.url))
    }
  }
}

