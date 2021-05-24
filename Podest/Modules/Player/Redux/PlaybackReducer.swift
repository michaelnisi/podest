//
//  PlaybackStateTransformer.swift
//  Podest
//
//  Created by Michael Nisi on 24.05.21.
//  Copyright © 2021 Michael Nisi. All rights reserved.
//

import Foundation
import Playback
import Combine
import FeedKit

struct PlaybackReducer {
  let factory: NowPlayingFactory
  
  func reducer(state: NowPlaying.State, action: Playback.PlaybackState<Entry>) -> AnyPublisher<NowPlaying.State, Never> {
    switch state {
    case .full:
      switch action {
      case .inactive(_):
        return Just(.none)
          .eraseToAnyPublisher()
        
      case .paused(_, _, _):
        return Just(.none)
          .eraseToAnyPublisher()
        
      case .preparing(_, _):
        return Just(.none)
          .eraseToAnyPublisher()
        
      case let .listening(entry, asset):
        return factory.transformListening(entry: entry, asset: asset)
          .eraseToAnyPublisher()
        
      case let .viewing(entry, player):
        return Just(.video(entry, player))
          .eraseToAnyPublisher()
      }
    case .mini(_, _):
      switch action {
      case .inactive(_):
        return Just(.none)
          .eraseToAnyPublisher()
        
      case .paused(_, _, _):
        return Just(.none)
          .eraseToAnyPublisher()
        
      case .preparing(_, _):
        return Just(.none)
          .eraseToAnyPublisher()
        
      case let .listening(entry, asset):
        return factory.transformListening(entry: entry, asset: asset)
          .eraseToAnyPublisher()
        
      case let .viewing(entry, player):
        return Just(.video(entry, player))
          .eraseToAnyPublisher()
      }
    case .video(_, _):
      switch action {
      case .inactive(_):
        return Just(.none)
          .eraseToAnyPublisher()
        
      case .paused(_, _, _):
        return Just(.none)
          .eraseToAnyPublisher()
        
      case .preparing(_, _):
        return Just(.none)
          .eraseToAnyPublisher()
        
      case let .listening(entry, asset):
        return factory.transformListening(entry: entry, asset: asset)
          .eraseToAnyPublisher()
        
      case let .viewing(entry, player):
        return Just(.video(entry, player))
          .eraseToAnyPublisher()
      }
    case .none:
      switch action {
      case .inactive(_):
        return Just(.none)
          .eraseToAnyPublisher()
        
      case .paused(_, _, _):
        return Just(.none)
          .eraseToAnyPublisher()
        
      case .preparing(_, _):
        return Just(.none)
          .eraseToAnyPublisher()
        
      case let .listening(entry, asset):
        return factory.transformListening(entry: entry, asset: asset)
          .eraseToAnyPublisher()
        
      case let .viewing(entry, player):
        return Just(.video(entry, player))
          .eraseToAnyPublisher()
      }
    }
  }
}
