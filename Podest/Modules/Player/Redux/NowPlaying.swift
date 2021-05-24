//
//  NowPlaying.swift
//  Podest
//
//  Created by Michael Nisi on 22.05.21.
//  Copyright © 2021 Michael Nisi. All rights reserved.
//

import Foundation
import FeedKit
import Playback
import Podcasts
import os.log
import Epic
import Combine
import AVFoundation

private let logger = Logger(subsystem: "ink.codes.podest", category: "NowPlaying")

/// NowPlaying publishes the player state.
class NowPlaying {
    
  enum State {
    case full(Entry, Epic.Player)
    case mini(Entry, MiniPlayer)
    case video(Entry, AVPlayer)
    case none
  }
  
  enum Message {
    case error(String, String)
    case none
  }
  
  @Published private (set) var state: State = .none
  @Published private (set) var message: Message = .none
  
  private let playbackReducer = PlaybackReducer(factory: NowPlayingFactory())

  init() {
    Podcasts.playback.$state
      .receive(on: DispatchQueue.main)
      .map { (self.state, $0) }
      .flatMap(playbackReducer.reducer)
      .assign(to: &$state)
  }
}

extension NowPlaying {
  func startMiniPlayer(showing entry: Entry) {
    guard case .none = state else {
      return
    }
    
    let item = MiniPlayer.Item(title: entry.title)
    let player = MiniPlayer()
    
    state = .mini(entry, player)
    
    player.configure(item: item, isPlaying: false)
  }
}

extension NowPlaying {
  func play(_ entry: Entry) {
    logger.info("playing: \(entry.title, privacy: .public)")

    Podcasts.userQueue.enqueue(entries: [entry], belonging: .user) { enqueued, er in
      if let error = er {
        logger.error("enqueue error:: \(error.localizedDescription, privacy: .public)")
      }

      if !enqueued.isEmpty {
        logger.info("enqueued to play:: \(enqueued, privacy: .public)")
      }

      do {
        try Podcasts.userQueue.skip(to: entry)
      } catch {
        logger.error("skip error:: \(error.localizedDescription, privacy: .public)")
      }
      
      Podcasts.playback.resume(entry, from: nil)
    }
  }
  
  func pause() {
    guard Podcasts.playback.currentItem != nil else {
      return
    }

    Podcasts.playback.pause(nil, at: nil)
  }
}

extension NowPlaying {
  func forward() {
    
  }
  
  func backward() {
    
  }
  
  func scrub() {
    
  }
}

