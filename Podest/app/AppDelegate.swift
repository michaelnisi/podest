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

  private var shouldRestoreState = true
  private var shouldSaveState = true

  /// An object that adopts `Routing` for event funnelling.
  ///
  /// In the current design, the root view controller.
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
    shouldRestoreState = launchOptions?[.url] == nil
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
    shouldRestoreState
  }

  func application(_ application: UIApplication, shouldSaveSecureApplicationState coder: NSCoder) -> Bool {
    shouldSaveState
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
    os_log("failed to register: %{public}@",
           log: log, type: .error, error as CVarArg)
  }
}

// MARK: - Responding to App State Changes and System Events

extension AppDelegate {

  private func closeFiles() {
    os_log("closing files", log: log, type: .info)

    Podest.userCaching.closeDatabase()
    Podest.feedCaching.closeDatabase()
  }

  private func flush() {
    os_log("flushing caches", log: log, type: .info)

    StringRepository.purge()
    Podest.images.flush()
    Podest.files.flush()

    do {
      try Podest.userCaching.flush()
      try Podest.feedCaching.flush()
    } catch {
      os_log("flushing failed: %{public}@",
             log: log, type: .error, error as CVarArg)
    }
  }

  func applicationWillResignActive(_ application: UIApplication) {
    Podest.gateway.uninstall()
    Podest.networkActivity.reset()
    Podest.store.cancelReview(resetting: true)
    flush()
    closeFiles()
  }

  func applicationDidBecomeActive(_ application: UIApplication) {
    Podest.gateway.install(router: root)
  }

  func applicationDidEnterBackground(_ application: UIApplication) {
    Podest.gateway.schedule()
  }

  func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
    flush()
  }

  func applicationWillTerminate(_ application: UIApplication) {
    Podest.gateway.uninstall()
    flush()
    closeFiles()
  }
}
