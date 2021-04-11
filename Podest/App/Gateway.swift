//
//  Gateway.swift
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
import Podcasts

private let log = OSLog(subsystem: "ink.codes.podest", category: "app")

/// `AppGateway` routes actions between app modules. Its main responsibility is handling background launches and notifications.
class AppGateway {

  private var router: Routing?
  private var kvStoreObserver: NSObjectProtocol?

  /// Installs this `AppGateway` as delegate and updates the queue after pulling from iCloud.
  func install(router: Routing) {
    os_log("installing", log: log, type: .info)

    self.router = router

    // During development, we might want to launch into the previous state,
    // without syncing or updating.
    guard !Podcasts.settings.noSync else {
      return router.reload(completionBlock: nil)
    }

    func updateQueue(considering syncError: Error? = nil) -> Void {
      DispatchQueue.main.async {
        self.router?.update(considering: syncError, animated: true) { _, error in
          if let er = error {
            os_log("updating queue produced error: %{public}@", log: log, er as CVarArg)
          }

          Podcasts.userQueue.queueDelegate = self
          Podcasts.userLibrary.libraryDelegate = self
        }
      }
    }

    guard Podcasts.iCloud.isAccountStatusKnown else {
      Podcasts.iCloud.pull { _, error in
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

  /// Removes this `AppGateway`as delegate.
  func uninstall() {
    os_log("uninstalling", log: log, type: .info)
    Podcasts.userQueue.queueDelegate = nil
    Podcasts.userLibrary.libraryDelegate = nil
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

        let success = error == nil

        guard newData else {
          return task.setTaskCompleted(success: success)
        }

        self.push {
          task.setTaskCompleted(success: success)
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
      Podcasts.iCloud.resetAccountStatus()
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
      os_log("unidentified subscription: %{public}@", log: log, type: .error, subscriptionID)
      completionHandler(.failed)
    }
  }
}

// MARK: - Background URL Session

extension AppGateway {

  func handleEventsForBackgroundURLSession(identifier: String, completionHandler: @escaping () -> Void) {
    Podcasts.files.handleEventsForBackgroundURLSession(identifier: identifier) {
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

    Podcasts.iCloud.pull { [weak self] newData, error in
      let result = AppGateway.makeBackgroundFetchResult(newData, error)

      if case .newData = result {
        DispatchQueue.main.async {
          self?.router?.reload { error in
            dispatchPrecondition(condition: .onQueue(.main))

            if let er = error {
              os_log("reloading queue failed: %{public}@", log: log, type: .error, er as CVarArg)
            }

            completionBlock?(result)
          }
        }
      } else {
        DispatchQueue.main.async {
          completionBlock?(result)
        }
      }
    }
  }

  private func push(completionBlock: (() -> Void)? = nil) {
    Podcasts.iCloud.push { error in
      if let er = error {
        os_log("push failed: %{public}@", log: log, type: .error, er as CVarArg)
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

    Podcasts.files.preload(url: url)
  }

  func queue(_ queue: Queueing, dequeued: EntryGUID, enclosure: Enclosure?) {
    guard let str = enclosure?.url, let url = URL(string: str) else {
      return os_log("missing enclosure: %{public}@", log: log, type: .error, dequeued)
    }

    Podcasts.files.cancel(url: url)
  }
}

// MARK: - Cleaning up

extension AppGateway {

  private func closeFiles() {
    os_log("closing files", log: log, type: .info)
    Podcasts.userCaching.closeDatabase()
    Podcasts.feedCaching.closeDatabase()
  }

  func flush() {
    os_log("flushing caches", log: log, type: .info)
    StringRepository.purge()
    Podcasts.images.flush()
    Podcasts.files.flush()

    do {
      try Podcasts.userCaching.flush()
      try Podcasts.feedCaching.flush()
    } catch {
      os_log("flushing failed: %{public}@", log: log, type: .error, error as CVarArg)
    }
  }

  func resign() {
    uninstall()
    Podcasts.store.cancelReview(resetting: true)
    flush()
    closeFiles()
  }
}

// MARK: - Factory

extension AppGateway {

  /// Produces a background fetch result logging its interpretation.
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
