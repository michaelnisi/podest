//
//  Bus.swift
//  Podest
//
//  Created by Michael Nisi on 05.09.20.
//  Copyright © 2020 Michael Nisi. All rights reserved.
//

import Foundation
import Combine
import FeedKit
import os.log
import Playback

private let log = OSLog(subsystem: "ink.codes.podest", category: "bus")

/// Central bus exposing global state via Combine subjects.
class Bus {

  let playback = PlaybackBus()

  public static let shared = Bus()

  private init() {}
}

class PlaybackBus {

  private let entrySubject = CurrentValueSubject<Entry?, Never>(nil)
}

// MARK: - PlaybackDelegate

extension PlaybackBus: PlaybackDelegate {
  
  func proxy(url: URL) -> URL? {
    nil
  }

  func playback(session: Playback, didChange state: PlaybackState) {
    entrySubject.value = session.currentEntry
  }

  func nextItem() -> Entry? {
    nil
  }

  func previousItem() -> Entry? {
    nil
  }
}
