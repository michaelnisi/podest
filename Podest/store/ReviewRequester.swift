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

/// Requests users for feedback.
class ReviewRequester {

  private let version: BuildVersion
  
  private let unsealedTime: TimeInterval
  
  private let log: OSLog 
  
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
  
  /// Counting down from five.
  private static var rateIncentiveLength = 5
  
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
  
  /// Tells StoreKit to ask the user to rate or review your app, if appropriate.
  func requestReview() {
    precondition(!invalidated)
    
    let build = version.build
    
    DispatchQueue.main.async {
      let key = UserDefaults.lastVersionPromptedForReviewKey
      
      UserDefaults.standard.set(build, forKey: key)
      SKStoreReviewController.requestReview()
    }
  }
  
  var isReviewed: Bool {
    UserDefaults.standard.lastVersionPromptedForReview == version.build
  }
  
  var isTime: Bool {
    Date().timeIntervalSince1970 - unsealedTime > 3600 * 24 * 3 
  }
  
  /// Waits two seconds before submitting `reviewBlock` to the `.main` queue, 
  /// giving us a chance to cancel (this timeout) when the context changes and 
  /// a review is not appropriate any longer. Of course, any existing timeout 
  /// gets cancelled. 
  /// 
  /// Does nothing within three days of first launch or if inappropriate.
  /// 
  /// Asking for ratings or reviews is only OK while users are idle for a moment
  /// after they have been active. All other times can be considered harmful.
  /// People hate getting interrupted.
  /// 
  /// - Returns: Returns `true` if a new timer has been installed.
  @discardableResult
  func setReviewTimeout(reviewBlock: @escaping () -> Void) -> Bool {
    precondition(!invalidated)
    dispatchPrecondition(condition: .onQueue(.main))
    
    rateIncentiveTimeout = nil
    
    guard rateIncentiveCountdown >= 0 else {
      os_log("not setting review timeout: rating disabled", log: log)
      return false
    }
    
    rateIncentiveCountdown -= 1
    
    guard rateIncentiveCountdown == 0, isTime else {
        os_log("** not setting review timeout: too soon", log: log, type: .debug)
        
        return false
    }
    
    rateIncentiveCountdown = ReviewRequester.rateIncentiveLength
    
    guard !isReviewed else {
      rateIncentiveCountdown = -1
  
      return false
    }
    
    rateIncentiveTimeout = setTimeout(
      delay: .seconds(2), queue: .main, handler: reviewBlock)
    
    return true
  }
  
  func cancelReview(resetting: Bool) {
    dispatchPrecondition(condition: .onQueue(.main))
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
