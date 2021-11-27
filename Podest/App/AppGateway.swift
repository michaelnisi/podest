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
import BackgroundTasks
import CloudKit
import os.log
import FeedKit
import Podcasts

private let logger: Logger? = .init(subsystem: "ink.codes.podest", category: "AppGateway")

/// `AppGateway` routes actions between app modules. Its main responsibility is handling
/// background launches and notifications.
class AppGateway {
  private var router: Routing!
  private var kvStoreObserver: NSObjectProtocol? // TODO: Observe store for played/unplayed flag
  private var isPulling = false { didSet { logger?.log("isPulling: \(self.isPulling)") } }
  private var isPushing = false { didSet { logger?.log("isPushing: \(self.isPushing)") } }
  
  /// Installs the gateway for callbacks and updates the user library.
  func install(router: Routing) {
    logger?.notice("installing")

    self.router = router
    Podcasts.userQueue.queueDelegate = self
    Podcasts.userLibrary.libraryDelegate = self
    
    Podcasts.userLibrary.update { newData, error in
      AppGateway.makeResult("update", newData, error)
    }
  }

  /// Removes this `AppGateway`as delegate.
  func uninstall() {
    logger?.notice("uninstalling")
    
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
    ) { [unowned self] task in
      handleAppRefresh(task: task as! BGAppRefreshTask)
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
      logger?.error("could not schedule app refresh: \(error.localizedDescription)")
    }
    
    // Set a breakpoint here.
    //
    // e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"ink.codes.Podest.refresh"]
  }

  private func handleAppRefresh(task: BGAppRefreshTask) {
    schedule()

    var isExpired = false

    task.expirationHandler = {
      isExpired = true
    }

    DispatchQueue.main.async { [unowned self] in
      logger?.notice("updating queue")
      
      router?.update(considering: nil, animated: false) { newData, error in
        guard !isExpired else {
          task.setTaskCompleted(success: false)
          logger?.warning("app refresh task expired")
          
          return
        }
        
        let success = error == nil
        
        logger?.notice("setting task complete: \(success)")
        
        guard newData else {
          task.setTaskCompleted(success: success)
          
          return
        }
        
        push {
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
    
    nc.addObserver(forName: .CKAccountChanged, object: nil, queue: .main) { [unowned self] _ in
      Podcasts.iCloud.resetAccountStatus()
      pull()
    }
  }

  func handleNotification(
    userInfo: [AnyHashable : Any],
    fetchCompletionHandler onComplete: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    guard
      let notification = CKNotification(fromRemoteNotificationDictionary: userInfo),
      let subscriptionID = notification.subscriptionID else {
        
      logger?.error("unhandled remote notification")
        
      return
    }

    switch subscriptionID {
    case UserDB.subscriptionID:
      pull { result in
        onComplete(result)
      }

    default:
      logger?.error("unidentified subscription: \(subscriptionID)")
      onComplete(.failed)
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
  ///   - onComplete: The completion block executing on the main queue.
  /// when done.
  ///
  /// Pulling has presedence over pushing.
  private func pull(onComplete: ((UIBackgroundFetchResult) -> Void)? = nil) {
    dispatchPrecondition(condition: .onQueue(.main))
    
    guard !isPushing else {
      return
    }
    
    isPulling = true
    
    Podcasts.iCloud.pull { [unowned self] newData, error in
      let result = AppGateway.makeResult("pull", newData, error)

      if case .newData = result {
        DispatchQueue.main.async {
          router?.reload { error in
            dispatchPrecondition(condition: .onQueue(.main))

            if let error = error {
              logger?.error("reloading queue failed: \(error.localizedDescription)")
            }
            
            isPulling = false

            onComplete?(result)
          }
        }
      } else {
        DispatchQueue.main.async {
          isPulling = false
          
          onComplete?(result)
        }
      }
    }
  }

  private func push(onComplete: (() -> Void)? = nil) {
    guard !isPulling else {
      onComplete?()
      return
    }
    
    isPushing = true

    Podcasts.iCloud.push { [unowned self] error in
      if let error = error {
        logger?.error("push failed: \(error.localizedDescription)")
      }
      
      isPushing = false
      
      onComplete?()
    }
  }
}

// MARK: - LibraryDelegate

extension AppGateway: LibraryDelegate {
  func library(_ library: Subscribing, subscribed urls: Set<FeedURL>) {
    DispatchQueue.main.async { [unowned self] in
      router?.updateIsSubscribed(using: urls)
    }
  }
}

// MARK: - QueueDelegate

extension AppGateway: QueueDelegate {
  func queue(_ queue: Queueing, willUpdate: (() -> Void)?) {
    pull { _ in
      willUpdate?()
    }
  }
  
  func queue(_ queue: Queueing, enqueued guids: Set<EntryGUID>) {
    DispatchQueue.main.async { [unowned self] in
      router?.updateIsEnqueued(using: guids)
      router?.reload { _ in
        push()
      }
    }
  }

  func queue(_ queue: Queueing, enqueued: EntryGUID, enclosure: Enclosure?) {
    guard let str = enclosure?.url, let url = URL(string: str) else {
      logger?.error("missing enclosure: \(enqueued)")
      
      return
    }
    
    Podcasts.files.preload(url: url)
  }

  func queue(_ queue: Queueing, dequeued: EntryGUID, enclosure: Enclosure?) {
    guard let str = enclosure?.url, let url = URL(string: str) else {
      logger?.error("missing enclosure: \(dequeued)")
      
      return
    }

    Podcasts.files.cancel(url: url)
  }
}

// MARK: - Cleaning up

extension AppGateway {
  private func closeFiles() {
    logger?.info("closing files")
    Podcasts.userCaching.closeDatabase()
    Podcasts.feedCaching.closeDatabase()
  }

  func flush() {
    logger?.info("flushing cache")
    StringRepository.purge()
    Podcasts.images.flush()
    Podcasts.files.flush()

    do {
      try Podcasts.userCaching.flush()
      try Podcasts.feedCaching.flush()
    } catch {
      logger?.error("flushing failed: \(error.localizedDescription)")
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
  @discardableResult private static
  func makeResult(_ info: String, _ newData: Bool, _ error: Error?) -> UIBackgroundFetchResult {
    guard error == nil else {
      if newData {
        logger?.error("\(info) completed: \(error!.localizedDescription)")
        
        return .newData
      } else {
        logger?.error("\(info) failed: \(error!.localizedDescription)")
        
        return .failed
      }
    }

    if newData {
      logger?.info("\(info) completed with new data")
      
      return .newData
    } else {
      logger?.info("\(info) completed with no data")
      
      return .noData
    }
  }
}
