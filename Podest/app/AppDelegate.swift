//
//  AppDelegate.swift
//  Podest
//
//  Created by Michael on 11/11/14.
//  Copyright (c) 2014 Michael Nisi. All rights reserved.
//

import UIKit
import os.log

private let log = OSLog(subsystem: "ink.codes.podest", category: "app")

protocol Routing: UserProxy, ViewControllers {}

@UIApplicationMain
final class AppDelegate: UIResponder, UIApplicationDelegate {
  var window: UIWindow?

  private var state = (restore: true, save: true)

  private var root: Routing {
    dispatchPrecondition(condition: .onQueue(.main))

    guard let vc = window?.rootViewController as? Routing else {
      fatalError("unexpected root view controller")
    }
    
    return vc
  }
}

// MARK: - Initializing the App

extension AppDelegate {

  func application(
    _ application: UIApplication,
    willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]?
  ) -> Bool {
    state.restore = launchOptions?[.url] == nil
    window?.tintColor = UIColor(named: "Purple")!

    if !Podest.settings.noSync {
      application.registerForRemoteNotifications()
    }

    return true
  }

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]?
  ) -> Bool {
    UserDefaults.registerPodestDefaults()
    if !Podest.store.isExpired() {
      Podest.gateway.register()
    }

    return true
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

// MARK: - Opening a URL-Specified Resource

extension AppDelegate {

  func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    root.open(url: url)
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

  func applicationWillResignActive(_ application: UIApplication) {
    Podest.gateway.resign()
  }

  func applicationDidBecomeActive(_ application: UIApplication) {
    Podest.gateway.install(router: root)
  }

  func applicationDidEnterBackground(_ application: UIApplication) {
    Podest.gateway.schedule()
  }

  func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
    Podest.gateway.flush()
  }

  func applicationWillTerminate(_ application: UIApplication) {
    Podest.gateway.resign()
  }
}
