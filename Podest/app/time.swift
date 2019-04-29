//
//  time.swift
//  Podest
//
//  Created by Michael on 10/19/17.
//  Copyright © 2017 Michael Nisi. All rights reserved.
//

import Foundation

/// Sets up a cancellable oneshot timer.
///
/// - Parameters:
///   - delay: The delay before `handler` is submitted to `queue`.
///   - queue: The target queue to which `handler` is submitted.
///   - handler: The block to execute after `delay`.
///
/// - Returns: The resumed oneshot timer dispatch source.
func setTimeout(
  delay: DispatchTimeInterval,
  queue: DispatchQueue,
  handler: @escaping () -> Void
) -> DispatchSourceTimer {
  let leeway: DispatchTimeInterval = .nanoseconds(100)
  let timer = DispatchSource.makeTimerSource(queue: queue)

  timer.setEventHandler(handler: handler)
  timer.schedule(deadline: .now() + delay, leeway: leeway)
  timer.resume()

  return timer
}
