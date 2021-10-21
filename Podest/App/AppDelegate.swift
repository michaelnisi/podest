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
import Podcasts

private let log = OSLog(subsystem: "ink.codes.podest", category: "app")

protocol Routing: UserProxy, ViewControllers {}

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
  private var state = (restore: true, save: true)
}

// MARK: - Initializing the App

extension AppDelegate {
  func application(
    _ application: UIApplication,
    willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]?
  ) -> Bool {
    state.restore = launchOptions?[.url] == nil

    if !Podcasts.settings.noSync {
      application.registerForRemoteNotifications()
    }
    
    return true
  }

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]?
  ) -> Bool {
    UserDefaults.registerPodestDefaults()
    if !Podcasts.store.isExpired() {
      Podest.gateway.register()
    }

    return true
  }
  
  func application(
    _ application: UIApplication,
    configurationForConnecting connectingSceneSession: UISceneSession,
    options: UIScene.ConnectionOptions
  ) -> UISceneConfiguration {
    .init(name: "Default Configuration", sessionRole: connectingSceneSession.role)
  }
}

// MARK: - Managing App State Restoration

extension AppDelegate {

  func application(
    _ application: UIApplication,
    shouldRestoreApplicationState coder: NSCoder) -> Bool {
    state.restore
  }

  func application(_ application: UIApplication, shouldSaveSecureApplicationState coder: NSCoder) -> Bool {
    state.save
  }
}

// MARK: - Managing Interface Geometry

extension AppDelegate {

  func application(
    _ application: UIApplication,
    supportedInterfaceOrientationsFor window: UIWindow?
  ) -> UIInterfaceOrientationMask {
    guard window?.traitCollection.userInterfaceIdiom != .phone else {
      return .portrait
    }
    
    return .allButUpsideDown
  }
}

// MARK: - Downloading Data in the Background

extension AppDelegate {

  func application(
    _ application: UIApplication,
    handleEventsForBackgroundURLSession identifier: String,
    completionHandler: @escaping () -> Void
  ) {
    Podest.gateway.handleEventsForBackgroundURLSession(
      identifier: identifier, completionHandler: completionHandler)
  }

  func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable : Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult
  ) -> Void) {
    Podest.gateway.handleNotification(userInfo: userInfo, fetchCompletionHandler: completionHandler)
  }
}

// MARK: - Handling Remote Notification Registration

extension AppDelegate {

  func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    Podest.gateway.didRegisterForRemoteNotificationsWithDeviceToken(deviceToken)
  }

  func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    os_log("failed to register: %{public}@", log: log, type: .error, error as CVarArg)
  }
}

// MARK: - Responding to App State Changes and System Events

extension AppDelegate {
  func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
    Podest.gateway.flush()
  }

  func applicationWillTerminate(_ application: UIApplication) {
    Podest.gateway.resign()
  }
}
