//
//  PlayerMessage.swift
//  Podest
//
//  Created by Michael Nisi on 24.06.19.
//  Copyright © 2019 Michael Nisi. All rights reserved.
//

import Foundation
import Playback
import FeedKit

/// Makes user messages from playback errors.
struct PlayerMessage {
  
  static func makeMessage(entry: Entry, error: PlaybackError) -> (String, String)? {
    
    switch error {
    case .log, .unknown:
      fatalError("unexpected error")
      
    case .unreachable:
      return (
        "You’re Offline",
        """
        Your episode – \(entry.title) – can’t be played because you are \
        not connected to the Internet.
        
        Turn off Airplane Mode or connect to Wi-Fi.
        """
      )
      
    case .failed:
      return (
        "Playback Error",
        """
        Sorry, playback of your episode – \(entry.title) – failed.
        
        Try later or, if this happens repeatedly, remove it from your Queue.
        """
      )
      
    case .media:
      return (
        "Strange Data",
        """
        Your episode – \(entry.title) – cannot be played.
        
        It’s probably best to remove it from your Queue.
        """
      )
      
    case .surprising(let surprisingError):
      return (
        "Oh No",
        """
        Your episode – \(entry.title) – cannot be played.
        
        \(surprisingError.localizedDescription)
        
        Please consider removing it from your Queue.
        """
      )
      
    case .session:
      return nil
    }
  }
}
