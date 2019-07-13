//
//  ReviewRequester.swift
//  Podest
//
//  Created by Michael Nisi on 12.07.19.
//  Copyright © 2019 Michael Nisi. All rights reserved.
//

import Foundation
import StoreKit
import os.log

/// Considerately prompts users for a rating or a review on the App Store.
class ReviewRequester {

  private let version: BuildVersion
  
  private let unsealedTime: TimeInterval
  
  private let log: OSLog 
  
  /// Creates a new requester.
  /// 
  /// - Parameters:
  ///   - version: Information about the current version of the app.
  ///   - unsealedTime: The timestamp of when the app was launched for the first
  ///   time.
  ///   - log: A log object to use.
  init(version: BuildVersion, unsealedTime: TimeInterval, log: OSLog) {
    self.version = version
    self.unsealedTime = unsealedTime
    self.log = log
  }
  
  /// The timer triggering rating requests.
  private var rateIncentiveTimeout: DispatchSourceTimer? {
    willSet {
      os_log("setting rate incentive timeout: %@", 
             log: log, type: .debug, String(describing: newValue))
      rateIncentiveTimeout?.cancel()
    }
  }
  
  /// Counting down from five for simple activity tracking.
  private static let rateIncentiveLength = 5
  
  /// Countdown to trigger ratings. Set to -1 to deactivate ratings.
  private var rateIncentiveCountdown = rateIncentiveLength {
    didSet {
      guard rateIncentiveCountdown >= 0 else {
        return os_log("rating disabled", log: log, type: .info)
      }
      
      os_log("rate incentive threshold: %{public}i",
             log: log, type: .debug, rateIncentiveCountdown)
    }
  }
  
  /// Requests review setting a timestamp for this build.
  func requestReview() {
    precondition(!invalidated)
    
    let build = version.build
    
    DispatchQueue.main.async {
      let key = UserDefaults.lastVersionPromptedForReviewKey
      
      UserDefaults.standard.set(build, forKey: key)
      SKStoreReviewController.requestReview()
    }
  }
  
  /// `true` if this build has been reviewed.
  var isReviewed: Bool {
    UserDefaults.standard.lastVersionPromptedForReview == version.build
  }
  
  /// `true` if now is a good time to ask for a rating or a review.
  var isTime: Bool {
    Date().timeIntervalSince1970 - unsealedTime > 3600 * 24 * 3 
  }
  
  /// Waits two seconds before submitting `reviewBlock` to a global system queue, 
  /// giving us a chance to cancel (this timeout) if the context should change 
  /// and a prompt is not appropriate. Of course, any existing timeout gets
  /// cancelled. 
  /// 
  /// Does nothing within three days of first launch or if inappropriate.
  /// 
  /// Asking for ratings or reviews is only OK while users are idle for a moment
  /// after they have been active. All other times come across tacky. People 
  /// hate getting interrupted. We hate it.
  /// 
  /// - Returns: Returns `true` if a new timer has been installed.
  @discardableResult
  func setReviewTimeout(reviewBlock: @escaping () -> Void) -> Bool {
    precondition(!invalidated)
    
    rateIncentiveTimeout = nil
    
    guard rateIncentiveCountdown >= 0, isTime else {
      os_log("not setting review timeout", log: log)
      return false
    }
    
    rateIncentiveCountdown -= 1
    
    os_log("** countdown: %i", log: log, type: .debug, rateIncentiveCountdown)
    
    guard rateIncentiveCountdown == 0 else {
      return false
    }
    
    rateIncentiveCountdown = ReviewRequester.rateIncentiveLength
    
    guard !isReviewed else {
      rateIncentiveCountdown = -1
  
      return false
    }
    
    rateIncentiveTimeout = setTimeout(
      delay: .seconds(2), queue: .global(), handler: reviewBlock)
    
    return true
  }
  
  func cancelReview(resetting: Bool) {
    precondition(!invalidated)
    
    rateIncentiveTimeout = nil
    
    if resetting {
      rateIncentiveCountdown = ReviewRequester.rateIncentiveLength
    }
  }
  
  private var invalidated = false
  
  /// Cancels timer and prevents further review requests.
  func invalidate() {
    precondition(!invalidated)
    
    rateIncentiveTimeout = nil
    rateIncentiveCountdown = -1
    invalidated = true
  }
}
