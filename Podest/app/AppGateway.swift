//
//  AppGateway.swift
//  Podest
//
//  Created by Michael Nisi on 29.08.20.
//  Copyright © 2020 Michael Nisi. All rights reserved.
//

import UIKit
import BackgroundTasks
import CloudKit
import os.log
import FeedKit

private let log = OSLog(subsystem: "ink.codes.podest", category: "app")

/// `AppGateway` routes actions between app modules. Its main responsibility is handling background launches and notifications.
class AppGateway {

  private var router: Routing?
  private var kvStoreObserver: NSObjectProtocol?

  /// The `isPulling` property is `true` while we are pulling from iCloud.
  private var isPulling = false {
    didSet {
      dispatchPrecondition(condition: .onQueue(.main))
    }
  }

  /// The `isPushing` property is `true` while we are pushisng to iCloud.
  private var isPushing = false {
    willSet {
      dispatchPrecondition(condition: .onQueue(.main))
    }
  }

  func install(router: Routing) {
    self.router = router

    // During development, we might want to launch into the previous state,
    // without syncing or updating.
    guard !Podest.settings.noSync else {
      return router.reload(completionBlock: nil)
    }

    func updateQueue(considering syncError: Error? = nil) -> Void {
      DispatchQueue.main.async {
        self.router?.update(considering: syncError, animated: true) { _, error in
          if let er = error {
            os_log("updating queue produced error: %{public}@",
                   log: log, er as CVarArg)
          }

          Podest.userQueue.queueDelegate = self
          Podest.userLibrary.libraryDelegate = self
        }
      }
    }

    guard Podest.iCloud.isAccountStatusKnown else {
      Podest.iCloud.pull { _, error in
        if let er = error {
          os_log("iCloud: %{public}@", log: log, String(describing: er))
        }

        // Withholding errors, iCloud is optional.
        updateQueue()
      }
      return
    }

    updateQueue()
  }

  func uninstall() {
    Podest.userQueue.queueDelegate = nil
    Podest.userLibrary.libraryDelegate = nil
  }
}

// MARK: - Background Tasks

extension AppGateway {

  func register() {
    BGTaskScheduler.shared.register(
      forTaskWithIdentifier: "ink.codes.Podest.refresh",
      using: nil
    ) { task in
      self.handleAppRefresh(task: task as! BGAppRefreshTask)
    }
  }

  func cancelAlBGTaskRequests() {
    BGTaskScheduler.shared.cancelAllTaskRequests()
  }

  func schedule() {
    let request = BGAppRefreshTaskRequest(identifier: "ink.codes.Podest.refresh")
    request.earliestBeginDate = Date(timeIntervalSinceNow: 1 * 60)

    do {
      try BGTaskScheduler.shared.submit(request)
    } catch {
      os_log("could not schedule app refresh: %{public}@", log: log, type: .error, error as CVarArg)
    }
  }

  private func handleAppRefresh(task: BGAppRefreshTask) {
    schedule()

    var isExpired = false

    task.expirationHandler = {
      isExpired = true
    }

    DispatchQueue.main.async {
      self.router?.update(considering: nil, animated: false) { newData, error in
        guard !isExpired else {
          task.setTaskCompleted(success: false)

          return os_log("app refresh task expired", log: log, type: .error)
        }

        self.push {
          task.setTaskCompleted(success: error == nil && newData)
        }
      }
    }
  }
}

// MARK: - Notifications

extension AppGateway {

  func didRegisterForRemoteNotificationsWithDeviceToken(_ deviceToken: Data) {
    let nc = NotificationCenter.default

    nc.addObserver(forName: .CKAccountChanged, object: nil, queue: .main) { [weak self] _ in
      Podest.iCloud.resetAccountStatus()
      self?.pull()
    }
  }

  func handleNotification(
    userInfo: [AnyHashable : Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    guard let notification = CKNotification(
      fromRemoteNotificationDictionary: userInfo),
      let subscriptionID = notification.subscriptionID else {
      return os_log("unhandled remote notification", log: log, type: .error)
    }

    // We receive a notification per zone. How can we optimize this?

    switch subscriptionID {
    case UserDB.subscriptionID:
      pull(completionBlock: completionHandler)

    default:
      os_log("failing fetch completion: unidentified subscription: %{public}@",
             log: log, type: .error, subscriptionID)
      completionHandler(.failed)
    }
  }
}

// MARK: - Background URL Session

extension AppGateway {

  func handleEventsForBackgroundURLSession(identifier: String, completionHandler: @escaping () -> Void) {
    Podest.files.handleEventsForBackgroundURLSession(identifier: identifier) {
      DispatchQueue.main.async {
        completionHandler()
      }
    }
  }
}

// MARK: - Syncing with iCloud

extension AppGateway {

  /// Pulls iCloud, integrates new data, and reloads the queue locally to update
  /// views for snapshotting.
  ///
  /// - Parameters:
  ///   - completionBlock: The completion block executing on the main queue.
  /// when done.
  ///
  /// Pulling has presedence over pushing.
  private func pull(completionBlock: ((UIBackgroundFetchResult) -> Void)? = nil) {
    dispatchPrecondition(condition: .onQueue(.main))

    if isPushing {
      os_log("pulling while pushing", log: log)
    }

    isPulling = true

    Podest.iCloud.pull { [weak self] newData, error in
      let result = AppGateway.makeBackgroundFetchResult(newData, error)

      if case .newData = result {
        DispatchQueue.main.async {
          self?.router?.reload { error in
            dispatchPrecondition(condition: .onQueue(.main))

            if let er = error {
              os_log("reloading queue failed: %{public}@",
                     log: log, type: .error, er as CVarArg)
            }

            self?.isPulling = false

            completionBlock?(result)
          }
        }
      } else {
        DispatchQueue.main.async {
          self?.isPulling = false

          completionBlock?(result)
        }
      }
    }
  }

  /// Pushes user data to iCloud. **Must execute on the main queue.**
  private func push(completionBlock: (() -> Void)? = nil) {
    guard !isPulling, !isPushing else {
      os_log("already syncing", log: log)
      completionBlock?()
      return
    }

    isPushing = true

    Podest.iCloud.push { [weak self] error in
      if let er = error {
        os_log("push failed: %{public}@",
               log: log, type: .error, er as CVarArg)
      }

      DispatchQueue.main.async {
        self?.isPushing = false
      }

      completionBlock?()
    }
  }
}

// MARK: - LibraryDelegate

extension AppGateway: LibraryDelegate {

  func library(_ library: Subscribing, changed urls: Set<FeedURL>) {
    DispatchQueue.main.async { [weak self] in
      self?.router?.updateIsSubscribed(using: urls)

      self?.push()
    }
  }
}

// MARK: - QueueDelegate

extension AppGateway: QueueDelegate {

  func queue(_ queue: Queueing, changed guids: Set<EntryGUID>) {
    DispatchQueue.main.async { [weak self] in
      self?.router?.updateIsEnqueued(using: guids)
      self?.router?.reload(completionBlock: nil)

      self?.push()
    }
  }

  func queue(_ queue: Queueing, enqueued: EntryGUID, enclosure: Enclosure?) {
    guard let str = enclosure?.url, let url = URL(string: str) else {
      return os_log("missing enclosure: %{public}@", log: log, type: .error, enqueued)
    }

    Podest.files.preload(url: url)
  }

  func queue(_ queue: Queueing, dequeued: EntryGUID, enclosure: Enclosure?) {
    guard let str = enclosure?.url, let url = URL(string: str) else {
      return os_log("missing enclosure: %{public}@", log: log, type: .error, dequeued)
    }

    Podest.files.cancel(url: url)
  }
}

// MARK: - Factory

extension AppGateway {

  /// Produces a background fetch result and logs its interpretation.
  ///
  /// - Parameters:
  ///   - newData: `true` if new data has been received.
  ///   - error: The error to take into consideration.
  ///
  /// The `newData` flag takes precedence over `error`.
  private static
  func makeBackgroundFetchResult(_ newData: Bool, _ error: Error?) -> UIBackgroundFetchResult {
    guard error == nil else {
      if newData {
        os_log("fetch completed with new data and error: %{public}@",
               log: log, type: .error, error! as CVarArg)
        return .newData
      } else {
        os_log("fetch failed: %{public}@",
               log: log, type: .error, error! as CVarArg)
        return .failed
      }
    }

    if newData {
      os_log("fetch completed with new data", log: log, type: .info)
      return .newData
    } else {
      os_log("fetch completed with no data", log: log, type: .info)
      return .noData
    }
  }
}
